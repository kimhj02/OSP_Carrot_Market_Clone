/// Flutter 앱의 진입점
///
/// 이 파일은 앱의 시작점으로, 다음과 같은 역할을 합니다:
/// 1. Flutter 바인딩 초기화
/// 2. 카카오 SDK 초기화
/// 3. Provider를 사용한 상태 관리 설정
/// 4. 메인 앱 위젯 실행
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:provider/provider.dart';
import 'package:flutter_sandbox/firebase_options.dart';
import 'package:flutter_sandbox/providers/kakao_login_provider.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/providers/ad_provider.dart';
import 'package:flutter_sandbox/pages/home_page.dart';
import 'package:flutter_sandbox/pages/verify_email_page.dart';
import 'package:flutter_sandbox/pages/email_auth_page.dart';
/// 앱의 메인 진입점
///
/// Flutter 앱이 시작될 때 가장 먼저 실행되는 함수입니다.
/// 카카오 SDK를 초기화하고 Provider를 설정한 후 앱을 실행합니다.
///
// Firebase 기능 사용 여부 플래그 (false면 Firebase 비활성화)

//const bool kUseFirebase = false;

const bool kUseFirebase = true; //Firebase 활성화시 주석 제거

Future<void> main() async {
  // Flutter 바인딩을 초기화합니다.
  // 이는 Flutter 엔진과의 통신을 위한 필수 단계입니다.
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (비활성화 시 건너뜀)
  if (kUseFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase 초기화 성공');
    } catch (e) {
      // 초기화 실패 시에도 앱이 구동되도록 경고만 출력
      print('⚠️ Firebase 초기화 실패: $e');
    }
  }

  // 앱을 실행합니다.
  // MultiProvider를 사용하여 여러 Provider를 앱 전체에 제공합니다.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => KakaoLoginProvider()),
        ChangeNotifierProvider(create: (context) => EmailAuthProvider()),
        ChangeNotifierProvider(create: (context) => AdProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// 메인 앱 위젯
///
/// MaterialApp을 반환하여 앱의 기본 구조를 설정합니다.
/// 테마와 홈 화면을 지정합니다.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '금오 마켓', // 앱 제목
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ), // 기본 테마 (청록색 기반)
      home: const AuthCheck(),
    );
  }
}
/// 로그인 상태에 따라 화면 흐름제어
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {

    final User? user = context.watch<EmailAuthProvider>().user;

    /// 로그아웃 상태
    if (user == null) {
      return const EmailAuthPage();
    }
    /// 로그인 상태
    else {
      /// 메일 인증 여부 확인
      if (user.emailVerified) {
        /// 인증 완료 시 메인 홈 페이지
        return const HomePage();
      } else {
        /// 인증 미완료 시 이메일 인증 대기 페이지
        return const VerifyEmailPage();
      }
    }
  }
}