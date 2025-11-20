/// 이메일 인증 상태 관리 Provider
///
/// Provider 패턴을 사용하여 Firebase 이메일 인증 상태를 관리하는 클래스입니다.
/// ChangeNotifier를 mixin하여 상태 변경 시 UI에 자동으로 알림을 보냅니다.
///
/// 주요 기능:
/// - 로그인 상태 관리
/// - 이메일/비밀번호 로그인
/// - 이메일/비밀번호 회원가입
/// - 사용자 정보 제공
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/services/fcm_service.dart';

/// 이메일 인증 상태를 관리하는 Provider 클래스
///
/// ChangeNotifier를 mixin하여 상태 변경 시 구독자들에게 알림을 보냅니다.
/// Firebase Auth를 사용하여 실제 인증 로직을 처리합니다.
class EmailAuthProvider with ChangeNotifier {
  final LocalAppRepository _localRepo = LocalAppRepository.instance;
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _firebaseSubscription;
  StreamSubscription<AppUserProfile?>? _localSubscription;

  /// 현재 로그인된 사용자 정보
  /// null이면 로그인되지 않은 상태
  AppUserProfile? _user;

  /// 로딩 상태
  bool _loading = false;

  /// 에러 메시지
  String? _errorMessage;

  /// 현재 로그인된 사용자 정보를 반환합니다.
  AppUserProfile? get user => _user;

  /// 로딩 상태를 반환합니다.
  bool get loading => _loading;

  /// 에러 메시지를 반환합니다.
  String? get errorMessage => _errorMessage;

  /// 생성자 - Firebase Auth 상태 변화 리스너 등록
  EmailAuthProvider() {
    if (AppConfig.useFirebase) {
      _auth = FirebaseAuth.instance;
      _firebaseSubscription = _auth!.userChanges().listen((User? user) async {
        if (user == null) {
          _user = null;
          notifyListeners();
        } else {
          // Firestore에서 사용자 정보 가져오기
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            
            if (userDoc.exists) {
              _user = _createAppUserProfile(user, userDoc);
            } else {
              // Firestore에 정보가 없으면 이메일 도메인으로부터 추론
              _user = _mapFirebaseUser(user);
            }
          } catch (e) {
            debugPrint('사용자 정보 로드 실패: $e');
            // 실패 시 이메일 도메인으로부터 추론
            _user = _mapFirebaseUser(user);
          }
          
          // FCM 토큰 저장
          await FCMService().saveTokenForUser(user.uid);
          
          notifyListeners();
        }
      });
    } else {
      _localSubscription =
          _localRepo.authStateChanges.listen((AppUserProfile? user) {
        _user = user;
        notifyListeners();
      });
    }
  }

  /// region level 값을 안전하게 파싱하는 헬퍼 메서드
  String _parseRegionLevel(dynamic level) {
    if (level == null) return 'unknown';
    if (level is String) return level;
    if (level is int) return level.toString();
    return 'unknown';
  }

  /// Firestore의 DocumentSnapshot에서 AppUserProfile 객체를 생성하는 메서드
  AppUserProfile _createAppUserProfile(User user, DocumentSnapshot userDoc) {
    final data = userDoc.data()! as Map<String, dynamic>;
    final regionData = data['region'] as Map<String, dynamic>?;

    return AppUserProfile(
      uid: user.uid,
      displayName: data['displayName'] as String? ?? data['name'] as String? ?? '',
      email: user.email ?? '',
      region: regionData != null ? Region(
        code: regionData['code'] as String? ?? '',
        name: regionData['name'] as String? ?? '',
        level: _parseRegionLevel(regionData['level']),
        parent: regionData['parent'] as String?,
      ) : _getDefaultRegionFromEmail(user.email ?? ''),
      universityId: data['universityId'] as String? ??
                   _localRepo.getUniversityCodeByEmailDomain(user.email ?? '') ??
                   'UNKNOWN',
      emailVerified: user.emailVerified,
      hasSetNickname: data['hasSetNickname'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
                 (user.metadata.creationTime ?? DateTime.now()),
      photoUrl: user.photoURL ?? data['photoUrl'] as String?,
    );
  }

  /// 이메일로부터 기본 지역을 가져옵니다
  Region _getDefaultRegionFromEmail(String email) {
    final universityCode = _localRepo.getUniversityCodeByEmailDomain(email);
    if (universityCode != null) {
      final region = _localRepo.getDefaultRegionByUniversity(universityCode);
      if (region != null) {
        return region;
      }
    }
    return defaultRegion;
  }

  /// 이메일과 비밀번호로 로그인합니다.
  ///
  /// Parameters:
  /// - [email]: 로그인할 이메일 주소
  /// - [password]: 비밀번호
  ///
  /// Returns:
  /// - [String?]: 성공 시 null, 실패 시 에러 메시지
  Future<String?> login(String email, String password) async {
    setState(loading: true, resetError: true);
    try {
      if (AppConfig.useFirebase) {
        await _auth!
            .signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('로그인 요청 시간 초과');
              },
            );
        return null;
      } else {
        final errorMessage =
            await _localRepo.login(email.trim(), password.trim());
        if (errorMessage != null) {
          setState(errorMessage: errorMessage);
        }
        return errorMessage;
      }
    } on TimeoutException {
      final errorMsg = '네트워크 연결이 불안정합니다. 인터넷 연결을 확인하고 다시 시도해주세요.';
      setState(errorMessage: errorMsg);
      return errorMsg;
    } on FirebaseAuthException catch (e) {
      final errorMsg = _getErrorMessage(e.code);
      setState(errorMessage: errorMsg);
      return errorMsg;
    } catch (e) {
      final errorMsg = '로그인 중 오류가 발생했습니다: ${e.toString()}';
      setState(errorMessage: errorMsg);
      return errorMsg;
    } finally {
      setState(loading: false);
    }
  }

  /// 이메일과 비밀번호로 회원가입합니다.
  ///
  /// Parameters:
  /// - [email]: 가입할 이메일 주소
  /// - [password]: 비밀번호
  ///
  /// Returns:
  /// - [String?]: 성공 시 null, 실패 시 에러 메시지
  Future<String?> signUp(String email, String password) async {
    setState(loading: true, errorMessage: null);
    try {
      if (AppConfig.useFirebase) {
        final userCredential = await _auth!
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('회원가입 요청 시간 초과');
              },
            );

        final user = userCredential.user;
        if (user != null) {
          // Firestore에 사용자 정보 저장 (학교 정보 포함)
          try {
            final email = user.email ?? '';
            final universityCode = _localRepo.getUniversityCodeByEmailDomain(email);
            final region = universityCode != null
                ? _localRepo.getDefaultRegionByUniversity(universityCode)
                : null;
            
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'uid': user.uid,
              'email': email,
              'name': '', // 닉네임 설정 전에는 빈 문자열
              'photoUrl': user.photoURL,
              'universityId': universityCode ?? 'UNKNOWN',
              'region': region != null ? {
                'code': region.code,
                'name': region.name,
                'level': region.level,
                'parent': region.parent,
              } : null,
              'emailVerified': user.emailVerified,
              'hasSetNickname': false, // 닉네임 미설정 상태
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            
            debugPrint('사용자 정보 저장 성공: ${user.email}, 학교: $universityCode');
          } catch (e) {
            debugPrint('사용자 정보 저장 실패: $e');
          }
          
          if (!user.emailVerified) {
            try {
              await user.sendEmailVerification();
              debugPrint('인증 이메일 발송 성공: ${user.email}');
            } catch (e) {
              debugPrint('인증 이메일 발송 실패: $e');
            }
          }
        }
        return null;
      } else {
        final errorMessage =
            await _localRepo.signUp(email.trim(), password.trim());
        if (errorMessage != null) {
          setState(errorMessage: errorMessage);
        }
        return errorMessage;
      }
    } on TimeoutException {
      final errorMsg = '네트워크 연결이 불안정합니다. 인터넷 연결을 확인하고 다시 시도해주세요.';
      setState(errorMessage: errorMsg);
      return errorMsg;
    } on FirebaseAuthException catch (e) {
      final errorMsg = _getErrorMessage(e.code);
      setState(errorMessage: errorMsg);
      return errorMsg;
    } catch (e) {
      final errorMsg = '회원가입 중 오류가 발생했습니다: ${e.toString()}';
      setState(errorMessage: errorMsg);
      return errorMsg;
    } finally {
      setState(loading: false);
    }
  }

  /// 로그아웃을 수행
  /// 사용자 정보를 초기화한 후 UI에 변경사항을 알림
  Future<void> logout() async {
    if (AppConfig.useFirebase) {
      await _auth?.signOut();
    } else {
      await _localRepo.logout();
    }
    _user = null;
    notifyListeners();
  }

  /// 닉네임 설정
  ///
  /// Firestore 트랜잭션을 사용하여 닉네임 중복을 원자적으로 방지합니다.
  /// nicknames 컬렉션에 닉네임을 문서 ID로 사용하여 uniqueness를 보장합니다.
  Future<String?> updateNickname(String nickname) async {
    if (_user == null) {
      return '로그인된 사용자가 없습니다.';
    }

    setState(loading: true, resetError: true);
    try {
      if (AppConfig.useFirebase) {
        /// 트랜잭션을 사용하여 닉네임 중복 방지 및 업데이트
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final nicknameRef = FirebaseFirestore.instance
              .collection('nicknames')
              .doc(nickname);
          final nicknameDoc = await transaction.get(nicknameRef);

          // 닉네임이 이미 존재하는지 확인
          if (nicknameDoc.exists) {
            final existingUid = nicknameDoc.data()?['uid'] as String?;
            // 다른 사용자가 이미 사용 중인 닉네임인 경우
            if (existingUid != _user!.uid) {
              throw Exception('nickname-already-in-use');
            }
            // 현재 사용자가 이미 설정한 닉네임인 경우는 통과
          }

          // 닉네임 문서 생성 또는 업데이트로 선점
          transaction.set(nicknameRef, {
            'uid': _user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 사용자 프로필 업데이트
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.uid);
          transaction.update(userRef, {
            'displayName': nickname,
            'name': nickname,
            'hasSetNickname': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        /// 로컬 사용자 정보 업데이트
        _user = _user!.copyWith(
          displayName: nickname,
          hasSetNickname: true,
        );
        notifyListeners();
        return null;
      } else {
        /// 로컬 모드에서는 로컬 저장소 업데이트
        _user = _user!.copyWith(
          displayName: nickname,
          hasSetNickname: true,
        );
        notifyListeners();
        return null;
      }
    } catch (e) {
      final errorMsg = e.toString().contains('nickname-already-in-use')
          ? '이미 사용 중인 닉네임입니다.'
          : '닉네임 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      setState(errorMessage: errorMsg);
      return errorMsg;
    } finally {
      setState(loading: false);
    }
  }

  /// 사용자 정보 다시 로드
  ///
  /// 이메일 인증 완료 등으로 사용자 정보가 변경되었을 때 호출합니다.
  Future<void> reloadUser() async {
    if (AppConfig.useFirebase) {
      final currentUser = _auth?.currentUser;
      if (currentUser != null) {
        try {
          /// Firebase Auth 사용자 정보 새로고침
          await currentUser.reload();
          final refreshedUser = _auth?.currentUser;

          if (refreshedUser != null) {
            /// Firestore에서 최신 사용자 정보 가져오기
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(refreshedUser.uid)
                .get();

            if (userDoc.exists) {
              _user = _createAppUserProfile(refreshedUser, userDoc);
            } else {
              _user = _mapFirebaseUser(refreshedUser);
            }
            notifyListeners();
            debugPrint(' 사용자 정보 새로고침 완료: emailVerified=${_user?.emailVerified}');
          }
        } catch (e) {
          debugPrint(' 사용자 정보 새로고침 실패: $e');
        }
      }
    } else {
      debugPrint('로컬 모드에서는 사용자 정보 새로고침이 필요하지 않습니다.');
    }
  }

  /// 상태를 업데이트하는 헬퍼 메서드
  void setState({
    bool? loading,
    bool resetError = false,
    String? errorMessage,
  }) {
    if (loading != null) {
      _loading = loading;
    }
    if (resetError) {
      _errorMessage = null;
    }
    if (errorMessage != null) {
      _errorMessage = errorMessage;
    }
    notifyListeners();
  }

  /// Firebase Auth 에러 코드를 한글 메시지로 변환
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다';
      case 'user-not-found':
        return '등록되지 않은 이메일입니다';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다';
      case 'weak-password':
        return '비밀번호가 너무 약합니다 (6자 이상)';
      case 'operation-not-allowed':
        return '이메일/비밀번호 로그인이 활성화되지 않았습니다';
      case 'too-many-requests':
        return '너무 많은 요청이 있었습니다. 나중에 다시 시도해주세요';
      case 'user-disabled':
        return '이 계정은 비활성화되었습니다';
      default:
        return '인증 오류: $code';
    }
  }

  AppUserProfile _mapFirebaseUser(User user) {
    // Firestore에서 사용자 정보 가져오기
    if (AppConfig.useFirebase) {
      // 비동기적으로 Firestore에서 정보를 가져오지만,
      // 동기적으로 반환해야 하므로 기본값 사용 후 업데이트
      final email = user.email ?? '';
      final universityCode = _localRepo.getUniversityCodeByEmailDomain(email);
      final region = universityCode != null
          ? _localRepo.getDefaultRegionByUniversity(universityCode)
          : defaultRegion;
      
      return AppUserProfile(
        uid: user.uid,
        displayName: user.displayName ?? (email.split('@').first),
        email: email,
        region: region ?? defaultRegion,
        universityId: universityCode ?? 'UNKNOWN',
        emailVerified: user.emailVerified,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        photoUrl: user.photoURL,
      );
    } else {
      return AppUserProfile(
        uid: user.uid,
        displayName: user.displayName ?? (user.email ?? '사용자'),
        email: user.email ?? '',
        region: defaultRegion,
        universityId: 'UNKNOWN',
        emailVerified: user.emailVerified,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        photoUrl: user.photoURL,
      );
    }
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _localSubscription?.cancel();
    super.dispose();
  }
}
