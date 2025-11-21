/// 판매자 프로필 페이지
///
/// 판매자 정보와 판매 상품 목록을 표시하는 화면입니다.
///
/// 주요 기능:
/// - 판매자 기본 정보 표시
/// - 판매자가 등록한 상품 목록 표시
/// - 판매중/판매완료 탭 구분
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';

/// 판매자 프로필 페이지를 나타내는 위젯
class SellerProfilePage extends StatefulWidget {
  /// 판매자 ID
  final String sellerId;
  
  /// 판매자 닉네임
  final String sellerNickname;
  
  /// 판매자 프로필 이미지 URL (선택사항)
  final String? sellerProfileImageUrl;

  const SellerProfilePage({
    super.key,
    required this.sellerId,
    required this.sellerNickname,
    this.sellerProfileImageUrl,
  });

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage>
    with SingleTickerProviderStateMixin {
  /// 상품 상태 탭 컨트롤러
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Firestore Document를 Product로 변환하는 헬퍼 메서드
  Product _firestoreDocToProduct(String docId, Map<String, dynamic> data, String? viewerUid) {
    final location = data['location'] as GeoPoint?;
    final region = data['region'] as Map<String, dynamic>?;
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    final likedUserIds = List<String>.from(data['likedUserIds'] ?? []);
    
    // 안전한 Enum 파싱 헬퍼 함수
    T _safeParseEnum<T>(List<T> values, dynamic value, T defaultValue) {
      if (value is int && value >= 0 && value < values.length) {
        return values[value];
      }
      return defaultValue;
    }

    return Product(
      id: docId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      imageUrls: List<String>.from(data['images'] ?? []),
      category: _safeParseEnum(
        ProductCategory.values,
        data['category'],
        ProductCategory.etc,
      ),
      status: _safeParseEnum(
        ProductStatus.values,
        data['status'],
        ProductStatus.onSale,
      ),
      sellerId: data['sellerUid'] as String? ?? '',
      sellerNickname: data['sellerName'] as String? ?? '',
      sellerProfileImageUrl: data['sellerPhotoUrl'] as String?,
      location: region?['name'] as String? ?? '알 수 없는 지역',
      createdAt: createdAt?.toDate() ?? DateTime.now(),
      updatedAt: updatedAt?.toDate() ?? DateTime.now(),
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      isLiked: viewerUid != null && likedUserIds.contains(viewerUid),
      x: location?.latitude ?? 0.0,
      y: location?.longitude ?? 0.0,
      meetLocationDetail: data['meetLocationDetail'] as String?,
    );
  }

  /// 상품 목록을 필터링하는 메서드
  List<Product> _filterProducts(List<Product> products, int tabIndex) {
    switch (tabIndex) {
      case 0: // 판매중
        return products
            .where((p) => p.status == ProductStatus.onSale || 
                         p.status == ProductStatus.reserved)
            .toList();
      case 1: // 판매완료
        return products
            .where((p) => p.status == ProductStatus.sold)
            .toList();
      default:
        return [];
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '판매자 프로필',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // 판매자 정보 섹션
          _buildSellerSection(),

          // 상품 상태 탭
          _buildTabBar(),

          // 상품 목록
          Expanded(
            child: _buildProductList(),
          ),
        ],
      ),
    );
  }

  /// 판매자 정보 섹션을 생성하는 위젯
  Widget _buildSellerSection() {
    if (AppConfig.useFirebase) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerUid', isEqualTo: widget.sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          final products = snapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _firestoreDocToProduct(doc.id, data, null);
          }).toList() ?? [];
          
          return _buildSellerInfo(products);
        },
      );
    } else {
      final products = LocalAppRepository.instance
          .getProducts(viewerUid: null)
          .where((p) => p.sellerId == widget.sellerId)
          .toList();
      return _buildSellerInfo(products);
    }
  }

  /// 판매자 정보를 표시하는 위젯
  Widget _buildSellerInfo(List<Product> products) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 판매자 프로필 이미지
          CircleAvatar(
            radius: 40,
            backgroundImage: widget.sellerProfileImageUrl != null
                ? NetworkImage(widget.sellerProfileImageUrl!)
                : null,
            child: widget.sellerProfileImageUrl == null
                ? const Icon(Icons.person, color: Colors.grey, size: 40)
                : null,
          ),
          const SizedBox(height: 16),

          // 판매자 닉네임
          Text(
            widget.sellerNickname,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 판매 상품 통계
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('판매중', products
                  .where((p) => p.status == ProductStatus.onSale || 
                               p.status == ProductStatus.reserved)
                  .length),
              const SizedBox(width: 24),
              _buildStatItem('판매완료', products
                  .where((p) => p.status == ProductStatus.sold)
                  .length),
            ],
          ),
        ],
      ),
    );
  }

  /// 통계 아이템을 생성하는 위젯
  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// 상품 상태 탭바를 생성하는 위젯
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.teal,
        labelColor: Colors.teal,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: '판매중'),
          Tab(text: '판매완료'),
        ],
        onTap: (index) {
          setState(() {});
        },
      ),
    );
  }

  /// 상품 목록을 빌드하는 위젯
  Widget _buildProductList() {
    if (AppConfig.useFirebase) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerUid', isEqualTo: widget.sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          
          final allProducts = snapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _firestoreDocToProduct(doc.id, data, null);
          }).toList() ?? [];
          
          // 최신순으로 정렬 (클라이언트 측)
          allProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          final filtered = _filterProducts(allProducts, _tabController.index);
          
          if (filtered.isEmpty) {
            return _buildEmptyState();
          }
          
          return _buildProductGrid(filtered);
        },
      );
    } else {
      // 로컬 모드
      final products = LocalAppRepository.instance
          .getProducts(viewerUid: null)
          .where((p) => p.sellerId == widget.sellerId)
          .toList();
      
      final filtered = _filterProducts(products, _tabController.index);
      
      if (filtered.isEmpty) {
        return _buildEmptyState();
      }
      
      return _buildProductGrid(filtered);
    }
  }

  /// 상품 그리드를 생성하는 위젯
  Widget _buildProductGrid(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  /// 상품 카드를 생성하는 위젯
  Widget _buildProductCard(Product product) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: product.imageUrls.isNotEmpty
                      ? product.imageUrls.first.startsWith('lib/')
                            ? Image.asset(
                                product.imageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : Image.network(
                                product.imageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 상품 정보
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품 제목
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 가격
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 상품 상태
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: product.status == ProductStatus.onSale
                          ? Colors.teal[50]
                          : product.status == ProductStatus.reserved
                          ? Colors.orange[50]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: product.status == ProductStatus.onSale
                            ? Colors.teal
                            : product.status == ProductStatus.reserved
                            ? Colors.orange
                            : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 빈 상태를 표시하는 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(),
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

  /// 빈 상태 메시지를 반환하는 메서드
  String _getEmptyMessage() {
    switch (_tabController.index) {
      case 0:
        return '판매중인 상품이 없습니다';
      case 1:
        return '판매 완료된 상품이 없습니다';
      default:
        return '';
    }
  }
}

