# Firebase Cloud Functions

이 폴더에는 Firebase Cloud Functions 코드가 포함되어 있습니다.

## 주요 기능

### 1. sendChatNotification
- `notificationRequests` 컬렉션에 새 문서가 추가되면 자동으로 실행됩니다.
- FCM을 통해 푸시 알림을 전송합니다.
- 알림 전송 후 요청 문서를 삭제합니다.

### 2. onUserUpdate
- 사용자 정보가 업데이트될 때 실행됩니다.
- FCM 토큰 변경을 감지합니다.

## 설치 및 배포

### 1. Node.js 설치 확인
```bash
node --version  # v18 이상 필요
```

### 2. Firebase CLI 설치
```bash
npm install -g firebase-tools
```

### 3. Firebase 로그인
```bash
firebase login
```

### 4. 프로젝트 초기화 (처음 한 번만)
```bash
firebase init functions
```

### 5. 의존성 설치
```bash
cd functions
npm install
```

### 6. Functions 배포
```bash
firebase deploy --only functions
```

## 로컬 테스트

```bash
npm run serve
```

## 로그 확인

```bash
firebase functions:log
```

## 주의사항

1. Firebase 프로젝트에 Functions가 활성화되어 있어야 합니다.
2. Blaze 플랜(유료)이 필요합니다 (무료 할당량 제공).
3. FCM 서버 키는 Firebase Console에서 자동으로 관리됩니다.

