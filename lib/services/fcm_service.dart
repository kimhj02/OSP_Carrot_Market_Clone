/// Firebase Cloud Messaging 서비스
///
/// 푸시 알림 기능을 관리하는 서비스 클래스입니다.
///
/// 주요 기능:
/// - FCM 토큰 관리
/// - 알림 권한 요청
/// - 포그라운드/백그라운드 알림 처리
/// - 채팅 메시지 알림 전송
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sandbox/config/app_config.dart';

/// Firebase Cloud Messaging 서비스 싱글톤
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  /// FCM 토큰을 반환합니다.
  String? get fcmToken => _fcmToken;

  /// FCM 초기화 및 설정
  Future<void> initialize() async {
    if (!AppConfig.useFirebase) return;

    try {
      // 알림 권한 요청 (iOS)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ 사용자가 알림 권한을 허용했습니다');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ 사용자가 임시 알림 권한을 허용했습니다');
      } else {
        debugPrint('❌ 사용자가 알림 권한을 거부했습니다');
        return;
      }

      // FCM 토큰 가져오기
      _fcmToken = await _messaging.getToken();
      debugPrint('✅ FCM 토큰: $_fcmToken');

      // 토큰 갱신 리스너
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 FCM 토큰 갱신: $newToken');
        _saveTokenToFirestore(newToken);
      });

      // 포그라운드 메시지 핸들러
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 백그라운드 메시지 핸들러 (앱이 종료된 상태에서 메시지 수신)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // 앱이 종료된 상태에서 알림을 탭하여 앱을 열었을 때
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      // 토큰을 Firestore에 저장
      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
      }
    } catch (e) {
      debugPrint('❌ FCM 초기화 실패: $e');
    }
  }

  /// 사용자의 FCM 토큰을 Firestore에 저장
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ FCM 토큰 저장 실패: $e');
    }
  }

  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 포그라운드 메시지 수신: ${message.notification?.title}');
    debugPrint('📨 메시지 내용: ${message.notification?.body}');
    debugPrint('📨 데이터: ${message.data}');

    // 포그라운드에서는 FlutterLocalNotifications를 사용하여 알림 표시
    // 여기서는 간단히 로그만 출력 (필요시 flutter_local_notifications 패키지 추가 가능)
  }

  /// 백그라운드 메시지 처리
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📨 백그라운드 메시지 수신: ${message.notification?.title}');
    // 채팅 페이지로 이동하는 로직은 여기에 추가 가능
  }

  /// 채팅 메시지 알림 전송
  ///
  /// Parameters:
  /// - [recipientUid]: 알림을 받을 사용자 UID
  /// - [senderName]: 발신자 이름
  /// - [message]: 메시지 내용
  /// - [chatRoomId]: 채팅방 ID
  Future<void> sendChatNotification({
    required String recipientUid,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    if (!AppConfig.useFirebase) return;

    try {
      // 수신자의 FCM 토큰 가져오기
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .get();

      if (!recipientDoc.exists) {
        debugPrint('❌ 수신자 정보를 찾을 수 없습니다: $recipientUid');
        return;
      }

      final recipientData = recipientDoc.data()!;
      final recipientFcmToken = recipientData['fcmToken'] as String?;

      if (recipientFcmToken == null) {
        debugPrint('❌ 수신자의 FCM 토큰이 없습니다: $recipientUid');
        return;
      }

      // 알림 설정 확인
      final notificationsEnabled = recipientData['notificationsEnabled'] as bool? ?? true;
      if (!notificationsEnabled) {
        debugPrint('ℹ️ 수신자가 알림을 비활성화했습니다: $recipientUid');
        return;
      }

      // FCM을 통해 알림 전송
      // 주의: 실제 프로덕션에서는 Cloud Functions를 사용하는 것이 권장됩니다
      // 여기서는 클라이언트 측에서 직접 전송 (제한적)
      // Cloud Functions를 사용하려면 서버 측 코드가 필요합니다

      debugPrint('📤 알림 전송 시도: $recipientFcmToken');
      
      // 실제로는 Cloud Functions의 sendNotification 함수를 호출해야 합니다
      // 여기서는 Firestore에 알림 요청을 저장하고 Cloud Functions가 처리하도록 할 수 있습니다
      // 또는 직접 HTTP 요청으로 FCM API를 호출할 수 있습니다 (서버 키 필요)

      // 임시로 Firestore에 알림 요청 저장 (Cloud Functions가 처리하도록)
      await FirebaseFirestore.instance
          .collection('notificationRequests')
          .add({
        'recipientUid': recipientUid,
        'recipientFcmToken': recipientFcmToken,
        'title': senderName,
        'body': message,
        'data': {
          'type': 'chat',
          'chatRoomId': chatRoomId,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 알림 요청 저장 완료');
    } catch (e) {
      debugPrint('❌ 알림 전송 실패: $e');
    }
  }

  /// 사용자 로그인 시 FCM 토큰 저장
  Future<void> saveTokenForUser(String userId) async {
    if (!AppConfig.useFirebase) return;
    if (_fcmToken == null) {
      _fcmToken = await _messaging.getToken();
    }
    if (_fcmToken != null) {
      await _saveTokenToFirestore(_fcmToken!);
    }
  }

  /// 사용자 로그아웃 시 FCM 토큰 삭제
  Future<void> deleteTokenForUser(String userId) async {
    if (!AppConfig.useFirebase) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('❌ FCM 토큰 삭제 실패: $e');
    }
  }
}

/// 백그라운드 메시지 핸들러 (최상위 함수)
/// 앱이 백그라운드에 있을 때 호출됩니다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 백그라운드 메시지 처리: ${message.messageId}');
  debugPrint('📨 제목: ${message.notification?.title}');
  debugPrint('📨 내용: ${message.notification?.body}');
}

