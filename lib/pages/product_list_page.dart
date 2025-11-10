/// 상품 목록 페이지
///
/// 당근 마켓의 상품 목록을 표시하는 화면입니다.
/// 카테고리별 필터링, 검색, 정렬 기능을 제공합니다.
///
/// 주요 기능:
/// - 상품 목록 표시
/// - 카테고리별 필터링
/// - 검색 기능
/// - 정렬 기능 (최신순, 가격순, 인기순)
/// - 상품 상세 페이지로 이동
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/models/ad.dart';
import 'package:flutter_sandbox/providers/ad_provider.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/widgets/ad_card.dart';
import 'package:flutter_sandbox/data/mock_products.dart';

/// 상품 목록을 표시하는 페이지
class ProductListPage extends StatefulWidget {
  final ProductCategory? initialCategory;

  const ProductListPage({super.key, this.initialCategory});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  /// 현재 선택된 카테고리
  ProductCategory? _selectedCategory;

  /// 검색어
  String _searchQuery = '';

  /// 정렬 방식
  SortType _sortType = SortType.latest;

  /// 상품 목록 (임시 데이터)
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    // initialCategory가 있으면 초기 카테고리로 설정
    _selectedCategory = widget.initialCategory;
    _loadProducts();
  }

  /// 상품 목록을 로드하는 메서드 (임시 데이터)
  void _loadProducts() {
    // 실제로는 API에서 데이터를 가져옵니다
    _products = getMockProducts();
  }

  /// 필터링된 상품 목록을 반환하는 메서드
  List<Product> get _filteredProducts {
    List<Product> filtered = _products;

    // 카테고리 필터링
    if (_selectedCategory != null) {
      filtered = filtered
          .where((product) => product.category == _selectedCategory)
          .toList();
    }

    // 검색어 필터링
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (product) =>
                product.title.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                product.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    // 정렬
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
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _showSortDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 카테고리 필터
          _buildCategoryFilter(),

          // 상품 목록
          Expanded(
            child: _filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductList(),
          ),
        ],
      ),
    );
  }

  /// 카테고리 필터를 생성하는 위젯
  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 전체 카테고리
          _buildCategoryChip('전체', null),
          const SizedBox(width: 8),

          // 각 카테고리
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

  /// 카테고리 칩을 생성하는 위젯
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

  /// 상품 목록과 광고를 병합한 리스트를 반환하는 메서드
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

  /// 상품 목록을 생성하는 위젯
  Widget _buildProductList() {
    return Consumer<AdProvider>(
      builder: (context, adProvider, child) {
        final mergedList = _getMergedList(
          _filteredProducts,
          adProvider.activeAds,
        );

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mergedList.length,
          itemBuilder: (context, index) {
            final item = mergedList[index];

            // 타입에 따라 Product 또는 Ad 렌더링
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

  /// 상품 아이템을 생성하는 위젯
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
              // 상품 이미지
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
                            if (_isAssetImage(imagePath)) {
                              final normalizedPath = _normalizeAssetPath(
                                imagePath,
                              );
                              debugPrint(
                                '이미지 로드 시도: 원본=$imagePath, 정규화=$normalizedPath',
                              );
                              return Image.asset(
                                normalizedPath,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('❌ Asset 이미지 로드 실패: $imagePath');
                                  debugPrint('❌ 정규화된 경로: $normalizedPath');
                                  debugPrint('❌ 에러: $error');
                                  debugPrint('❌ StackTrace: $stackTrace');
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 30,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '오류',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                frameBuilder:
                                    (
                                      context,
                                      child,
                                      frame,
                                      wasSynchronouslyLoaded,
                                    ) {
                                      if (wasSynchronouslyLoaded) {
                                        debugPrint(
                                          '✅ 이미지 동기 로드 성공: $normalizedPath',
                                        );
                                        return child;
                                      }
                                      if (frame != null) {
                                        debugPrint(
                                          '✅ 이미지 비동기 로드 성공: $normalizedPath',
                                        );
                                        return child;
                                      }
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              );
                            } else {
                              return Image.network(
                                imagePath,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              // 상품 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상품 제목
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

                    // 상품 설명
                    Text(
                      product.description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // 가격과 위치
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

                    // 조회수와 찜 수
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
                        Icon(Icons.favorite, size: 14, color: Colors.grey[600]),
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

  /// 빈 상태를 표시하는 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '상품이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 카테고리나 검색어를 시도해보세요',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// 검색 다이얼로그를 표시하는 메서드
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

  /// 정렬 다이얼로그를 표시하는 메서드
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('정렬 방식'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SortType.values.map((sortType) {
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

  /// 이미지 URL이 asset 경로인지 확인하는 메서드
  bool _isAssetImage(String imageUrl) {
    return imageUrl.contains('dummy_data') ||
        imageUrl.startsWith('lib/') ||
        imageUrl.startsWith('assets/');
  }

  /// Asset 경로를 정규화하는 메서드
  String _normalizeAssetPath(String path) {
    // lib/dummy_data/ 경로는 그대로 사용
    // Flutter에서 asset 경로는 pubspec.yaml에 등록된 경로와 일치해야 함
    if (path.startsWith('lib/dummy_data/')) {
      return path;
    }
    // assets/로 시작하는 경우
    if (path.startsWith('assets/')) {
      return path;
    }
    // 다른 경로는 그대로 반환
    return path;
  }

  /// 카테고리 텍스트를 반환하는 메서드
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
    }
  }

  /// 상품 상세 페이지로 이동하는 메서드
  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }
}

/// 정렬 방식을 나타내는 열거형
enum SortType {
  /// 최신순
  latest,

  /// 가격 낮은순
  priceLow,

  /// 가격 높은순
  priceHigh,

  /// 인기순
  popular,
}

/// SortType 확장 메서드
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
    }
  }
}
