/// 이메일 인증 화면
///
/// Firebase 이메일/비밀번호 인증을 위한 로그인 및 회원가입 화면입니다.
/// 당근 마켓 스타일의 UI를 제공합니다.
///
/// 주요 기능:
/// - 이메일/비밀번호 로그인
/// - 이메일/비밀번호 회원가입
/// - 로그인/회원가입 모드 전환
/// - 에러 메시지 표시
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/data/school_domains.dart';
/// 이메일 인증 화면 위젯
///
/// 로그인과 회원가입을 모두 처리하는 화면입니다.
class EmailAuthPage extends StatefulWidget {
  const EmailAuthPage({super.key});

  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignIn = true; // true: 로그인, false: 회원가입
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 스낵바 메시지 표시
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// 폼 제출 처리
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final emailAuthProvider = Provider.of<EmailAuthProvider>(context, listen: false);
    String? errorMessage;

    ///로그인
    if (_isSignIn) {
      errorMessage = await emailAuthProvider.login(
        _emailController.text,
        _passwordController.text,
      );
      if (errorMessage == null) {
        _showSnackBar('로그인 성공!');
      } else {
        _showSnackBar(errorMessage);
      }
    }

    ///회원가입
    else {
      errorMessage = await emailAuthProvider.signUp(
        _emailController.text,
        _passwordController.text,
      );
      if (errorMessage == null) {
        _showSnackBar('회원가입 성공! 이메일을 확인해주세요.');

      } else {
        _showSnackBar(errorMessage);
      }
    }
  }

  /// 입력 필드 디자인
  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isSignIn ? '이메일 로그인' : '회원가입',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<EmailAuthProvider>(
        builder: (context, authProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// 로고 영역
                  const SizedBox(height: 32),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.email_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  /// 이메일 입력 필드
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration('이메일'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해주세요';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 형식을 입력해주세요';
                      }

                      /// 회원가입 모드일 때
                      if (!_isSignIn) {
                        final lowercasedValue = value.trim().toLowerCase();
                        if (!schoolDomains.any(
                              (domain) => lowercasedValue.endsWith(domain),
                        )) {
                          return '허용된 학교 이메일이 아닙니다.';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  /// 비밀번호 입력 필드
                  TextFormField(
                    controller: _passwordController,
                    decoration: _inputDecoration(
                      '비밀번호',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요';
                      }
                      if (value.length < 6) {
                        return '비밀번호는 6자 이상이어야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  /// 로그인/회원가입 버튼
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authProvider.loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: authProvider.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isSignIn ? '로그인' : '회원가입',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  /// 로그인/회원가입 전환 버튼
                  TextButton(
                    onPressed: authProvider.loading
                        ? null
                        : () {
                            setState(() {
                              _isSignIn = !_isSignIn;
                              _emailController.clear();
                              _passwordController.clear();
                            });
                          },
                    child: Text(
                      _isSignIn
                          ? '계정이 없으신가요? 회원가입'
                          : '이미 계정이 있으신가요? 로그인',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

