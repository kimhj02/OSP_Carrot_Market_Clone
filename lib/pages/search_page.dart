import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/data/mock_products.dart';
import 'package:flutter_sandbox/providers/location_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 나중에 products를 디비에서 가져오기
  late final List<Product> _products;

  String _query = ''; // 검색어 상태

  @override
  void initState() {
    super.initState();
    _products = getMockProducts();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    
    // 검색어로 필터링된 상품 리스트
    var filtered = _products
        .where((p) => p.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    // 위치 필터링 적용 (현재 위치 또는 학교 주변)
    if (locationProvider.isLocationFilterEnabled &&
        locationProvider.filterLatitude != null &&
        locationProvider.filterLongitude != null) {
      filtered = filtered.where((product) {
        // Product의 x, y가 유효한 경우에만 거리 계산
        if (product.x == 0.0 && product.y == 0.0) {
          return false; // 위치 정보가 없는 상품은 제외
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
          _buildFilterInfo(locationProvider, filtered.length),
          // 검색 결과 리스트
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(_query, locationProvider)
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 필터링 정보를 표시하는 위젯
  Widget _buildFilterInfo(LocationProvider locationProvider, int resultCount) {
    if (!locationProvider.isLocationFilterEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.teal.withOpacity(0.05),
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
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.withOpacity(0.3)),
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
  const _ProductThumbnail({super.key, required this.imageUrls});

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
  const _FallbackThumbnail({super.key});

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
