/// 관리자 인증 서비스
///
/// Firestore의 admins 컬렉션에서 관리자 권한을 확인하는 서비스입니다.
/// 현재 로그인한 사용자가 관리자인지 확인하는 기능을 제공합니다.
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sandbox/config/app_config.dart';

/// 관리자 인증 서비스 클래스
class AdminService {
  /// Firestore 인스턴스 (Firebase 모드에서만 초기화)
  final FirebaseFirestore? _firestore =
      AppConfig.useFirebase ? FirebaseFirestore.instance : null;

  /// Firebase Auth 인스턴스 (Firebase 모드에서만 초기화)
  final FirebaseAuth? _auth =
      AppConfig.useFirebase ? FirebaseAuth.instance : null;

  /// 현재 로그인한 사용자가 관리자인지 확인하는 메서드
  ///
  /// Returns:
  ///   - true: 관리자 권한이 있는 경우
  ///   - false: 관리자 권한이 없거나 로그인하지 않은 경우
  Future<bool> isAdmin() async {
    if (!AppConfig.useFirebase) {
      return false;
    }
    try {
      final user = _auth?.currentUser;
      if (user == null || user.email == null) {
        return false;
      }

      final adminDoc = await _firestore!
          .collection('admins')
          .doc(user.email)
          .get();

      return adminDoc.exists && adminDoc.data() != null;
    } catch (e) {
      print('관리자 권한 확인 중 오류 발생: $e');
      return false;
    }
  }

  /// 특정 이메일이 관리자인지 확인하는 메서드
  ///
  /// Parameters:
  ///   - email: 확인할 이메일 주소
  ///
  /// Returns:
  ///   - true: 관리자 권한이 있는 경우r
  ///   - false: 관리자 권한이 없거나 이메일이 없는 경우
  Future<bool> isAdminByEmail(String email) async {
    if (!AppConfig.useFirebase) {
      return false;
    }
    try {
      if (email.isEmpty) {
        return false;
      }

      final adminDoc = await _firestore!
          .collection('admins')
          .doc(email)
          .get();

      return adminDoc.exists && adminDoc.data() != null;
    } catch (e) {
      print('관리자 권한 확인 중 오류 발생: $e');
      return false;
    }
  }

  /// 관리자 목록을 가져오는 메서드
  ///
  /// Returns:
  ///   - 관리자 이메일 목록
  Future<List<String>> getAdminEmails() async {
    if (!AppConfig.useFirebase) {
      return [];
    }
    try {
      final adminSnapshot = await _firestore!.collection('admins').get();
      return adminSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('관리자 목록 조회 중 오류 발생: $e');
      return [];
    }
  }
}

