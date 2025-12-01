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

class ProductCreatePage extends StatefulWidget {
  const ProductCreatePage({super.key});

  @override
  State<ProductCreatePage> createState() => _ProductCreatePageState();
}

class _ProductCreatePageState extends State<ProductCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = [];
  final _groupItemController = TextEditingController();
  final _groupMaxMembersController = TextEditingController();
  final _groupCurrentMembersController = TextEditingController(text: '1');
  final _groupPricePerPersonController = TextEditingController();
  final _groupMeetTextController = TextEditingController();
  final _meetLocationDetailController = TextEditingController();

  ListingType _type = ListingType.market;
  ProductCategory _category = ProductCategory.digital;
  DateTime? _orderDeadline;
  List<AppGeoPoint> _selectedLocations = [];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _groupItemController.dispose();
    _groupMaxMembersController.dispose();
    _groupCurrentMembersController.dispose();
    _groupPricePerPersonController.dispose();
    _groupMeetTextController.dispose();
    _meetLocationDetailController.dispose();
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

  /// 이미지 선택
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocations.isEmpty) {
      _showMessage('거래 위치를 한 곳 이상 선택해주세요.');
      return;
    }

    final user = context.read<EmailAuthProvider>().user;
    if (user == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 3. 최종적으로 Firestore에 저장할 이미지 URL 목록
      final List<String> images = [];

      // Firebase 모드: 갤러리에서 선택한 이미지를 Firebase Storage에 업로드
      if (AppConfig.useFirebase && _selectedImages.isNotEmpty) {
        final storage = FirebaseStorage.instance;
        final authUser = FirebaseAuth.instance.currentUser;

        if (authUser == null) {
          _showMessage('로그인이 필요합니다.');
          setState(() => _isSubmitting = false);
          return;
        }

        for (final imageFile in _selectedImages) {
          try {
            final file = File(imageFile.path);
            final fileName =
                '${authUser.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';

            final ref = storage.ref().child('products/${authUser.uid}/$fileName');

            // 파일 업로드
            await ref.putFile(file);

            // 다운로드 URL 가져오기
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

        for (final imageFile in _selectedImages) {
          final fileName = path.basename(imageFile.path);
          final savedFile = File(path.join(imagesDir.path, fileName));
          await File(imageFile.path).copy(savedFile.path);
          images.add(savedFile.path);
        }
      }

      // 이미지가 없으면 기본 이미지 사용
      if (images.isEmpty) {
        images.add('lib/dummy_data/아이폰.jpeg');
      }

      // ===== 여기부터는 기존 로직 그대로 (groupInfo, Firestore 저장 등) =====

      GroupBuyInfo? groupInfo;
      if (_type == ListingType.groupBuy) {
        if (_groupItemController.text.trim().isEmpty ||
            _groupMaxMembersController.text.trim().isEmpty ||
            _groupPricePerPersonController.text.trim().isEmpty ||
            _groupMeetTextController.text.trim().isEmpty) {
          _showMessage('같이사요 정보를 모두 입력해주세요.');
          setState(() => _isSubmitting = false);
          return;
        }
        groupInfo = GroupBuyInfo(
          itemSummary: _groupItemController.text.trim(),
          maxMembers:
          int.tryParse(_groupMaxMembersController.text.trim()) ?? 0,
          currentMembers:
          int.tryParse(_groupCurrentMembersController.text.trim()) ?? 1,
          pricePerPerson:
          int.tryParse(_groupPricePerPersonController.text.trim()) ?? 0,
          orderDeadline:
          _orderDeadline ?? DateTime.now().add(const Duration(days: 1)),
          meetPlaceText: _groupMeetTextController.text.trim(),
        );
      }

      if (AppConfig.useFirebase) {
        final firestore = FirebaseFirestore.instance;
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser == null) {
          _showMessage('로그인이 필요합니다.');
          setState(() => _isSubmitting = false);
          return;
        }

        final primaryLocation = _selectedLocations.first;
        final actualRegion =
            LocalAppRepository.instance.getRegionByLocation(
              primaryLocation.latitude,
              primaryLocation.longitude,
            ) ??
                user.region;

        final productData = {
          'type': _type == ListingType.market ? 'market' : 'groupBuy',
          'title': _titleController.text.trim(),
          'price': int.tryParse(_priceController.text.trim()) ?? 0,
          'location': GeoPoint(
              primaryLocation.latitude, primaryLocation.longitude),
          'meetLocations': _selectedLocations
              .map((loc) =>
              GeoPoint(loc.latitude, loc.longitude))
              .toList(),
          // ★ 더미 이미지 제거: 그대로 images 사용
          'images': images,
          'category': _category.index,
          'status': 0,
          'region': {
            'code': actualRegion.code,
            'name': actualRegion.name,
            'level': actualRegion.level,
            'parent': actualRegion.parent,
          },
          'universityId': user.universityId,
          'sellerUid': authUser.uid,
          'sellerName': user.displayName,
          'sellerPhotoUrl': user.photoUrl,
          'likeCount': 0,
          'viewCount': 0,
          'description': _descriptionController.text.trim(),
          'meetLocationDetail':
          _meetLocationDetailController.text.trim().isNotEmpty
              ? _meetLocationDetailController.text.trim()
              : null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'likedUserIds': [],
          if (groupInfo != null)
            'groupBuy': {
              'itemSummary': groupInfo.itemSummary,
              'maxMembers': groupInfo.maxMembers,
              'currentMembers': groupInfo.currentMembers,
              'pricePerPerson': groupInfo.pricePerPerson,
              'orderDeadline':
              Timestamp.fromDate(groupInfo.orderDeadline),
              'meetPlaceText': groupInfo.meetPlaceText,
            },
        };

        await firestore.collection('products').add(productData);

        if (mounted) {
          _showMessage('상품이 등록되었습니다!', isError: false);
          Navigator.pop(context, true);
        }
      } else {
        // 로컬 모드
        final primaryLocation = _selectedLocations.first;
        final actualRegion =
            LocalAppRepository.instance.getRegionByLocation(
              primaryLocation.latitude,
              primaryLocation.longitude,
            ) ??
                user.region;

        await LocalAppRepository.instance.createListing(
          type: _type,
          title: _titleController.text.trim(),
          price: int.tryParse(_priceController.text.trim()) ?? 0,
          meetLocations: _selectedLocations,
          images: images, // ★ 더미 제거
          category: _category,
          region: actualRegion,
          universityId: user.universityId,
          seller: user,
          description: _descriptionController.text.trim(),
          groupBuy: groupInfo,
          meetLocationDetail:
          _meetLocationDetailController.text.trim().isNotEmpty
              ? _meetLocationDetailController.text.trim()
              : null,
        );

        if (mounted) {
          _showMessage('상품이 등록되었습니다!', isError: false);
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
        title: const Text('상품 등록'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 16),
              _buildCategorySelector(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '제목을 입력해주세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '대표 가격 (원)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '가격을 입력해주세요.' : null,
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
                          style: const TextStyle(color: Colors.teal),
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
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '상세 설명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _buildLocationSelector(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _meetLocationDetailController,
                decoration: const InputDecoration(
                  labelText: '상세 거래 위치',
                  hintText: '예: 금오공대 정문 앞 편의점, 인동동 마트 앞',
                  border: OutlineInputBorder(),
                  helperText: '지도에서 선택한 위치 외에 상세한 거래 장소를 입력해주세요',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '상세 거래 위치를 입력해주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),
              if (_type == ListingType.groupBuy) _buildGroupBuyFields(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text('상품 등록'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    // 중고거래만 표시 (같이사요는 별도 페이지에서 처리)
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Text(
        '중고거래',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ProductCategory.values.map((category) {
            final isSelected = _category == category;
            return ChoiceChip(
              label: Text(_categoryLabel(category)),
              selected: isSelected,
              onSelected: (_) => setState(() => _category = category),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSelector() {
    return Column(
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
          Text(
            '총 ${_selectedLocations.length}개 위치 선택됨',
            style: const TextStyle(
              color: Colors.teal,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildGroupBuyFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text(
          '같이사요 상세 정보',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _groupItemController,
          decoration: const InputDecoration(
            labelText: '상품/메뉴 요약',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _groupMaxMembersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '모집 인원',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _groupPricePerPersonController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '1인 금액',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _groupCurrentMembersController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '현재 참여 인원',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _groupMeetTextController,
          decoration: const InputDecoration(
            labelText: '만날 장소 설명',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('주문 마감 시간'),
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
      ],
    );
  }

  String _categoryLabel(ProductCategory category) {
    switch (category) {
      case ProductCategory.digital:
        return '전자기기';
      case ProductCategory.textbooks:
        return '전공책';
      case ProductCategory.daily:
        return '생활용품';
      case ProductCategory.housing:
        return '가구/주거';
      case ProductCategory.fashion:
        return '패션/잡화';
      case ProductCategory.hobby:
        return '취미/레저';
      case ProductCategory.etc:
        return '기타';
      case ProductCategory.groupBuy:
        return '같이사요';
    }
  }
}
