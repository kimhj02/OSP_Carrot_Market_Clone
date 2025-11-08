import 'package:flutter/material.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 나중에 products를 디비에서 가져오기
  final List<Product> _products = [
    Product(
      id: 'p1',
      title: '맥북 프로 16인치 M2 Max',
      description: '상태 A급입니다. 배터리 사이클 50회 미만!',
      price: 2500000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2015/01/21/14/14/apple-606761_1280.jpg',
      ],
      category: ProductCategory.digital,
      status: ProductStatus.onSale,
      sellerId: 'u1',
      sellerNickname: '토미오카기유',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2020/07/01/12/58/avatar-5357766_1280.png',
      location: '서울 강남구 역삼동',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now(),
      viewCount: 123,
      likeCount: 10,
      isLiked: false,
      x: 37.4979,
      y: 127.0276,
    ),
    Product(
      id: 'p2',
      title: '닌텐도 스위치 OLED',
      description: '화이트 색상, 구성품 모두 있습니다.',
      price: 380000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2017/01/10/19/05/nintendo-switch-1966317_1280.jpg',
      ],
      category: ProductCategory.digital,
      status: ProductStatus.onSale,
      sellerId: 'u2',
      sellerNickname: '도깨비감자',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2021/02/21/18/39/avatar-6039862_1280.png',
      location: '서울 마포구 망원동',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      updatedAt: DateTime.now(),
      viewCount: 98,
      likeCount: 6,
      isLiked: true,
      x: 37.5553,
      y: 126.9109,
    ),
    Product(
      id: 'p3',
      title: '커피머신 네스프레소 버츄오',
      description: '1년 사용, 작동 잘 됩니다. 캡슐 몇 개 드려요.',
      price: 90000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2017/08/10/07/32/coffee-2620202_1280.jpg',
      ],
      category: ProductCategory.etc,
      status: ProductStatus.reserved,
      sellerId: 'u3',
      sellerNickname: '하루한잔',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2016/03/31/19/14/avatar-1295401_1280.png',
      location: '서울 서초구 방배동',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
      viewCount: 201,
      likeCount: 14,
      isLiked: false,
      x: 37.4813,
      y: 127.0086,
    ),
    Product(
      id: 'p4',
      title: '아이폰 15 프로 256GB',
      description: '실사용 2개월, 배터리 100%, 구성품 풀박스입니다.',
      price: 1450000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2015/12/09/17/12/iphone-1087840_1280.jpg',
      ],
      category: ProductCategory.digital,
      status: ProductStatus.onSale,
      sellerId: 'u4',
      sellerNickname: '사과농장주',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2016/08/08/09/17/avatar-1577909_1280.png',
      location: '서울 송파구 잠실동',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      updatedAt: DateTime.now(),
      viewCount: 83,
      likeCount: 4,
      isLiked: false,
      x: 37.5101,
      y: 127.0827,
    ),
    Product(
      id: 'p5',
      title: '운동용 스핀바이크',
      description: '거의 새 제품이에요. 실내 운동용으로 좋아요.',
      price: 120000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2017/03/02/04/24/spin-bike-2119547_1280.jpg',
      ],
      category: ProductCategory.sports,
      status: ProductStatus.onSale,
      sellerId: 'u5',
      sellerNickname: '헬창토끼',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
      location: '서울 동작구 상도동',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      updatedAt: DateTime.now(),
      viewCount: 64,
      likeCount: 2,
      isLiked: false,
      x: 37.502,
      y: 126.9538,
    ),
    Product(
      id: 'p6',
      title: '반려동물 이동가방',
      description: '중형견용, 3번 사용했습니다. 깨끗합니다.',
      price: 25000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2018/08/06/20/04/dog-carrier-3588554_1280.jpg',
      ],
      category: ProductCategory.pets,
      status: ProductStatus.onSale,
      sellerId: 'u6',
      sellerNickname: '강쥐맘',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2021/01/21/15/41/avatar-5933465_1280.png',
      location: '서울 은평구 불광동',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
      viewCount: 47,
      likeCount: 1,
      isLiked: false,
      x: 37.6232,
      y: 126.9294,
    ),
    Product(
      id: 'p7',
      title: '원목 2인용 식탁세트',
      description: '튼튼한 원목 테이블과 의자 2개 세트입니다.',
      price: 85000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2016/11/18/12/52/dining-room-1835926_1280.jpg',
      ],
      category: ProductCategory.furniture,
      status: ProductStatus.sold,
      sellerId: 'u7',
      sellerNickname: '방배장인',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2020/09/02/14/35/avatar-5537860_1280.png',
      location: '서울 서초구 서초동',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now(),
      viewCount: 182,
      likeCount: 11,
      isLiked: false,
      x: 37.4913,
      y: 127.0079,
    ),
    Product(
      id: 'p8',
      title: '여성 코트 (자라 ZARA)',
      description: '겨울용 코트, S 사이즈. 2번 착용했습니다.',
      price: 55000,
      imageUrls: [
        'https://cdn.pixabay.com/photo/2016/10/19/07/28/fashion-1758836_1280.jpg',
      ],
      category: ProductCategory.womenClothing,
      status: ProductStatus.onSale,
      sellerId: 'u8',
      sellerNickname: '패션러버',
      sellerProfileImageUrl:
          'https://cdn.pixabay.com/photo/2022/03/04/17/21/avatar-7046219_1280.png',
      location: '서울 성동구 성수동',
      createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      updatedAt: DateTime.now(),
      viewCount: 69,
      likeCount: 3,
      isLiked: false,
      x: 37.5467,
      y: 127.0444,
    ),
  ];

  String _query = ''; // 검색어 상태

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
                    child: Image.network(
                      product.imageUrls.first,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(product.title),
                  subtitle:
                      Text('${product.formattedPrice} · ${product.location}'),
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
