# Firebase Cloud Functions 설정 가이드

이 가이드는 Firebase Cloud Functions를 설정하여 실제 푸시 알림을 전송하는 방법을 설명합니다.

## 사전 요구사항

1. **Node.js 설치** (v18 이상)
   ```bash
   node --version
   ```

2. **Firebase CLI 설치**
   ```bash
   npm install -g firebase-tools
   ```

3. **Firebase 프로젝트 설정**
   - Firebase Console에서 프로젝트 생성
   - Functions 기능 활성화
   - Blaze 플랜(유료) 활성화 필요 (무료 할당량 제공)

## 설정 단계

### 1. Firebase 로그인
```bash
firebase login
```

### 2. 프로젝트 초기화
프로젝트 루트 디렉토리에서 실행:
```bash
firebase init functions
```

선택 사항:
- 기존 프로젝트 선택 또는 새 프로젝트 생성
- JavaScript 언어 선택
- ESLint 사용 여부 (선택)
- 의존성 설치 (Y)

### 3. Functions 폴더로 이동 및 의존성 설치
```bash
cd functions
npm install
```

### 4. Functions 배포
```bash
# 프로젝트 루트에서
firebase deploy --only functions
```

또는 Functions 폴더에서:
```bash
cd functions
npm run deploy
```

## 작동 방식

1. **앱에서 메시지 전송**
   - 사용자가 채팅 메시지를 보내면 `chat_page.dart`에서 `FCMService.sendChatNotification()` 호출
   - 알림 요청이 `notificationRequests` 컬렉션에 저장됨

2. **Cloud Functions 트리거**
   - `notificationRequests` 컬렉션에 새 문서가 추가되면 `sendChatNotification` 함수 자동 실행
   - 함수가 FCM을 통해 실제 푸시 알림 전송
   - 전송 완료 후 요청 문서 삭제

3. **사용자 기기에서 알림 수신**
   - 앱이 백그라운드/종료 상태: 시스템 알림 표시
   - 앱이 포그라운드: `FCMService`의 핸들러에서 처리

## 로컬 테스트

### Functions 에뮬레이터 실행
```bash
cd functions
npm run serve
```

### Firestore 에뮬레이터와 함께 실행
```bash
firebase emulators:start --only functions,firestore
```

## 로그 확인

### 실시간 로그
```bash
firebase functions:log
```

### 특정 함수 로그만 보기
```bash
firebase functions:log --only sendChatNotification
```

## 문제 해결

### 1. Functions 배포 실패
- Firebase 프로젝트에 Functions가 활성화되어 있는지 확인
- Blaze 플랜이 활성화되어 있는지 확인
- `firebase login` 상태 확인

### 2. 알림이 전송되지 않음
- FCM 토큰이 올바르게 저장되었는지 확인
- `notificationRequests` 컬렉션에 문서가 생성되는지 확인
- Functions 로그에서 에러 확인

### 3. 권한 오류
- Firebase Console에서 Functions 권한 확인
- 서비스 계정 권한 확인

## 비용

- **Blaze 플랜**: 무료 할당량 제공
  - 첫 2M 함수 호출/월 무료
  - 첫 400K GB-초, 200K GHz-초 컴퓨팅 시간 무료
  - FCM: 무료 (무제한)

## 추가 개선 사항

1. **재시도 로직**: 알림 전송 실패 시 재시도
2. **배치 알림**: 여러 알림을 한 번에 전송
3. **알림 통계**: 알림 전송 성공/실패 통계 수집
4. **알림 스케줄링**: 특정 시간에 알림 전송

## 참고 자료

- [Firebase Cloud Functions 문서](https://firebase.google.com/docs/functions)
- [FCM 문서](https://firebase.google.com/docs/cloud-messaging)
- [Firebase CLI 문서](https://firebase.google.com/docs/cli)

