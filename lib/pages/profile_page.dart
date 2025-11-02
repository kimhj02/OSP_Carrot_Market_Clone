/// 사용자 프로필 페이지
///
/// 당근 마켓 스타일의 사용자 프로필 화면입니다.
/// 사용자 기본 정보와 내가 등록한 상품 목록을 표시합니다.
///
/// 주요 기능:
/// - 사용자 기본 정보 표시
/// - 내가 등록한 상품 목록 표시
/// - 판매중/예약중/판매완료 탭 구분
/// - 로그아웃 기능
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:flutter_sandbox/providers/kakao_login_provider.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';

/// 사용자 프로필 페이지를 나타내는 위젯
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  /// 상품 상태 탭 컨트롤러
  late TabController _tabController;

  /// 내가 등록한 상품 목록 (임시 데이터)
  List<Product> _myProducts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMyProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 내가 등록한 상품 목록을 로드하는 메서드 (임시 데이터)
  void _loadMyProducts() {
    // 실제로는 sellerId로 필터링하여 가져옵니다
    _myProducts = [
      Product(
        id: '1',
        title: '아이폰 14 Pro 256GB',
        description: '거의 새 제품입니다. 케이스와 액정보호필름 포함',
        price: 800000,
        imageUrls: ['lib/dummy_data/아이폰.jpeg'],
        category: ProductCategory.digital,
        status: ProductStatus.onSale,
        sellerId: 'seller1',
        sellerNickname: '김철수',
        location: '역삼동',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        viewCount: 45,
        likeCount: 12,
      ),
      Product(
        id: '2',
        title: '맥북 에어 M2 13인치',
        description: '2023년 구매, 보증기간 남음',
        price: 1200000,
        imageUrls: ['lib/dummy_data/맥북.jpeg'],
        category: ProductCategory.digital,
        status: ProductStatus.reserved,
        sellerId: 'seller1',
        sellerNickname: '김철수',
        location: '역삼동',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        viewCount: 78,
        likeCount: 23,
      ),
      Product(
        id: '3',
        title: '나이키 에어포스',
        description: '사이즈 270, 3번 정도만 신었습니다',
        price: 80000,
        imageUrls: ['lib/dummy_data/에어포스.jpeg'],
        category: ProductCategory.sports,
        status: ProductStatus.sold,
        sellerId: 'seller1',
        sellerNickname: '김철수',
        location: '역삼동',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        viewCount: 32,
        likeCount: 8,
      ),
    ];
  }

  /// 현재 선택된 탭에 해당하는 상품 목록을 반환하는 메서드
  List<Product> get _filteredProducts {
    final selectedIndex = _tabController.index;
    switch (selectedIndex) {
      case 0: // 판매중
        return _myProducts.where((p) => p.status == ProductStatus.onSale).toList();
      case 1: // 예약중
        return _myProducts.where((p) => p.status == ProductStatus.reserved).toList();
      case 2: // 판매완료
        return _myProducts.where((p) => p.status == ProductStatus.sold).toList();
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
        title: const Text(
          '나의 금오',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              // 설정 기능 (향후 구현)
            },
          ),
        ],
      ),
      body: Consumer2<KakaoLoginProvider, EmailAuthProvider>(
        builder: (context, kakaoProvider, emailProvider, child) {
          final kakaoUser = kakaoProvider.user;
          final emailUser = emailProvider.user;
          final isLoggedIn = kakaoUser != null || emailUser != null;
          final isKakaoLogin = kakaoUser != null;

          return Column(
            children: [
              // 프로필 정보 섹션
              _buildProfileSection(
                context,
                kakaoUser,
                emailUser,
                isLoggedIn,
                isKakaoLogin,
                kakaoProvider,
                emailProvider,
              ),
              
              // 상품 상태 탭
              _buildTabBar(),
              
              // 상품 목록
              Expanded(
                child: _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : _buildProductGrid(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 프로필 정보 섹션을 생성하는 위젯
  Widget _buildProfileSection(
    BuildContext context,
    User? kakaoUser,
    dynamic emailUser,
    bool isLoggedIn,
    bool isKakaoLogin,
    KakaoLoginProvider kakaoProvider,
    EmailAuthProvider emailProvider,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 40,
            backgroundImage: isKakaoLogin
                ? (kakaoUser?.kakaoAccount?.profile?.profileImageUrl != null
                    ? NetworkImage(kakaoUser!.kakaoAccount!.profile!.profileImageUrl!)
                    : null)
                : (emailUser?.photoURL != null
                    ? NetworkImage(emailUser.photoURL!)
                    : null),
            child: (isKakaoLogin
                    ? kakaoUser?.kakaoAccount?.profile?.profileImageUrl == null
                    : emailUser?.photoURL == null)
                ? const Icon(Icons.person, color: Colors.grey, size: 40)
                : null,
          ),
          const SizedBox(height: 16),
          
          // 사용자 이름
          Text(
            isKakaoLogin
                ? (kakaoUser?.kakaoAccount?.profile?.nickname ?? '사용자')
                : (emailUser?.displayName ?? emailUser?.email ?? '사용자'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          
          // 로그인 방식 및 이메일
          Text(
            isKakaoLogin
                ? '카카오 로그인 • ID: ${kakaoUser?.id ?? ''}'
                : '이메일 로그인 • ${emailUser?.email ?? ''}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          
          // 위치 정보
          const Text(
            '강남구 역삼동',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          
          // 로그아웃 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                if (isKakaoLogin) {
                  await kakaoProvider.logout();
                } else {
                  await emailProvider.logout();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('로그아웃'),
            ),
          ),
        ],
      ),
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
          Tab(text: '예약중'),
          Tab(text: '판매완료'),
        ],
        onTap: (index) {
          setState(() {});
        },
      ),
    );
  }

  /// 상품 그리드를 생성하는 위젯
  Widget _buildProductGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: product.imageUrls.isNotEmpty
                      ? product.imageUrls.first.startsWith('lib/')
                          ? Image.asset(
                              product.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            )
                          : Image.network(
                              product.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, color: Colors.grey),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            '등록한 상품이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyMessage(),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 메시지를 반환하는 메서드
  String _getEmptyMessage() {
    switch (_tabController.index) {
      case 0:
        return '판매할 상품을 등록해보세요';
      case 1:
        return '예약된 상품이 없습니다';
      case 2:
        return '판매 완료된 상품이 없습니다';
      default:
        return '';
    }
  }
}

