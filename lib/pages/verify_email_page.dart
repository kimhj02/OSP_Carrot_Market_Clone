import 'dart:async'; // Timer를 사용하기 위해 import
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/config/app_config.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? _timer;
  bool _isSendingEmail = false;

  @override
  void initState() {
    super.initState();


    if (AppConfig.useFirebase) {
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!AppConfig.useFirebase) {
          timer.cancel();
          return;
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          timer.cancel();
          return;
        }
        await currentUser.reload();
        if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
          timer.cancel();
          debugPrint('✅ 이메일 인증 확인됨. 사용자 정보를 새로고침합니다.');

          /// EmailAuthProvider의 사용자 정보를 새로고침하여 화면 전환 트리거
          if (mounted) {
            final authProvider = context.read<EmailAuthProvider>();
            await authProvider.reloadUser();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); /// 화면이 사라질 때 타이머도 종료
    super.dispose();
  }

  /// 인증 이메일 재전송 함수
  Future<void> _resendVerificationEmail() async {
    if (!AppConfig.useFirebase) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로컬 모드에서는 인증이 필요하지 않습니다.')),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSendingEmail = true);
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증 이메일을 다시 전송했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  /// 재전송 확인 다이얼로그 함수
  Future<void> _showResendConfirmationDialog() async {

    if (_isSendingEmail) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('이메일 재전송'),
          content: const Text('인증 이메일을 다시 전송하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    /// 사용자가 '확인'을 눌렀을 때 재전송 함수 호출
    if (confirmed == true) {
      /// await showDialog 이후에 mounted를  확인
      if (mounted) {
        await _resendVerificationEmail();
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    final authProvider = Provider.of<EmailAuthProvider>(context, listen: false);
    final String userEmail = authProvider.user?.email ?? '회원님의 이메일';

    return Scaffold(
      appBar: AppBar(
        title: const Text('이메일 인증'),
        actions: [
          /// 로그아웃 버튼 (오른쪽 상단)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 100, color: Colors.teal),
              const SizedBox(height: 24),
              const Text(
                '이메일을 확인해주세요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.useFirebase
                    ? '본인 인증을 위해 $userEmail로\n전송된 링크를 클릭하세요.'
                    : '현재 로컬 모드로 실행 중입니다.\n모든 기능을 자유롭게 사용해보세요.',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              /// 인증 이메일 재전송 버튼
              ElevatedButton.icon(
                icon: _isSendingEmail
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                )
                    : const Icon(Icons.send_outlined),
                label: const Text('인증 이메일 다시 보내기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                /// 이미 전송 중이면 버튼 비활성화
                onPressed: AppConfig.useFirebase
                    ? (_isSendingEmail ? null : _showResendConfirmationDialog)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}