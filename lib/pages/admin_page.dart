/// 관리자 페이지
///
/// 광고 및 신고된 상품을 관리하는 관리자 전용 페이지입니다.
/// 광고 목록 표시, 추가, 수정, 삭제 기능과 신고된 상품 목록 및 처리 기능을 제공합니다.
///
/// @author Flutter Sandbox
/// @version 2.0.0
/// @since 2024-01-01

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/models/ad.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/providers/ad_provider.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';


/// 관리자 페이지 위젯
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ReportedProduct> _reportedProducts = [];
  bool _loadingReports = false;
  String? _errorMessage;

  /// 광고 이미지 업로드 공용 헬퍼
  Future<void> _pickAndUploadAdImageForDialog({
    required BuildContext context,
    required StateSetter setState,
    required TextEditingController imageUrlController,
    required void Function(bool) setUploadingImage,
  }) async {
    try {
      // 업로드 시작
      setUploadingImage(true);
      setState(() {});

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('웹에서는 현재 갤러리 업로드를 지원하지 않습니다.')),
          );
        }
        return;
      }

      final file = File(picked.path);
      final url = await _uploadAdImage(file);

      if (!context.mounted) {
            return;
      }
      // 성공 시 URL 반영
      imageUrlController.text = url;
      setState(() {});
    } catch (e) {
      debugPrint('광고 이미지 업로드 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 업로드에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 성공/실패 상관없이 항상 false 로 복원
      if (context.mounted) {
        setUploadingImage(false);
        setState(() {});
      }
    }
  }



  /// 광고 이미지 Firebase Storage 업로드
  Future<String> _uploadAdImage(File file) async {
    if (!AppConfig.useFirebase) {
      throw StateError('Firebase 모드에서만 이미지 업로드를 지원합니다.');
    }

    // "ads/타임스탬프_파일명.png" 경로로 저장
    final fileName =
        'ads/${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';

    final ref = FirebaseStorage.instance.ref().child(fileName);

    final uploadTask = await ref.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          // Tab index가 변경될 때 UI를 다시 빌드하여 AppBar actions 업데이트
        });
      }
      if (_tabController.index == 1 && _reportedProducts.isEmpty && !_loadingReports) {
        _loadReportedProducts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '관리자 페이지',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: '광고 관리'),
            Tab(icon: Icon(Icons.flag), text: '신고된 상품'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              onPressed: () => _showAddAdDialog(context),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAdManagementTab(),
          _buildReportedProductsTab(),
        ],
      ),
    );
  }


  /// 광고 관리 탭
  Widget _buildAdManagementTab() {
    return Consumer<AdProvider>(
      builder: (context, adProvider, child) {
        if (adProvider.loading && adProvider.ads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (adProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  adProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (adProvider.ads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '등록된 광고가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '오른쪽 상단의 + 버튼을 눌러 광고를 추가하세요',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: adProvider.ads.length,
          itemBuilder: (context, index) {
            final ad = adProvider.ads[index];
            return _buildAdCard(context, ad, adProvider);
          },
        );
      },
    );
  }

  /// 신고된 상품 탭
  Widget _buildReportedProductsTab() {
    if (_loadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReportedProducts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_reportedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '신고된 상품이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReportedProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportedProducts.length,
        itemBuilder: (context, index) {
          final reportedProduct = _reportedProducts[index];
          return _buildReportedProductCard(context, reportedProduct);
        },
      ),
    );
  }

  /// 광고 카드를 생성하는 위젯
  Widget _buildAdCard(BuildContext context, Ad ad, AdProvider adProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 광고 제목과 상태
            Row(
              children: [
                Expanded(
                  child: Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ad.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ad.isActive ? '활성' : '비활성',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 광고 설명
            Text(
              ad.description,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 광고 이미지
            if (ad.imageUrl.isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ad.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // 광고 정보
            Row(
              children: [
                Icon(Icons.link, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ad.linkUrl,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 활성화/비활성화 토글
                TextButton.icon(
                  onPressed: () async {
                    final success = await adProvider.toggleAdActive(
                      ad.id,
                      !ad.isActive,
                    );
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ad.isActive ? '광고가 비활성화되었습니다' : '광고가 활성화되었습니다',
                          ),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    ad.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(ad.isActive ? '비활성화' : '활성화'),
                ),
                const SizedBox(width: 8),
                // 수정 버튼
                TextButton.icon(
                  onPressed: () => _showEditAdDialog(context, ad),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('수정'),
                ),
                const SizedBox(width: 8),
                // 삭제 버튼
                TextButton.icon(
                  onPressed: () =>
                      _showDeleteConfirmDialog(context, ad, adProvider),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 광고 추가 다이얼로그 표시
  void _showAddAdDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final imageUrlController = TextEditingController(); // 내부에서만 사용
    final linkUrlController = TextEditingController();
    bool isActive = true;

    bool uploadingImage = false;


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('광고 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // 이미지 영역
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이미지',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (imageUrlController.text.isNotEmpty)
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrlController.text,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: uploadingImage
                              ? null
                              : () => _pickAndUploadAdImageForDialog(
                            context: context,
                            setState: setState,
                            imageUrlController: imageUrlController,
                            setUploadingImage: (isUploading) => uploadingImage = isUploading,
                          ),

                          icon: uploadingImage
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.photo),
                          label: Text(uploadingImage ? '업로드 중...' : '사진 선택'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (imageUrlController.text.isNotEmpty)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: uploadingImage
                                ? null
                                : () {
                              setState(() {
                                imageUrlController.clear();
                              });
                            },
                            child: const Text('이미지 제거'),
                          ),
                        ),
                      ),
                  ],
                ),


                const SizedBox(height: 12),
                TextField(
                  controller: linkUrlController,
                  decoration: const InputDecoration(
                    labelText: '링크 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('활성화'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final adProvider = Provider.of<AdProvider>(
                  context,
                  listen: false,
                );
                final ad = Ad(
                  id: '',
                  title: titleController.text,
                  description: descriptionController.text,
                  imageUrl: imageUrlController.text, // 업로드된 URL
                  linkUrl: linkUrlController.text,
                  isActive: isActive,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final adId = await adProvider.addAd(ad);
                if (adId != null && context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('광고가 추가되었습니다')));
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(adProvider.errorMessage ?? '광고 추가에 실패했습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }



  /// 광고 수정 다이얼로그 표시
  void _showEditAdDialog(BuildContext context, Ad ad) {
    final titleController = TextEditingController(text: ad.title);
    final descriptionController = TextEditingController(text: ad.description);
    final imageUrlController = TextEditingController(text: ad.imageUrl); // 내부용
    final linkUrlController = TextEditingController(text: ad.linkUrl);
    bool isActive = ad.isActive;

    bool uploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('광고 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                //  이미지 영역
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이미지',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (imageUrlController.text.isNotEmpty)
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrlController.text,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: uploadingImage
                              ? null
                              : () => _pickAndUploadAdImageForDialog(
                            context: context,
                            setState: setState,
                            imageUrlController: imageUrlController,
                            setUploadingImage: (isUploading) => uploadingImage = isUploading,
                          ),

                          icon: uploadingImage
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.photo),
                          label: Text(uploadingImage ? '업로드 중...' : '사진 선택'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (imageUrlController.text.isNotEmpty)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: uploadingImage
                                ? null
                                : () {
                              setState(() {
                                imageUrlController.clear();
                              });
                            },
                            child: const Text('이미지 제거'),
                          ),
                        ),
                      ),
                  ],
                ),


                const SizedBox(height: 12),
                TextField(
                  controller: linkUrlController,
                  decoration: const InputDecoration(
                    labelText: '링크 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('활성화'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final adProvider = Provider.of<AdProvider>(
                  context,
                  listen: false,
                );
                final updatedAd = ad.copyWith(
                  title: titleController.text,
                  description: descriptionController.text,
                  imageUrl: imageUrlController.text, // 최종 URL
                  linkUrl: linkUrlController.text,
                  isActive: isActive,
                  updatedAt: DateTime.now(),
                );

                final success = await adProvider.updateAd(updatedAd);
                if (success && context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('광고가 수정되었습니다')));
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(adProvider.errorMessage ?? '광고 수정에 실패했습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('수정'),
            ),
          ],
        ),
      ),
    );
  }



  /// 광고 삭제 확인 다이얼로그 표시
  void _showDeleteConfirmDialog(
    BuildContext context,
    Ad ad,
    AdProvider adProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('광고 삭제'),
        content: Text('"${ad.title}" 광고를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final success = await adProvider.deleteAd(ad.id);
              if (success && context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('광고가 삭제되었습니다')));
              } else if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(adProvider.errorMessage ?? '광고 삭제에 실패했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 신고된 상품 목록 로드
  Future<void> _loadReportedProducts() async {
    setState(() {
      _loadingReports = true;
      _errorMessage = null;
    });

    try {
      List<ReportedProduct> products = [];

      if (AppConfig.useFirebase) {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('reported', isGreaterThan: 0)
            .orderBy('reported', descending: true)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final reportedBy = List<String>.from(data['reportedBy'] ?? []);
          products.add(ReportedProduct(
            productId: doc.id,
            title: data['title'] ?? '',
            reportedCount: data['reported'] ?? 0,
            reportedBy: reportedBy,
            sellerId: data['sellerId'] ?? '',
            sellerName: data['sellerName'] ?? '',
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        }
      } else {
        // 로컬 모드
        final listings = LocalAppRepository.instance.getAllListings();
        for (var listing in listings) {
          final reportedCount = LocalAppRepository.instance.getReportedCount(listing.id);
          if (reportedCount > 0) {
            // 로컬 모드에서는 reportedBy 정보를 직접 저장하지 않으므로 빈 리스트
            products.add(ReportedProduct(
              productId: listing.id,
              title: listing.title,
              reportedCount: reportedCount,
              reportedBy: [],
              sellerId: listing.sellerUid,
              sellerName: listing.sellerName,
              createdAt: listing.createdAt,
            ));
          }
        }
        // 신고 횟수 순으로 정렬
        products.sort((a, b) => b.reportedCount.compareTo(a.reportedCount));
      }

      if (mounted) {
        setState(() {
          _reportedProducts = products;
          _loadingReports = false;
        });
      }
    } catch (e) {
      debugPrint('신고된 상품 목록 로드 오류: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '신고된 상품 목록을 불러오는 중 오류가 발생했습니다';
          _loadingReports = false;
        });
      }
    }
  }

  /// 신고된 상품 카드 위젯
  Widget _buildReportedProductCard(BuildContext context, ReportedProduct reportedProduct) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reportedProduct.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '신고 ${reportedProduct.reportedCount}회',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '판매자: ${reportedProduct.sellerName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (reportedProduct.reportedBy.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '신고한 사용자: ${reportedProduct.reportedBy.length}명',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          _viewProduct(context, reportedProduct.productId),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text(
                        '상품 보기',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          _clearReports(context, reportedProduct),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text(
                        '신고 해제',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () =>
                          _deleteProduct(context, reportedProduct),
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text(
                        '상품 삭제',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  /// 상품 상세 페이지로 이동
  void _viewProduct(BuildContext context, String productId) async {
    if (AppConfig.useFirebase) {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      
      if (doc.exists && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              product: Product.fromFirestore(doc),
            ),
          ),
        );
      }
    } else {
      // 로컬 모드
      final product = LocalAppRepository.instance.getProductById(productId);
      if (product != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
      }
    }
  }

  /// 신고 해제
  Future<void> _clearReports(BuildContext context, ReportedProduct reportedProduct) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신고 해제'),
        content: Text('"${reportedProduct.title}"의 신고를 모두 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (AppConfig.useFirebase) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(reportedProduct.productId)
            .update({
          'reported': 0,
          'reportedBy': FieldValue.delete(),
        });
      } else {
        // 로컬 모드
        LocalAppRepository.instance.clearReports(reportedProduct.productId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 해제되었습니다')),
        );
        _loadReportedProducts();
      }
    } catch (e) {
      debugPrint('신고 해제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신고 해제에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 상품 삭제
  Future<void> _deleteProduct(BuildContext context, ReportedProduct reportedProduct) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상품 삭제'),
        content: Text('"${reportedProduct.title}" 상품을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (AppConfig.useFirebase) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(reportedProduct.productId)
            .delete();
      } else {
        await LocalAppRepository.instance.deleteListing(reportedProduct.productId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상품이 삭제되었습니다')),
        );
        _loadReportedProducts();
      }
    } catch (e) {
      debugPrint('상품 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품 삭제에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 신고된 상품 모델
class ReportedProduct {
  final String productId;
  final String title;
  final int reportedCount;
  final List<String> reportedBy;
  final String sellerId;
  final String sellerName;
  final DateTime createdAt;

  ReportedProduct({
    required this.productId,
    required this.title,
    required this.reportedCount,
    required this.reportedBy,
    required this.sellerId,
    required this.sellerName,
    required this.createdAt,
  });
}
