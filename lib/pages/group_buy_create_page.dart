import 'package:flutter/material.dart';

/// 같이사요 모집 글을 작성하는 페이지
///
/// 실제 저장 기능은 구현되지 않았으며, 기본 입력 양식과 UX만 제공합니다.
class GroupBuyCreatePage extends StatefulWidget {
  const GroupBuyCreatePage({super.key});

  @override
  State<GroupBuyCreatePage> createState() => _GroupBuyCreatePageState();
}

class _GroupBuyCreatePageState extends State<GroupBuyCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _perPersonPriceController =
      TextEditingController();
  final TextEditingController _meetingPlaceController =
      TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _perPersonPriceController.dispose();
    _meetingPlaceController.dispose();
    _deadlineController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '같이사요 모집하기',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoBanner(),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _titleController,
                  label: '모집 제목',
                  hintText: '예) 역삼동 네 명이서 치킨 시켜요',
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '제목을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _itemController,
                  label: '상품 / 메뉴',
                  hintText: '예) 교촌 허니콤보, 3개 묶음 / 1.5L 콜라 4개',
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '상품이나 메뉴를 입력해주세요.'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _quantityController,
                        label: '모집 인원',
                        hintText: '예) 4명',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _perPersonPriceController,
                        label: '1인 예상 금액',
                        hintText: '예) 7,500원',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _meetingPlaceController,
                  label: '만날 장소',
                  hintText: '예) 역삼역 3번 출구, 금오대학교 5호관 로비',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _deadlineController,
                  label: '주문 마감 시간',
                  hintText: '예) 오늘 밤 11시까지, 3월 15일 오후 2시',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _memoController,
                  label: '전달 사항',
                  hintText:
                      '주문 방법, 결제 방식, 알레르기 정보 등 참여자에게 알려줄 내용을 적어주세요.',
                  maxLines: 6,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isSubmitting ? '등록 중...' : '모집글 올리기',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '같이사요 안내',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '대학생 이웃들과 대용량 상품을 나누거나 배달 음식을 함께 주문해보세요.\n'
            '모집글이 등록되면 채팅으로 참여자를 모을 수 있어요. 안전한 거래를 위해 결제 방식과 만남 장소를 명확하게 안내해주세요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSubmitting = true);

    await Future<void>.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('같이사요 모집글이 등록되었습니다 (샘플 동작)'),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, true);
  }
}


