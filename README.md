# 당근마켓 클론 프로젝트

Flutter 기반 중고거래 앱 프로젝트입니다. Firebase, Google Maps, Kakao 로그인 등의 기능을 사용합니다.

## ✨ 주요 기능

### 상품 관리
- 상품 등록, 수정, 삭제
- 상품 목록 표시 (카테고리별 필터링)
- 상품 상세 페이지
- 상품 검색 기능
- 상품 공유 기능

### 위치 기반 기능
- 현재 위치 기반 상품 필터링
- 학교 주변 상품 필터링
- 검색 반경 조정 (500m, 1km, 2km, 5km)
- 거리순 정렬
- 지도에서 상품 위치 확인
- 위치 정보 저장 (SharedPreferences)

### 채팅 기능
- 실시간 1:1 채팅
- 채팅방 목록 (판매/구매 필터링)
- 채팅방 정렬 (최신순, 안 읽은 순, 이름순)
- 위치 정보 공유
- 읽지 않은 메시지 카운트

### 사용자 기능
- 카카오 로그인
- 이메일 회원가입/로그인
- 프로필 페이지
- 내가 등록한 상품 관리
- 찜한 상품 목록
- 판매자 프로필 보기

### 기타 기능
- 광고 표시 (상품 목록에 삽입)
- 카테고리별 필터링
- 상품 상태 관리 (판매중, 예약중, 판매완료)

## 📋 사전 준비사항

프로젝트를 시작하기 전에 다음 계정 및 키가 필요합니다:

- ✅ **Firebase 프로젝트** (Firebase Console에서 생성)
  - Android, iOS, macOS, Web 플랫폼 등록
  - Firebase 프로젝트 ID 확인
- ✅ **Google Cloud Console** - Google Maps API 키 발급
- ✅ **Kakao Developers** - 카카오 앱 등록 및 키 발급
  - 네이티브 앱 키
  - JavaScript 앱 키

## 👨‍💻 개발 가이드

프로젝트에 기능을 추가하거나 수정할 때는 [CONTRIBUTING.md](CONTRIBUTING.md) 파일을 참고하세요.

## 🚀 빠른 시작 (Quick Start)

프로젝트를 클론한 후 다음 단계를 따라 설정하세요:

1. **의존성 설치**
   ```bash
   flutter pub get
   ```

2. **필수 설정 파일 생성** (아래 섹션 참고)
   - Firebase 설정 파일들
   - API 키 설정 파일들

3. **앱 실행**
   ```bash
   flutter run
   ```

## 🔐 API 키 및 설정 파일 생성 가이드

> ⚠️ **중요**: 이 프로젝트는 보안을 위해 API 키를 Git에 포함하지 않습니다.  
> 프로젝트를 클론한 후 **반드시** 아래 단계를 따라 설정 파일을 생성해야 합니다.

### 1. Firebase 설정 파일 생성

#### Android
```bash
# 템플릿 파일 복사
cp android/app/google-services.json.example android/app/google-services.json
```

**설정 방법:**
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택 → 프로젝트 설정 → 내 앱
3. Android 앱 선택 → `google-services.json` 다운로드
4. 다운로드한 파일을 `android/app/google-services.json`에 저장

#### iOS
```bash
# 템플릿 파일 복사
cp ios/Runner/GoogleService-Info.plist.example ios/Runner/GoogleService-Info.plist
```

**설정 방법:**
1. Firebase Console → 프로젝트 설정 → 내 앱
2. iOS 앱 선택 → `GoogleService-Info.plist` 다운로드
3. 다운로드한 파일을 `ios/Runner/GoogleService-Info.plist`에 저장

#### macOS
```bash
# 템플릿 파일 복사
cp macos/Runner/GoogleService-Info.plist.example macos/Runner/GoogleService-Info.plist
```

**설정 방법:**
1. Firebase Console → 프로젝트 설정 → 내 앱
2. macOS 앱 선택 → `GoogleService-Info.plist` 다운로드
3. 다운로드한 파일을 `macos/Runner/GoogleService-Info.plist`에 저장

#### Flutter (모든 플랫폼)
```bash
# 템플릿 파일 복사
cp lib/firebase_options.dart.example lib/firebase_options.dart
```

**설정 방법 (권장): FlutterFire CLI 사용**
```bash
# FlutterFire CLI 설치 (아직 안 했다면)
dart pub global activate flutterfire_cli

# Firebase 프로젝트와 연결하여 자동 생성
flutterfire configure
```

또는 템플릿 파일(`lib/firebase_options.dart`)을 열어서 `YOUR_*` 부분을 Firebase Console의 실제 값으로 수동 교체하세요.

### 2. API 키 설정

#### Kakao API 키 (Flutter/Dart 코드)
```bash
# 템플릿 파일 복사
cp lib/config/api_keys.dart.example lib/config/api_keys.dart
```

**설정 방법:**
1. [Kakao Developers](https://developers.kakao.com/) 접속
2. 내 애플리케이션 → 애플리케이션 추가하기
3. 앱 설정 → 앱 키에서 다음 키 확인:
   - **네이티브 앱 키** (Native App Key)
   - **JavaScript 키** (JavaScript Key)
4. `lib/config/api_keys.dart` 파일을 열어서 `YOUR_*` 부분을 실제 키로 교체:
   ```dart
   class ApiKeys {
     static const String kakaoNativeAppKey = '실제_네이티브_앱_키';
     static const String kakaoJavaScriptAppKey = '실제_JavaScript_키';
   }
   ```

#### Google Maps & Kakao API 키 (Android)
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
   KAKAO_NATIVE_APP_KEY=실제_카카오_네이티브_앱_키
   ```

2. **Google Maps API 키 발급:**
   - [Google Cloud Console](https://console.cloud.google.com/) 접속
   - API 및 서비스 → 사용자 인증 정보
   - Maps SDK for Android 활성화 후 API 키 생성

3. **참고:** `build.gradle.kts`가 자동으로 `local.properties`의 값을 읽어 `AndroidManifest.xml`에 주입합니다.

#### Google Maps API 키 (iOS)
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

## ✅ 설정 완료 체크리스트

모든 설정이 완료되었는지 확인하세요:

- [ ] `android/app/google-services.json` 파일 생성됨
- [ ] `ios/Runner/GoogleService-Info.plist` 파일 생성됨
- [ ] `macos/Runner/GoogleService-Info.plist` 파일 생성됨 (macOS 개발 시)
- [ ] `lib/firebase_options.dart` 파일 생성됨
- [ ] `lib/config/api_keys.dart` 파일 생성 및 카카오 키 설정됨
- [ ] `android/local.properties` 파일 생성 및 API 키 설정됨
- [ ] `ios/Runner/Info.plist`에 Google Maps API 키 설정됨 (iOS 개발 시)

설정이 완료되면 `flutter run` 명령으로 앱을 실행할 수 있습니다.

## ⚠️ 주의사항 및 보안

### Git에 커밋하지 말아야 할 파일들
다음 파일들은 **절대 Git에 커밋하지 마세요** (이미 `.gitignore`에 포함되어 있음):

- `lib/firebase_options.dart`
- `lib/config/api_keys.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `android/local.properties`

### 템플릿 파일
템플릿 파일(`*.example`)은 Git에 포함되어 있으며, 이를 복사하여 사용하세요.

### 이미 Git에 커밋된 경우
만약 이전에 민감한 파일을 실수로 커밋했다면, 다음 명령으로 Git 추적만 중단하세요 (로컬 파일은 그대로 유지됨):

```bash
git rm --cached lib/firebase_options.dart
git rm --cached lib/config/api_keys.dart
git rm --cached android/app/google-services.json
git rm --cached ios/Runner/GoogleService-Info.plist
git rm --cached macos/Runner/GoogleService-Info.plist
git rm --cached android/local.properties
```

## 🐛 트러블슈팅

### Firebase 초기화 실패
- Firebase 설정 파일이 올바른 위치에 있는지 확인하세요
- Firebase 프로젝트의 패키지명/번들 ID가 일치하는지 확인하세요

### Google Maps가 작동하지 않음
- API 키가 올바르게 설정되었는지 확인하세요
- Google Cloud Console에서 Maps API가 활성화되어 있는지 확인하세요
- API 키에 플랫폼 제한(Android/iOS)이 설정되어 있다면 올바른 플랫폼인지 확인하세요

### 카카오 로그인이 작동하지 않음
- `lib/config/api_keys.dart`에 키가 올바르게 설정되었는지 확인하세요
- Android: `android/local.properties`의 `KAKAO_NATIVE_APP_KEY` 확인
- Kakao Developers에서 플랫폼 등록 및 리다이렉트 URI 설정 확인

## 📚 참고 자료

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [Firebase Flutter 문서](https://firebase.flutter.dev/)
- [Kakao Developers 가이드](https://developers.kakao.com/docs)
- [Google Maps Flutter 플러그인](https://pub.dev/packages/google_maps_flutter)
