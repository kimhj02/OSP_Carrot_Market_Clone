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
import 'package:firebase_auth/firebase_auth.dart';

/// 이메일 인증 상태를 관리하는 Provider 클래스
///
/// ChangeNotifier를 mixin하여 상태 변경 시 구독자들에게 알림을 보냅니다.
/// Firebase Auth를 사용하여 실제 인증 로직을 처리합니다.
class EmailAuthProvider with ChangeNotifier {
  /// Firebase Auth 인스턴스
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 현재 로그인된 사용자 정보
  /// null이면 로그인되지 않은 상태
  User? _user;

  /// 로딩 상태
  bool _loading = false;

  /// 에러 메시지
  String? _errorMessage;

  /// 현재 로그인된 사용자 정보를 반환합니다.
  User? get user => _user;

  /// 로딩 상태를 반환합니다.
  bool get loading => _loading;

  /// 에러 메시지를 반환합니다.
  String? get errorMessage => _errorMessage;

  /// 생성자 - Firebase Auth 상태 변화 리스너 등록
  EmailAuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
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
    setState(loading: true, errorMessage: null);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('로그인 요청 시간 초과');
        },
      );
      return null;
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
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('회원가입 요청 시간 초과');
        },
      );
      return null;
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

  /// 로그아웃을 수행합니다.
  ///
  /// 사용자 정보를 초기화한 후 UI에 변경사항을 알립니다.
  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  /// 상태를 업데이트하는 헬퍼 메서드
  void setState({bool? loading, String? errorMessage}) {
    if (loading != null) _loading = loading;
    if (errorMessage != null) _errorMessage = errorMessage;
    notifyListeners();
  }

  /// Firebase Auth 에러 코드를 한글 메시지로 변환합니다.
  String _getErrorMessage(String code) {
    switch (code) {
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
}