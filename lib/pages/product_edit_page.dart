/// 상품 수정 페이지
///
/// 기존 상품 정보를 수정하는 화면입니다.
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

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

class ProductEditPage extends StatefulWidget {
  final Product product;

  const ProductEditPage({
    super.key,
    required this.product,
  });

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlsController;
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = [];
  late final TextEditingController _groupItemController;
  late final TextEditingController _groupMaxMembersController;
  late final TextEditingController _groupCurrentMembersController;
  late final TextEditingController _groupPricePerPersonController;
  late final TextEditingController _groupMeetTextController;

  late ProductCategory _category;
  DateTime? _orderDeadline;
  List<AppGeoPoint> _selectedLocations = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _descriptionController = TextEditingController(text: widget.product.description);
    _imageUrlsController = TextEditingController(text: widget.product.imageUrls.join(', '));
    _category = widget.product.category;
    
    // 위치 정보 초기화
    if (widget.product.x != 0.0 && widget.product.y != 0.0) {
      _selectedLocations = [
        AppGeoPoint(latitude: widget.product.x, longitude: widget.product.y),
      ];
    }
    
    // 공동구매 정보 초기화 (있는 경우)
    final listing = LocalAppRepository.instance.getListing(widget.product.id);
    if (listing?.groupBuy != null) {
      final groupBuy = listing!.groupBuy!;
      _groupItemController = TextEditingController(text: groupBuy.itemSummary);
      _groupMaxMembersController = TextEditingController(text: groupBuy.maxMembers.toString());
      _groupCurrentMembersController = TextEditingController(text: groupBuy.currentMembers.toString());
      _groupPricePerPersonController = TextEditingController(text: groupBuy.pricePerPerson.toString());
      _groupMeetTextController = TextEditingController(text: groupBuy.meetPlaceText);
      _orderDeadline = groupBuy.orderDeadline;
    } else {
      _groupItemController = TextEditingController();
      _groupMaxMembersController = TextEditingController();
      _groupCurrentMembersController = TextEditingController(text: '1');
      _groupPricePerPersonController = TextEditingController();
      _groupMeetTextController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlsController.dispose();
    _groupItemController.dispose();
    _groupMaxMembersController.dispose();
    _groupCurrentMembersController.dispose();
    _groupPricePerPersonController.dispose();
    _groupMeetTextController.dispose();
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
      initialDate: _orderDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _orderDeadline != null
          ? TimeOfDay.fromDateTime(_orderDeadline!)
          : TimeOfDay.now(),
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
      
      // 기존 이미지가 있고 새로 선택한 이미지가 없으면 기존 이미지 유지
      if (images.isEmpty) {
        images = widget.product.imageUrls;
      }

      GroupBuyInfo? groupInfo;
      final listing = LocalAppRepository.instance.getListing(widget.product.id);
      if (listing?.type == ListingType.groupBuy) {
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
          maxMembers: int.tryParse(_groupMaxMembersController.text.trim()) ?? 0,
          currentMembers:
              int.tryParse(_groupCurrentMembersController.text.trim()) ?? 1,
          pricePerPerson:
              int.tryParse(_groupPricePerPersonController.text.trim()) ?? 0,
          orderDeadline: _orderDeadline ?? DateTime.now().add(const Duration(days: 1)),
          meetPlaceText: _groupMeetTextController.text.trim(),
        );
      }

      // Firebase 사용 시 Firestore 업데이트
      if (AppConfig.useFirebase) {
        final firestore = FirebaseFirestore.instance;
        final primaryLocation = _selectedLocations.first;
        
        final updateData = <String, dynamic>{
          'title': _titleController.text.trim(),
          'price': int.tryParse(_priceController.text.trim()) ?? 0,
          'location': GeoPoint(primaryLocation.latitude, primaryLocation.longitude),
          'meetLocations': _selectedLocations.map((loc) => 
            GeoPoint(loc.latitude, loc.longitude)).toList(),
          'images': images.isEmpty ? widget.product.imageUrls : images,
          'category': _category.index,
          'description': _descriptionController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (groupInfo != null) {
          updateData['groupBuy'] = {
            'itemSummary': groupInfo.itemSummary,
            'maxMembers': groupInfo.maxMembers,
            'currentMembers': groupInfo.currentMembers,
            'pricePerPerson': groupInfo.pricePerPerson,
            'orderDeadline': Timestamp.fromDate(groupInfo.orderDeadline),
            'meetPlaceText': groupInfo.meetPlaceText,
          };
        }

        await firestore.collection('products')
            .doc(widget.product.id)
            .update(updateData);

        if (mounted) {
          _showMessage('상품이 수정되었습니다!', isError: false);
          Navigator.pop(context, true);
        }
      } else {
        // 로컬 모드
        await LocalAppRepository.instance.updateListing(
          listingId: widget.product.id,
          title: _titleController.text.trim(),
          price: int.tryParse(_priceController.text.trim()) ?? 0,
          meetLocations: _selectedLocations,
          images: images.isEmpty ? widget.product.imageUrls : images,
          category: _category,
          description: _descriptionController.text.trim(),
          groupBuy: groupInfo,
        );

        if (mounted) {
          _showMessage('상품이 수정되었습니다!', isError: false);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showMessage('수정에 실패했습니다: $e');
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
    final listing = LocalAppRepository.instance.getListing(widget.product.id);
    final isGroupBuy = listing?.type == ListingType.groupBuy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 수정'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (isGroupBuy) _buildGroupBuyFields(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text('상품 수정'),
                ),
              ),
            ],
          ),
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

