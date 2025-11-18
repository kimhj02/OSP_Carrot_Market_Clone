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
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_sandbox/providers/kakao_login_provider.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart' as app_auth;
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/services/admin_service.dart';
import 'package:flutter_sandbox/pages/admin_page.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';

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

  /// 관리자 페이지 접근을 위한 설정 아이콘 탭 횟수
  int _settingsTapCount = 0;

  /// 관리자 서비스
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
      price: (data['price'] as int?) ?? 0,
      imageUrls: List<String>.from(data['images'] ?? []),
      category: ProductCategory.values[data['category'] as int? ?? 0],
      status: ProductStatus.values[data['status'] as int? ?? 0],
      sellerId: data['sellerUid'] as String? ?? '',
      sellerNickname: data['sellerName'] as String? ?? '',
      sellerProfileImageUrl: data['sellerPhotoUrl'] as String?,
      location: region?['name'] as String? ?? '알 수 없는 지역',
      createdAt: createdAt?.toDate() ?? DateTime.now(),
      updatedAt: updatedAt?.toDate() ?? DateTime.now(),
      viewCount: data['viewCount'] as int? ?? 0,
      likeCount: data['likeCount'] as int? ?? 0,
      isLiked: viewerUid != null && likedUserIds.contains(viewerUid),
      x: location?.latitude ?? 0.0,
      y: location?.longitude ?? 0.0,
      meetLocationDetail: data['meetLocationDetail'] as String?,
    );
  }

  /// 현재 선택된 탭에 해당하는 상품 목록을 필터링
  List<Product> _filterProducts(List<Product> products, int tabIndex, String? currentUserId) {
    switch (tabIndex) {
      case 0: // 판매중 - 내가 판매중인 상품만
        return products
            .where((p) => p.status == ProductStatus.onSale && p.sellerId == currentUserId)
            .toList();
      case 1: // 예약중 - 내가 예약중인 상품만
        return products
            .where((p) => p.status == ProductStatus.reserved && p.sellerId == currentUserId)
            .toList();
      case 2: // 판매완료 - 내가 판매완료한 상품만
        return products
            .where((p) => p.status == ProductStatus.sold && p.sellerId == currentUserId)
            .toList();
      case 3: // 찜한 상품 - 찜한 상품만 (내 상품이 아닌 것도 포함)
        return products.where((p) => p.isLiked).toList();
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Consumer2<KakaoLoginProvider, app_auth.EmailAuthProvider>(
        builder: (context, kakaoProvider, emailProvider, child) {
          final kakaoUser = kakaoProvider.user;
          final emailUser = emailProvider.user;
          final isLoggedIn = kakaoUser != null || emailUser != null;
          final isKakaoLogin = kakaoUser != null;

          return Column(
            children: [
              // 헤더 (제목 + 설정 버튼)
              _buildHeader(context),
              
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
                child: _buildProductList(),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  /// 헤더 위젯 (제목 + 설정 버튼)
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text(
            '내 프로필',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87, size: 28),
            iconSize: 28,
            onPressed: () async {
              _settingsTapCount++;
              if (_settingsTapCount >= 10) {
                _settingsTapCount = 0;
                final isAdmin = await _adminService.isAdmin();
                if (isAdmin && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminPage()),
                  );
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('관리자 권한이 없습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } else {
                // 3초 후 탭 횟수 리셋
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _settingsTapCount = 0;
                    });
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  /// 프로필 정보 섹션을 생성하는 위젯
  Widget _buildProfileSection(
    BuildContext context,
    kakao.User? kakaoUser,
    AppUserProfile? emailUser,
    bool isLoggedIn,
    bool isKakaoLogin,
    KakaoLoginProvider kakaoProvider,
    app_auth.EmailAuthProvider emailProvider,
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
                      ? NetworkImage(
                          kakaoUser!.kakaoAccount!.profile!.profileImageUrl!,
                        )
                      : null)
                : (emailUser?.photoUrl != null
                      ? NetworkImage(emailUser!.photoUrl!)
                      : null),
            child:
                (isKakaoLogin
                    ? kakaoUser?.kakaoAccount?.profile?.profileImageUrl == null
                    : emailUser?.photoUrl == null)
                ? const Icon(Icons.person, color: Colors.grey, size: 40)
                : null,
          ),
          const SizedBox(height: 16),

          // 사용자 이름
          Text(
            isKakaoLogin
                ? (kakaoUser?.kakaoAccount?.profile?.nickname ?? '사용자')
                : (emailUser?.displayName ?? emailUser?.email ?? '사용자'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          // 로그인 방식 및 이메일
          Text(
            isKakaoLogin
                ? '카카오 로그인 • ID: ${kakaoUser?.id ?? ''}'
                : '이메일 로그인 • ${emailUser?.email ?? ''}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 4),

          // 위치 정보
          const Text(
            '강남구 역삼동',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
        isScrollable: true,
        tabs: const [
          Tab(text: '판매중'),
          Tab(text: '예약중'),
          Tab(text: '판매완료'),
          Tab(text: '찜한 상품'),
        ],
        onTap: (index) {
          setState(() {});
        },
      ),
    );
  }

  /// 상품 목록을 빌드하는 위젯
  Widget _buildProductList() {
    final currentUser = context.watch<app_auth.EmailAuthProvider>().user;
    if (currentUser == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }

    if (AppConfig.useFirebase) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerUid', isEqualTo: currentUser.uid)
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
            return _firestoreDocToProduct(doc.id, data, currentUser.uid);
          }).toList() ?? [];
          
          // 최신순으로 정렬 (클라이언트 측)
          allProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          // 찜한 상품도 가져오기 (찜한 상품 탭용)
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('likedUserIds', arrayContains: currentUser.uid)
                .snapshots(),
            builder: (context, likedSnapshot) {
              final likedProducts = likedSnapshot.data?.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _firestoreDocToProduct(doc.id, data, currentUser.uid);
              }).toList() ?? [];
              
              // 최신순으로 정렬 (클라이언트 측)
              likedProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              
              // 탭에 따라 다른 상품 목록 사용
              // 판매중/예약중/판매완료 탭: 내 상품만
              // 찜한 상품 탭: 찜한 상품만
              final productsToShow = _tabController.index == 3
                  ? likedProducts
                  : allProducts;
              
              final filtered = _filterProducts(productsToShow, _tabController.index, currentUser.uid);
              
              if (filtered.isEmpty) {
                return _buildEmptyState();
              }
              
              return _buildProductGrid(filtered);
            },
          );
        },
      );
    } else {
      // 로컬 모드
      final allProducts = LocalAppRepository.instance
          .getProducts(viewerUid: currentUser.uid)
          .where((p) => p.sellerId == currentUser.uid)
          .toList();
      
      final likedProducts = LocalAppRepository.instance
          .getProducts(viewerUid: currentUser.uid)
          .where((p) => p.isLiked)
          .toList();
      
      // 탭에 따라 다른 상품 목록 사용
      final productsToShow = _tabController.index == 3
          ? likedProducts
          : allProducts;
      
      final filtered = _filterProducts(productsToShow, _tabController.index, currentUser.uid);
      
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
      case 3:
        return '찜한 상품이 없습니다';
      default:
        return '';
    }
  }
}
