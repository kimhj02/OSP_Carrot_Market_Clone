/**
 * Firebase Cloud Functions
 * 
 * 채팅 메시지 알림 전송을 처리하는 함수입니다.
 * 
 * @author Flutter Sandbox
 * @version 1.0.0
 * @since 2024-01-01
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * notificationRequests 컬렉션에 새 문서가 추가되면
 * FCM을 통해 푸시 알림을 전송합니다.
 */
exports.sendChatNotification = functions.firestore
  .document('notificationRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const { recipientFcmToken, title, body, data } = requestData;

    // FCM 토큰이 없으면 알림 전송 불가
    if (!recipientFcmToken) {
      console.log('❌ FCM 토큰이 없습니다. 알림을 전송할 수 없습니다.');
      
      // 알림 요청 문서 삭제 (토큰이 없어도 처리 완료로 간주)
      try {
        await snap.ref.delete();
        console.log('✅ 알림 요청 문서 삭제 성공 (토큰 없음)');
      } catch (error) {
        console.error('❌ 알림 요청 문서 삭제 실패 (토큰 없음):', error);
      }
      
      return null;
    }

    // 알림 메시지 구성
    const message = {
      token: recipientFcmToken,
      notification: {
        title: title || '새 메시지',
        body: body || '메시지가 도착했습니다',
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'chat_messages',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      // FCM을 통해 알림 전송
      const response = await admin.messaging().send(message);
      console.log('✅ 알림 전송 성공:', response);
      
      // 알림 요청 문서 삭제 (성공적으로 처리됨)
      await snap.ref.delete();
      
      return null;
    } catch (error) {
      console.error('❌ 알림 전송 실패:', error);
      
      // 실패한 경우에도 문서를 삭제하여 무한 루프 방지
      // 필요시 재시도 로직 추가 가능
      await snap.ref.delete();
      
      return null;
    }
  });

/**
 * 사용자가 로그인할 때 FCM 토큰을 업데이트합니다.
 */
exports.onUserUpdate = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    // FCM 토큰이 새로 추가되었거나 변경된 경우
    const fcmTokenBefore = beforeData.fcmToken;
    const fcmTokenAfter = afterData.fcmToken;

    if (fcmTokenAfter && fcmTokenAfter !== fcmTokenBefore) {
      console.log(`✅ 사용자 ${userId}의 FCM 토큰이 업데이트되었습니다.`);
    }

    return null;
  });

