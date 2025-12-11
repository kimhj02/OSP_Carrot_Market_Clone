# 바로 마켓 (당근마켓 클론)

## 사전 준비사항

- **Firebase 프로젝트** 생성 및 기본 설정
  - Android, iOS, Web 플랫폼 등록
  - Firebase 프로젝트 ID 확인
- **Google Cloud Console** - Google Maps API 키 발급

## 빠른 시작

> ⚠️ **중요**: 아래 단계를 **순서대로** 따라하세요. Firebase 설정을 먼저 완료해야 합니다.

### 단계별 설정 순서

1. **의존성 설치**
   ```bash
   flutter pub get
   ```

2. **Firebase 프로젝트 생성 및 설정** (아래 "Firebase 설정 가이드" 섹션 참고)
   - Firebase 프로젝트 생성
   - Authentication 설정
   - Firestore Database 설정
   - 보안 규칙 설정
   - Firebase 설정 파일 다운로드 및 추가

3. **API 키 설정** (아래 "API 키 및 설정 파일 생성 가이드" 섹션 참고)
   - Google Maps API 키 발급 및 설정

4. **앱 실행**
   ```bash
   flutter run
   ```

---

# Firebase 설정 가이드 (⚠️반드시 설정할 것)

## 1. Firebase 프로젝트 생성

### 1.1 Firebase Console 접속

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. "프로젝트 추가" 클릭

### 1.2 프로젝트 기본 정보 입력

- **프로젝트 이름**: 원하는 이름 입력 (예: "Baro Market")
- **Google Analytics**: 필요에 따라 활성화/비활성화
- **프로젝트 생성** 클릭

### 1.3 플랫폼 등록

#### Android

1. 프로젝트 설정 → 내 앱 → Android 앱 추가
2. 패키지 이름 입력 (예: `com.example.flutter_sandbox`)
3. `google-services.json` 다운로드
4. `android/app/` 폴더에 저장

#### iOS

1. 프로젝트 설정 → 내 앱 → iOS 앱 추가
2. 번들 ID 입력
3. `GoogleService-Info.plist` 다운로드
4. `ios/Runner/` 폴더에 저장

---

## 2. Authentication 설정

### 2.1 이메일/비밀번호 로그인 활성화

1. Firebase Console → **Authentication** → **로그인 방법** 탭
2. "이메일/비밀번호" 항목 찾기
3. **사용 설정** 토글 ON
4. **저장** 클릭

### 2.2 관리자 계정 생성

1. Authentication → **사용자** 탭
2. **사용자 추가** 버튼 클릭
3. 이메일과 비밀번호 입력
   - **이메일**: 관리자 이메일 (예: `admin@example.com`)
   - **비밀번호**: 임시 비밀번호 설정
4. **추가** 클릭

> ⚠️ **중요**: 관리자 비밀번호는 반드시 기록해두세요. 나중에 비밀번호 재설정 이메일을 보낼 수도 있습니다.

---

## 3. Firestore Database 설정

### 3.1 Firestore Database 생성

1. Firebase Console → **Firestore Database**
2. **데이터베이스 만들기** 클릭
3. **프로덕션 모드** 또는 **테스트 모드** 선택
   - 테스트 모드: 30일간 모든 읽기/쓰기 허용
   - 프로덕션 모드: 보안 규칙 필요 (4단계 참고)
4. **위치 선택** (가까운 지역 선택)
5. **사용 설정** 클릭

### 3.2 admins 컬렉션 생성

1. Firestore Database → **데이터** 탭
2. **컬렉션 시작** 클릭
3. 컬렉션 ID: `admins` 입력
4. **다음** 클릭
5. 문서 ID에 **관리자 이메일 주소 그대로** 입력 (예: `admin@example.com`)
   - ⚠️ **주의**: 이메일 주소를 정확히 입력해야 합니다. 공백이나 대소문자 차이가 있으면 안 됩니다.
6. 필드는 비워도 되지만, 선택적으로 추가 가능:
   - `role`: `admin` (문자열)
   - `createdAt`: 서버 타임스탬프
7. **저장** 클릭

### 3.3 ads 컬렉션 구조

`ads` 컬렉션은 관리자 페이지에서 광고를 추가하면 자동으로 생성됩니다.

**컬렉션 구조:**
```
ads/
  {자동생성ID}/
    - title: string (광고 제목)
    - description: string (광고 설명)
    - imageUrl: string (광고 이미지 URL)
    - linkUrl: string (광고 링크 URL)
    - position: number (상품 목록 삽입 위치)
    - isActive: boolean (활성화 여부)
    - createdAt: timestamp (생성일)
    - updatedAt: timestamp (수정일)
```

---

## 4. 보안 규칙 설정

### 4.1 Firestore 보안 규칙 수정

1. Firebase Console → **Firestore Database** → **규칙** 탭
2. 아래 규칙으로 교체:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // admins 컬렉션: 인증된 사용자만 읽기 가능
    match /admins/{email} {
      allow read: if request.auth != null;
      allow write: if false; // 쓰기는 콘솔에서만 가능
    }
    
    // ads 컬렉션: 
    // - 홈 화면: 모든 사용자가 읽을 수 있음 (광고는 공개 정보)
    // - 관리자 페이지: 관리자만 읽기 가능 (관리자 페이지는 앱 레벨에서 접근 제어)
    // - 쓰기: 관리자만 가능
    match /ads/{adId} {
      // 읽기: 모든 사용자 (홈 화면에서 보여주기 위해)
      allow read: if true;
      // 쓰기: 관리자만
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.token.email));
    }
    
    // 기타 컬렉션은 필요에 따라 설정
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

3. **게시** 버튼 클릭

### 4.2 규칙 설명

- **admins 컬렉션**:
  - 인증된 사용자만 읽기 가능
  - 쓰기는 콘솔에서만 가능 (보안을 위해)

- **ads 컬렉션**:
  - **모든 사용자가 읽기 가능** (홈 화면과 상품 목록에서 광고를 표시하기 위해)
  - 관리자만 쓰기 가능 (admins 컬렉션에 이메일이 있는 경우)

- **기타 컬렉션**:
  - 인증된 사용자만 읽기/쓰기 가능

---

## 5. 앱 설정 파일 추가

### 5.1 Android 설정

1. Firebase Console → 프로젝트 설정 → 내 앱 → Android 앱
2. `google-services.json` 다운로드
3. `android/app/google-services.json`에 저장

### 5.2 iOS 설정

1. Firebase Console → 프로젝트 설정 → 내 앱 → iOS 앱
2. `GoogleService-Info.plist` 다운로드
3. `ios/Runner/GoogleService-Info.plist`에 저장

### 5.3 macOS 설정 (macOS 개발 시)

1. Firebase Console → 프로젝트 설정 → 내 앱 → macOS 앱
2. `GoogleService-Info.plist` 다운로드
3. `macos/Runner/GoogleService-Info.plist`에 저장

### 5.4 Firebase Options 파일 생성

**권장 방법: FlutterFire CLI 사용**

FlutterFire CLI를 사용하면 Firebase 설정 파일들을 자동으로 생성하고 올바른 위치에 배치합니다:

```bash
# FlutterFire CLI 설치 (아직 안 했다면)
dart pub global activate flutterfire_cli

# Firebase 프로젝트와 연결하여 자동 생성
# 이 명령은 다음을 자동으로 수행합니다:
# - firebase_options.dart 파일 생성
# - google-services.json (Android) 자동 다운로드 및 배치
# - GoogleService-Info.plist (iOS/macOS) 자동 다운로드 및 배치
flutterfire configure
```

**수동 설정 방법:**

FlutterFire CLI를 사용하지 않는 경우, 아래 "API 키 및 설정 파일 생성 가이드" 섹션의 "Flutter (모든 플랫폼)" 부분을 참고하여 수동으로 설정하세요.

---

# API 키 및 설정 파일 생성 가이드

> ⚠️ **참고**: FlutterFire CLI (`flutterfire configure`)를 사용했다면, Firebase 설정 파일들은 이미 자동으로 생성되었습니다. 이 섹션은 수동 설정을 원하는 경우에만 참고하세요.

## 1. Firebase 설정 파일 수동 생성 (선택사항)

FlutterFire CLI를 사용하지 않는 경우에만 아래 방법을 따르세요.

### Android

```bash
# 템플릿 파일 복사
cp android/app/google-services.json.example android/app/google-services.json
```

**설정 방법:**

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택 → 프로젝트 설정 → 내 앱
3. Android 앱 선택 → `google-services.json` 다운로드
4. 다운로드한 파일을 `android/app/google-services.json`에 저장

### iOS

```bash
# 템플릿 파일 복사
cp ios/Runner/GoogleService-Info.plist.example ios/Runner/GoogleService-Info.plist
```

**설정 방법:**

1. Firebase Console → 프로젝트 설정 → 내 앱
2. iOS 앱 선택 → `GoogleService-Info.plist` 다운로드
3. 다운로드한 파일을 `ios/Runner/GoogleService-Info.plist`에 저장

### macOS

```bash
# 템플릿 파일 복사
cp macos/Runner/GoogleService-Info.plist.example macos/Runner/GoogleService-Info.plist
```

**설정 방법:**

1. Firebase Console → 프로젝트 설정 → 내 앱
2. macOS 앱 선택 → `GoogleService-Info.plist` 다운로드
3. 다운로드한 파일을 `macos/Runner/GoogleService-Info.plist`에 저장

### Flutter (모든 플랫폼)

```bash
# 템플릿 파일 복사
cp lib/firebase_options.dart.example lib/firebase_options.dart
```

**수동 설정 방법:**

1. `lib/firebase_options.dart` 파일을 열기
2. Firebase Console → 프로젝트 설정 → 일반 탭에서 각 플랫폼의 설정값 확인
3. `YOUR_*` 부분을 실제 값으로 교체:
   - `YOUR_PROJECT_ID` → 프로젝트 ID
   - `YOUR_ANDROID_API_KEY` → Android 앱의 API 키
   - `YOUR_IOS_API_KEY` → iOS 앱의 API 키
   - `YOUR_WEB_API_KEY` → Web 앱의 API 키
   - 기타 필요한 값들도 모두 교체

---

## 2. API 키 설정

### Google Maps API 키 (Android)

```bash
# 템플릿 파일 복사
cp android/local.properties.example android/local.properties
```

**설정 방법:**

1. `android/local.properties` 파일을 열어서 다음 값들을 설정:

   ```properties
   # SDK 경로 (Flutter가 자동으로 생성하지만 없으면 추가)
   sdk.dir=YOUR_ANDROID_SDK_PATH
   flutter.sdk=YOUR_FLUTTER_SDK_PATH
   
   # API Keys
   MAPS_API_KEY=실제_Google_Maps_API_키
   ```

2. **Google Maps API 키 발급:**
   - [Google Cloud Console](https://console.cloud.google.com/) 접속
   - API 및 서비스 → 사용자 인증 정보
   - Maps SDK for Android 활성화 후 API 키 생성

3. **참고:** `build.gradle.kts`가 자동으로 `local.properties`의 값을 읽어 `AndroidManifest.xml`에 주입합니다.

### Google Maps API 키 (iOS)

iOS는 빌드 시 자동 주입이 없으므로 **수동으로 설정**해야 합니다.

**설정 방법:**

1. `ios/Runner/Info.plist` 파일 열기
2. 다음 부분을 찾아서 실제 API 키로 교체:

   ```xml
   <key>GMSApiKey</key>
   <string>YOUR_GOOGLE_MAPS_API_KEY</string>
   ```

3. `YOUR_GOOGLE_MAPS_API_KEY`를 실제 Google Maps API 키로 교체

**Google Maps API 키 발급:**

- [Google Cloud Console](https://console.cloud.google.com/) 접속
- API 및 서비스 → 사용자 인증 정보
- Maps SDK for iOS 활성화 후 API 키 생성

---

## ✅ 설정 완료 체크리스트

모든 설정이 완료되었는지 확인하세요:

### Firebase 설정
- [ ] Firebase 프로젝트 생성 완료
- [ ] Authentication에서 이메일/비밀번호 로그인 활성화됨
- [ ] 관리자 계정 생성됨
- [ ] Firestore Database 생성됨
- [ ] `admins` 컬렉션 생성됨 (문서 ID = 관리자 이메일)
- [ ] Firestore 보안 규칙 설정 및 게시됨
- [ ] `android/app/google-services.json` 파일 생성됨 (Android 개발 시)
- [ ] `ios/Runner/GoogleService-Info.plist` 파일 생성됨 (iOS 개발 시)
- [ ] `macos/Runner/GoogleService-Info.plist` 파일 생성됨 (macOS 개발 시)
- [ ] `lib/firebase_options.dart` 파일 생성됨

### API 키 설정
- [ ] Google Maps API 키 발급 완료
- [ ] `android/local.properties` 파일 생성 및 `MAPS_API_KEY` 설정됨 (Android 개발 시)
- [ ] `ios/Runner/Info.plist`에 `GMSApiKey` 설정됨 (iOS 개발 시)

### 실행 준비
- [ ] `flutter pub get` 실행 완료
- [ ] 모든 체크리스트 항목 완료

설정이 완료되면 `flutter run` 명령으로 앱을 실행할 수 있습니다.

---

## 🐛 트러블슈팅

### Firebase 초기화 실패

- Firebase 설정 파일이 올바른 위치에 있는지 확인하세요
- Firebase 프로젝트의 패키지명/번들 ID가 일치하는지 확인하세요

### Google Maps가 작동하지 않음

- API 키가 올바르게 설정되었는지 확인하세요
- Google Cloud Console에서 Maps API가 활성화되어 있는지 확인하세요
- API 키에 플랫폼 제한(Android/iOS)이 설정되어 있다면 올바른 플랫폼인지 확인하세요

### "관리자 권한이 없습니다" 오류

- `admins` 컬렉션에 문서가 있는지 확인
- 문서 ID가 로그인 이메일과 정확히 일치하는지 확인
- Firestore 보안 규칙이 올바르게 설정되었는지 확인

### "PERMISSION_DENIED" 오류

- Firestore 보안 규칙을 확인하세요
- 인증된 사용자가 읽기 권한을 가지고 있는지 확인

### 로그인이 안 되는 경우

- Authentication에서 이메일/비밀번호 로그인이 활성화되어 있는지 확인
- 네트워크 연결 상태 확인
- 비밀번호가 올바른지 확인

---

## 📚 참고 자료

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [Firebase Flutter 문서](https://firebase.flutter.dev/)
- [Google Maps Flutter 플러그인](https://pub.dev/packages/google_maps_flutter)
- [Firebase 공식 문서](https://firebase.google.com/docs)
- [Firestore 보안 규칙 가이드](https://firebase.google.com/docs/firestore/security/get-started)
- [FlutterFire 문서](https://firebase.flutter.dev/)
