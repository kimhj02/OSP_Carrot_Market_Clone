import 'package:flutter/material.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/data/mock_products.dart';

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
    // 검색어로 필터링된 상품 리스트
    final filtered = _products
        .where((p) => p.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

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
      body: filtered.isEmpty
          ? const Center(child: Text('검색 결과가 없습니다.'))
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
