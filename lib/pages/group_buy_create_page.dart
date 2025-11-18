import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;

import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/location_picker_page.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/config/app_config.dart';

/// 같이사요 모집 글을 작성하는 페이지
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
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _imageUrlsController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = [];
  List<AppGeoPoint> _selectedLocations = [];
  DateTime? _orderDeadline;
  ProductCategory _category = ProductCategory.groupBuy;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _perPersonPriceController.dispose();
    _meetingPlaceController.dispose();
    _memoController.dispose();
    _imageUrlsController.dispose();
    super.dispose();
  }

  Future<void> _selectLocations() async {
    final initialLatLngs = _selectedLocations
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    final picked = await Navigator.push<List<LatLng>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocations: initialLatLngs,
        ),
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        _selectedLocations = picked
            .map(
              (latLng) => AppGeoPoint(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
              ),
            )
            .toList();
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );
      
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      _showMessage('이미지 선택 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _orderDeadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.teal,
      ),
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
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? '모집 인원을 입력해주세요.'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _perPersonPriceController,
                        label: '1인 예상 금액',
                        hintText: '예) 7500',
                        keyboardType: TextInputType.number,
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? '1인 금액을 입력해주세요.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 이미지 선택 섹션
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이미지',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('사진 선택'),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedImages.isNotEmpty)
                          Text(
                            '${_selectedImages.length}장 선택됨',
                            style: const TextStyle(color: Colors.orange),
                          ),
                      ],
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.file(
                                    File(_selectedImages[index].path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    color: Colors.red,
                                    onPressed: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _imageUrlsController,
                      decoration: const InputDecoration(
                        labelText: '이미지 URL (선택사항, 쉼표로 구분)',
                        border: OutlineInputBorder(),
                        helperText: '또는 이미지 URL을 직접 입력할 수 있습니다',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 위치 선택
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '거래 위치',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _selectLocations,
                          icon: const Icon(Icons.map),
                          label: const Text('지도에서 선택'),
                        ),
                      ],
                    ),
                    if (_selectedLocations.isEmpty)
                      const Text(
                        '아직 선택된 위치가 없습니다.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedLocations.asMap().entries.map((entry) {
                          return Chip(
                            label: Text(
                              '${entry.key + 1}. ${entry.value.latitude.toStringAsFixed(4)}, ${entry.value.longitude.toStringAsFixed(4)}',
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _meetingPlaceController,
                  label: '만날 장소 설명',
                  hintText: '예) 역삼역 3번 출구, 금오대학교 5호관 로비',
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '만날 장소를 입력해주세요.'
                      : null,
                ),
                const SizedBox(height: 16),
                // 주문 마감 시간 선택
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '주문 마감 시간',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _orderDeadline == null
                        ? '선택되지 않음'
                        : DateFormat('yyyy-MM-dd HH:mm').format(_orderDeadline!),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDeadline,
                  ),
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
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocations.isEmpty) {
      _showMessage('거래 위치를 한 곳 이상 선택해주세요.');
      return;
    }
    if (_orderDeadline == null) {
      _showMessage('주문 마감 시간을 선택해주세요.');
      return;
    }

    final user = context.read<EmailAuthProvider>().user;
    if (user == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String> images = [];
      
      // Firebase 사용 시 이미지를 Firebase Storage에 업로드
      if (AppConfig.useFirebase && _selectedImages.isNotEmpty) {
        final storage = FirebaseStorage.instance;
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser == null) {
          _showMessage('로그인이 필요합니다.');
          setState(() => _isSubmitting = false);
          return;
        }
        
        for (var imageFile in _selectedImages) {
          try {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
            final ref = storage.ref().child('products/${authUser.uid}/$fileName');
            await ref.putFile(File(imageFile.path));
            final downloadUrl = await ref.getDownloadURL();
            images.add(downloadUrl);
          } catch (e) {
            _showMessage('이미지 업로드 실패: $e');
            setState(() => _isSubmitting = false);
            return;
          }
        }
      } else if (!AppConfig.useFirebase && _selectedImages.isNotEmpty) {
        // 로컬 모드: 앱 내부 디렉토리에 복사
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(path.join(appDir.path, 'product_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        
        for (var imageFile in _selectedImages) {
          final fileName = path.basename(imageFile.path);
          final savedFile = File(path.join(imagesDir.path, fileName));
          await File(imageFile.path).copy(savedFile.path);
          images.add(savedFile.path);
        }
      }
      
      // URL로 입력한 이미지도 추가
      final urlImages = _imageUrlsController.text
          .split(',')
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList();
      images.addAll(urlImages);

      final groupInfo = GroupBuyInfo(
        itemSummary: _itemController.text.trim(),
        maxMembers: int.tryParse(_quantityController.text.trim()) ?? 0,
        currentMembers: 1,
        pricePerPerson: int.tryParse(_perPersonPriceController.text.trim()) ?? 0,
        orderDeadline: _orderDeadline!,
        meetPlaceText: _meetingPlaceController.text.trim(),
      );

      // Firebase 사용 시 Firestore에 저장
      if (AppConfig.useFirebase) {
        final firestore = FirebaseFirestore.instance;
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser == null) {
          _showMessage('로그인이 필요합니다.');
          setState(() => _isSubmitting = false);
          return;
        }

        // 선택한 첫 번째 위치에 따라 실제 지역을 결정
        final primaryLocation = _selectedLocations.first;
        final actualRegion = LocalAppRepository.instance.getRegionByLocation(
          primaryLocation.latitude,
          primaryLocation.longitude,
        ) ?? user.region;

        // 같이사요는 가격을 1인 금액 * 모집 인원으로 계산
        final totalPrice = groupInfo.pricePerPerson * groupInfo.maxMembers;

        final productData = {
          'type': 'groupBuy',
          'title': _titleController.text.trim(),
          'price': totalPrice,
          'location': GeoPoint(primaryLocation.latitude, primaryLocation.longitude),
          'meetLocations': _selectedLocations.map((loc) => 
            GeoPoint(loc.latitude, loc.longitude)).toList(),
          'images': images.isEmpty ? ['lib/dummy_data/아이폰.jpeg'] : images,
          'category': _category.index,
          'status': 0, // ListingStatus.onSale
          'region': {
            'code': actualRegion.code,
            'name': actualRegion.name,
            'level': actualRegion.level,
            'parent': actualRegion.parent,
          },
          'universityId': user.universityId,
          'sellerUid': user.uid,
          'sellerName': user.displayName,
          'sellerPhotoUrl': user.photoUrl,
          'likeCount': 0,
          'viewCount': 0,
          'description': _memoController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'likedUserIds': [],
          'groupBuy': {
            'itemSummary': groupInfo.itemSummary,
            'maxMembers': groupInfo.maxMembers,
            'currentMembers': groupInfo.currentMembers,
            'pricePerPerson': groupInfo.pricePerPerson,
            'orderDeadline': Timestamp.fromDate(groupInfo.orderDeadline),
            'meetPlaceText': groupInfo.meetPlaceText,
          },
        };

        await firestore.collection('products').add(productData);

        if (mounted) {
          _showMessage('같이사요 모집글이 등록되었습니다!', isError: false);
          Navigator.pop(context, true);
        }
      } else {
        // 로컬 모드
        final primaryLocation = _selectedLocations.first;
        final actualRegion = LocalAppRepository.instance.getRegionByLocation(
          primaryLocation.latitude,
          primaryLocation.longitude,
        ) ?? user.region;

        final totalPrice = groupInfo.pricePerPerson * groupInfo.maxMembers;

        await LocalAppRepository.instance.createListing(
          type: ListingType.groupBuy,
          title: _titleController.text.trim(),
          price: totalPrice,
          meetLocations: _selectedLocations,
          images: images.isEmpty ? ['lib/dummy_data/아이폰.jpeg'] : images,
          category: _category,
          region: actualRegion,
          universityId: user.universityId,
          seller: user,
          description: _memoController.text.trim(),
          groupBuy: groupInfo,
        );

        if (mounted) {
          _showMessage('같이사요 모집글이 등록되었습니다!', isError: false);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showMessage('등록에 실패했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}


