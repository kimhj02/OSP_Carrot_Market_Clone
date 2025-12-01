import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/providers/location_provider.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = ''; // 검색어 상태

  /// Firestore 문서를 Product로 변환
  Product _firestoreDocToProduct(String docId, Map<String, dynamic> data, String? viewerUid) {
    final location = data['location'] as GeoPoint?;
    final region = data['region'] as Map<String, dynamic>?;
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    final likedUserIds = List<String>.from(data['likedUserIds'] ?? []);
    
    return Product(
      id: docId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      imageUrls: List<String>.from(data['images'] ?? []),
      category: Product.safeParseEnum(
        ProductCategory.values,
        data['category'],
        ProductCategory.etc,
      ),
      status: Product.safeParseEnum(
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

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final viewerUid = context.watch<EmailAuthProvider>().user?.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '상품명 검색',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _query = value;
            });
          },
        ),
      ),
      body: Column(
        children: [
          // 필터링 정보 및 검색 결과 개수 표시
          Builder(
            builder: (context) {
              // Firebase 사용 시 StreamBuilder로 실시간 업데이트
              if (AppConfig.useFirebase) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    
                    if (snapshot.hasError) {
                      return const SizedBox.shrink();
                    }
                    
                    final allProducts = snapshot.data?.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _firestoreDocToProduct(doc.id, data, viewerUid);
                    }).toList() ?? [];
                    
                    final filtered = _filterProducts(allProducts, _query, locationProvider);
                    return _buildFilterInfo(locationProvider, filtered.length);
                  },
                );
              } else {
                // 로컬 모드
                final products = LocalAppRepository.instance
                    .getProducts(viewerUid: viewerUid)
                    .toList();
                final filtered = _filterProducts(products, _query, locationProvider);
                return _buildFilterInfo(locationProvider, filtered.length);
              }
            },
          ),
          // 검색 결과 리스트
          Expanded(
            child: AppConfig.useFirebase
                ? _buildFirebaseSearchResults(locationProvider, viewerUid)
                : _buildLocalSearchResults(locationProvider, viewerUid),
          ),
        ],
      ),
    );
  }

  /// Firebase 검색 결과 빌드
  Widget _buildFirebaseSearchResults(LocationProvider locationProvider, String? viewerUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('오류: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(_query, locationProvider);
        }
        
        final allProducts = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _firestoreDocToProduct(doc.id, data, viewerUid);
        }).toList();
        
        final filtered = _filterProducts(allProducts, _query, locationProvider);
        
        if (filtered.isEmpty) {
          return _buildEmptyState(_query, locationProvider);
        }
        
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            return _buildProductTile(product);
          },
        );
      },
    );
  }

  /// 로컬 검색 결과 빌드
  Widget _buildLocalSearchResults(LocationProvider locationProvider, String? viewerUid) {
    final products = LocalAppRepository.instance
        .getProducts(viewerUid: viewerUid)
        .toList();
    final filtered = _filterProducts(products, _query, locationProvider);
    
    if (filtered.isEmpty) {
      return _buildEmptyState(_query, locationProvider);
    }
    
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final product = filtered[index];
        return _buildProductTile(product);
      },
    );
  }

  /// 상품 필터링
  List<Product> _filterProducts(
    List<Product> products,
    String query,
    LocationProvider locationProvider,
  ) {
    var filtered = products;
    
    // 판매 완료 상품 제외
    filtered = filtered.where((p) => p.status != ProductStatus.sold).toList();
    
    // 검색어로 필터링
    if (query.isNotEmpty) {
      filtered = filtered
          .where((p) => 
              p.title.toLowerCase().contains(query.toLowerCase()) ||
              p.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    // 위치 필터링 적용
    if (locationProvider.isLocationFilterEnabled &&
        locationProvider.filterLatitude != null &&
        locationProvider.filterLongitude != null) {
      filtered = filtered.where((product) {
        if (product.x == 0.0 && product.y == 0.0) {
          return false;
        }
        final distance = Geolocator.distanceBetween(
          locationProvider.filterLatitude!,
          locationProvider.filterLongitude!,
          product.x,
          product.y,
        );
        return distance <= locationProvider.searchRadius;
      }).toList();
    }

    return filtered;
  }

  /// 상품 타일 빌드
  Widget _buildProductTile(Product product) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _ProductThumbnail(imageUrls: product.imageUrls),
      ),
      title: Text(product.title),
      subtitle: Text(
        '${product.formattedPrice} · ${product.location}',
      ),
      trailing: Text(
        product.statusText,
        style: TextStyle(
          color: product.status == ProductStatus.sold
              ? Colors.grey
              : Colors.green,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
    );
  }

  /// 필터링 정보를 표시하는 위젯
  Widget _buildFilterInfo(LocationProvider locationProvider, int resultCount) {
    if (!locationProvider.isLocationFilterEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.teal.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(
            locationProvider.isCurrentLocationSelected
                ? Icons.my_location
                : Icons.school,
            size: 16,
            color: Colors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '검색 결과 $resultCount개',
              style: TextStyle(
                fontSize: 13,
                color: Colors.teal[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: Text(
              locationProvider.searchRadiusText,
              style: TextStyle(
                color: Colors.teal,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 상태를 표시하는 위젯
  Widget _buildEmptyState(String query, LocationProvider locationProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              query.isEmpty
                  ? '검색어를 입력해주세요'
                  : locationProvider.isLocationFilterEnabled
                      ? '주변에 "${query}" 검색 결과가 없습니다'
                      : '"$query" 검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (locationProvider.isLocationFilterEnabled && query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '검색 반경을 늘리거나 필터를 해제해보세요',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final imageUrl = imageUrls.isNotEmpty && imageUrls.first.isNotEmpty
        ? imageUrls.first
        : null;

    if (imageUrl == null) {
      return const _FallbackThumbnail();
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const _FallbackThumbnail();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 60,
            height: 60,
            color: Colors.grey[200],
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    return Image.asset(
      imageUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const _FallbackThumbnail();
      },
    );
  }
}

class _FallbackThumbnail extends StatelessWidget {
  const _FallbackThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}
