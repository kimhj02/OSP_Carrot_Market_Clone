import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/models/ad.dart';
import 'package:flutter_sandbox/providers/ad_provider.dart';
import 'package:flutter_sandbox/providers/location_provider.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/widgets/ad_card.dart';

class ProductListPage extends StatefulWidget {
  final ProductCategory? initialCategory;

  const ProductListPage({super.key, this.initialCategory});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  ProductCategory? _selectedCategory;
  String _searchQuery = '';
  SortType _sortType = SortType.latest;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  /// Firestore에서 가져온 상품 리스트에 필터/정렬 적용
  List<Product> _getFilteredProducts(
      List<Product> baseProducts,
      LocationProvider? locationProvider,
      ) {
    List<Product> filtered = List<Product>.from(baseProducts);

    // 위치 필터
    if (locationProvider != null &&
        locationProvider.isLocationFilterEnabled &&
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

    // 카테고리 필터
    if (_selectedCategory != null) {
      filtered = filtered
          .where((product) => product.category == _selectedCategory)
          .toList();
    }

    // 검색어 필터
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (product) =>
        product.title
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()) ||
            product.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()),
      )
          .toList();
    }

    // 정렬
    if (locationProvider != null &&
        locationProvider.isLocationFilterEnabled &&
        locationProvider.filterLatitude != null &&
        locationProvider.filterLongitude != null &&
        _sortType == SortType.distance) {
      filtered.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          locationProvider.filterLatitude!,
          locationProvider.filterLongitude!,
          a.x,
          a.y,
        );
        final distanceB = Geolocator.distanceBetween(
          locationProvider.filterLatitude!,
          locationProvider.filterLongitude!,
          b.x,
          b.y,
        );
        return distanceA.compareTo(distanceB);
      });
    } else {
      switch (_sortType) {
        case SortType.latest:
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case SortType.priceLow:
          filtered.sort((a, b) => a.price.compareTo(b.price));
          break;
        case SortType.priceHigh:
          filtered.sort((a, b) => b.price.compareTo(a.price));
          break;
        case SortType.popular:
          filtered.sort((a, b) => b.likeCount.compareTo(a.likeCount));
          break;
        case SortType.distance:
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // Firestore products 컬렉션 실시간 조회
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('상품을 불러오는 중 오류가 발생했습니다.')),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Document → Product
        final products = docs.map((doc) {
          final product = Product.fromFirestore(doc);
          if (kDebugMode) {
            debugPrint(
                '상품 로드: id=${product.id}, title=${product.title}, images=${product.imageUrls}');
          }
          return product;
        }).toList();

        return Consumer<LocationProvider>(
          builder: (context, locationProvider, child) {
            final filteredProducts =
            _getFilteredProducts(products, locationProvider);

            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                title: const Text(
                  '상품 목록',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.black),
                    onPressed: _showSearchDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.sort, color: Colors.black),
                    onPressed: () => _showSortDialog(locationProvider),
                  ),
                ],
              ),
              body: Column(
                children: [
                  _buildLocationFilterInfo(locationProvider),
                  _buildCategoryFilter(),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? _buildEmptyState(locationProvider)
                        : _buildProductList(filteredProducts),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip('전체', null),
          const SizedBox(width: 8),
          ...ProductCategory.values.map(
                (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCategoryChip(_getCategoryText(category), category),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, ProductCategory? category) {
    final isSelected = _selectedCategory == category;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  List<dynamic> _getMergedList(List<Product> products, List<Ad> ads) {
    if (products.length < 5) {
      return List<dynamic>.from(products);
    }

    final mergedList = <dynamic>[];
    final activeAds = ads.where((ad) => ad.isActive).toList();
    var adIndex = 0;

    for (var i = 0; i < products.length; i++) {
      mergedList.add(products[i]);

      final shouldInsertAd = (i + 1) % 5 == 0 && adIndex < activeAds.length;

      if (shouldInsertAd) {
        mergedList.add(activeAds[adIndex]);
        adIndex++;
      }
    }

    return mergedList;
  }

  Widget _buildLocationFilterInfo(LocationProvider locationProvider) {
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
              '주변 상품',
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

  Widget _buildProductList(List<Product> filteredProducts) {
    return Consumer<AdProvider>(
      builder: (context, adProvider, child) {
        final mergedList = _getMergedList(
          filteredProducts,
          adProvider.activeAds,
        );

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mergedList.length,
          itemBuilder: (context, index) {
            final item = mergedList[index];

            if (item is Product) {
              return _buildProductItem(item);
            } else if (item is Ad) {
              return AdCard(ad: item);
            } else {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildProductItem(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToProductDetail(product),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              // 이미지
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.imageUrls.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Builder(
                    builder: (context) {
                      final imagePath = product.imageUrls.first;

                      if (kDebugMode) {
                        debugPrint(
                            '썸네일 로드: $imagePath (product: ${product.id})');
                      }

                      // 1) asset (더미 이미지 포함)
                      if (_isAssetImage(imagePath)) {
                        final normalized = _normalizeAssetPath(imagePath);
                        return Image.asset(
                          normalized,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return _buildImageErrorPlaceholder();
                          },
                        );
                      }

                      // 2) 네트워크(Firebase Storage URL 등)
                      if (_isNetworkImage(imagePath)) {
                        return Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return _buildImageErrorPlaceholder();
                          },
                        );
                      }

                      // 3) 로컬 파일 (예전 데이터 대비)
                      return Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                        errorBuilder:
                            (context, error, stackTrace) {
                          return _buildImageErrorPlaceholder();
                        },
                      );
                    },
                  ),
                )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          product.location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.viewCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.likeCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildEmptyState(LocationProvider locationProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedCategory == null
                  ? (locationProvider.isLocationFilterEnabled
                  ? Icons.location_off
                  : Icons.inbox_outlined)
                  : Icons.category_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == null
                  ? (locationProvider.isLocationFilterEnabled
                  ? '주변에 상품이 없습니다'
                  : '상품이 없습니다')
                  : '해당 카테고리의 상품이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              locationProvider.isLocationFilterEnabled &&
                  _selectedCategory == null
                  ? '검색 반경을 늘리거나 필터를 해제해보세요'
                  : '다른 카테고리나 검색어를 시도해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('상품 검색'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: '상품명을 입력하세요',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('검색'),
            ),
          ],
        );
      },
    );
  }

  void _showSortDialog(LocationProvider locationProvider) {
    final availableSortTypes = locationProvider.isLocationFilterEnabled
        ? SortType.values
        : SortType.values.where((type) => type != SortType.distance).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('정렬 방식'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableSortTypes.map((sortType) {
              return RadioListTile<SortType>(
                title: Text(sortType.displayName),
                value: sortType,
                groupValue: _sortType,
                onChanged: (value) {
                  setState(() {
                    _sortType = value!;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// asset 경로인지 확인
  bool _isAssetImage(String imageUrl) {
    return imageUrl.startsWith('lib/dummy_data/') ||
        imageUrl.startsWith('assets/');
  }

  /// 네트워크 이미지인지 확인
  bool _isNetworkImage(String imageUrl) {
    return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
  }

  String _normalizeAssetPath(String path) {
    if (path.startsWith('lib/dummy_data/')) {
      return path;
    }
    if (path.startsWith('assets/')) {
      return path;
    }
    return path;
  }

  String _getCategoryText(ProductCategory category) {
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

  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }
}

enum SortType {
  latest,
  priceLow,
  priceHigh,
  popular,
  distance,
}

extension SortTypeExtension on SortType {
  String get displayName {
    switch (this) {
      case SortType.latest:
        return '최신순';
      case SortType.priceLow:
        return '가격 낮은순';
      case SortType.priceHigh:
        return '가격 높은순';
      case SortType.popular:
        return '인기순';
      case SortType.distance:
        return '거리순';
    }
  }
}
