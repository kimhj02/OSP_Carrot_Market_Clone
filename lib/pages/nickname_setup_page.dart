/// 닉네임 설정 페이지

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/config/app_config.dart';

class NicknameSetupPage extends StatefulWidget {
  const NicknameSetupPage({super.key});

  @override
  State<NicknameSetupPage> createState() => _NicknameSetupPageState();
}

class _NicknameSetupPageState extends State<NicknameSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  bool _isChecking = false;
  bool _isSubmitting = false;
  bool? _isAvailable;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// 닉네임 중복 확인 (UI 피드백용)
  Future<void> _checkNickname() async {
    if (_formKey.currentState?.validate() != true) return;

    final nickname = _nicknameController.text.trim();

    setState(() {
      _isChecking = true;
      _isAvailable = null;
    });

    bool? isAvailable;
    Object? error;

    try {
      if (AppConfig.useFirebase) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('displayName', isEqualTo: nickname)
            .limit(1)
            .get();
        isAvailable = querySnapshot.docs.isEmpty;
      } else {
        isAvailable = true;
      }
    } catch (e) {
      error = e;
    }

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _isAvailable = error == null ? isAvailable : null;
    });

    if (error != null) {
      _showSnackBar('중복 확인 중 오류가 발생했습니다: ${error.toString()}', isSuccess: false);
    } else if (isAvailable == true) {
      _showSnackBar('사용 가능한 닉네임입니다!', isSuccess: true);
    } else if (isAvailable == false) {
      _showSnackBar('이미 사용 중인 닉네임입니다.', isSuccess: false);
    }
  }

  /// 닉네임 설정 완료 (트랜잭션으로 경쟁 조건 방지)
  Future<void> _submitNickname() async {
    if (_formKey.currentState?.validate() != true) return;

    if (_isAvailable != true) {
      _showSnackBar('닉네임 중복 확인을 먼저 해주세요.', isSuccess: false);
      return;
    }

    final nickname = _nicknameController.text.trim();
    final authProvider = Provider.of<EmailAuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      _showSnackBar('사용자 정보를 찾을 수 없습니다.', isSuccess: false);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final errorMessage = await authProvider.updateNickname(nickname);

      if (!mounted) return;

      if (errorMessage == null) {
        _showSnackBar('닉네임이 설정되었습니다!', isSuccess: true);
        /// AuthCheck가 자동으로 HomePage로 이동시킴
      } else {
        if (errorMessage.contains('이미 사용 중인')) {
          _showSnackBar(errorMessage, isSuccess: false);
          setState(() {
            _isAvailable = false;
          });
        } else {
          _showSnackBar('닉네임 설정 중 오류가 발생했습니다: $errorMessage', isSuccess: false);
        }
      }
    } catch (e) {
      // authProvider.updateNickname은 예외를 잡아서 오류 메시지를 반환하지만,
      // 만약을 대비해 catch 블록을 유지합니다.
      if (!mounted) return;
      _showSnackBar('예상치 못한 오류가 발생했습니다: ${e.toString()}', isSuccess: false);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 스낵바 메시지 표시
  void _showSnackBar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// 닉네임 유효성 검사
  String? _validateNickname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '닉네임을 입력해주세요';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return '닉네임은 2자 이상이어야 합니다';
    }

    if (trimmed.length > 10) {
      return '닉네임은 10자 이하여야 합니다';
    }

    // 한글, 영문, 숫자만 허용
    final regExp = RegExp(r'^[가-힣a-zA-Z0-9]+$');
    if (!regExp.hasMatch(trimmed)) {
      return '한글, 영문, 숫자만 사용 가능합니다';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '닉네임 설정',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              /// 안내 아이콘
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              /// 안내 텍스트
              const Text(
                '닉네임을 설정해주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '닉네임은 한 번 설정하면 변경할 수 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              /// 닉네임 입력 필드
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        labelText: '닉네임',
                        hintText: '2-10자 (한글, 영문, 숫자)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _isAvailable == null
                            ? null
                            : Icon(
                          _isAvailable == true
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _isAvailable == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        /// 입력 시 중복 확인 상태 초기화
                        if (_isAvailable != null) {
                          setState(() {
                            _isAvailable = null;
                          });
                        }
                      },
                      validator: _validateNickname,
                    ),
                  ),
                  const SizedBox(width: 8),

                  /// 중복 확인 버튼
                  ElevatedButton(
                    onPressed: _isChecking ? null : _checkNickname,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                        : const Text('중복\n확인'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              /// 닉네임 규칙 안내
              const Text(
                '• 2자 이상, 10자 이하\n'
                    '• 한글, 영문, 숫자만 사용 가능\n'
                    '• 특수문자, 공백 사용 불가',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),

              /// 설정 완료 버튼
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isAvailable != true)
                      ? null
                      : _submitNickname,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Text(
                    '설정 완료',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}