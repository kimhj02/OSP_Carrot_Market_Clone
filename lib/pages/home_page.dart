/// 당근 마켓 스타일 홈 페이지 위젯
///
/// 당근 마켓과 유사한 UI/UX를 제공하는 메인 화면입니다.
/// Provider 패턴을 사용하여 로그인 상태에 따라 다른 UI를 표시합니다.
///
/// 주요 기능:
/// - 당근 마켓 스타일의 네비게이션 바
/// - 로그인 상태에 따른 조건부 UI 렌더링
/// - 상품 목록 표시 (향후 구현)
/// - 지도 기능 (향후 구현)
/// - 채팅 기능 (향후 구현)
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sandbox/pages/search_page.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:flutter_sandbox/providers/kakao_login_provider.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/pages/product_create_page.dart';
import 'package:flutter_sandbox/pages/group_buy_create_page.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/pages/chat_list_page.dart';
import 'package:flutter_sandbox/pages/email_auth_page.dart';
import 'package:flutter_sandbox/pages/map_page.dart';
import 'package:flutter_sandbox/pages/profile_page.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/data/mock_products.dart';
import 'package:flutter_sandbox/providers/ad_provider.dart';
import 'package:flutter_sandbox/models/ad.dart';
import 'package:flutter_sandbox/widgets/ad_card.dart';

/// 앱의 홈 페이지를 나타내는 위젯
///
/// Consumer를 사용하여 KakaoLoginProvider의 상태 변화를 감지하고,
/// 로그인 상태에 따라 다른 UI를 표시합니다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int IndexedStackState = 0;
  ProductCategory? _selectedCategory;
  OverlayEntry? _fabMenuOverlay;
  bool _isFabMenuOpen = false;

  @override
  void dispose() {
    _removeFabMenu(disposeOnly: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 로그아웃 상태를 감지하여 홈으로 자동 이동
    return Consumer2<KakaoLoginProvider, EmailAuthProvider>(
      builder: (context, loginProvider, emailAuthProvider, child) {
        // 로그인 상태 확인
        final isLoggedIn =
            loginProvider.user != null || emailAuthProvider.user != null;

        // 로그아웃 상태이고 다른 탭에 있으면 홈으로 이동
        if (!isLoggedIn && IndexedStackState != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              IndexedStackState = 0;
            });
          });
        }

        return _buildScaffold(context, isLoggedIn);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, bool isLoggedIn) {
    return Scaffold(
      // 금오 마켓 스타일의 앱바
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            // 금오 마켓 아이콘
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_grocery_store,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            // 위치 정보 (탭하면 지도로 이동)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
              child: const Row(
                children: [
                  Text(
                    '강남구 역삼동',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: Colors.black),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 검색 아이콘
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          // 메뉴 아이콘
          // IconButton(
          //   icon: const Icon(Icons.menu, color: Colors.black),
          //   onPressed: () {
          //     // 메뉴 기능 (향후 구현)
          //     //drawer state 바꾸기
          //   },
          // ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                "바로 마켓 메뉴",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text("컨텐츠 1"),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text("컨텐츠 2"),
              onTap: () {},
            ),
          ],
        ),
      ),

      // 메인 콘텐츠 영역
      body: IndexedStack(
        index: IndexedStackState,
        children: [
          Consumer2<KakaoLoginProvider, EmailAuthProvider>(
            builder: (context, loginProvider, emailAuthProvider, child) {
              // 카카오 또는 이메일 로그인 상태 확인
              final kakaoUser = loginProvider.user;
              final emailUser = emailAuthProvider.user;
              final isLoggedIn = kakaoUser != null || emailUser != null;

              // 로그인 상태에 따른 조건부 UI 렌더링
              return !isLoggedIn
                  ? _buildLoginScreen(loginProvider, context) // 로그인되지 않은 경우
                  : Column(
                      children: [
                        // 카테고리 필터 바
                        _buildCategoryFilter(),
                        // 메인 콘텐츠
                        Expanded(
                          child: _buildMainScreen(
                            kakaoUser,
                            loginProvider,
                            emailUser,
                            emailAuthProvider,
                            context,
                          ),
                        ),
                      ],
                    ); // 로그인된 경우
            },
          ), //홈

          Life(),

          Consumer2<KakaoLoginProvider, EmailAuthProvider>(
            builder: (context, loginProvider, emailAuthProvider, child) {
              final isLoggedIn =
                  loginProvider.user != null || emailAuthProvider.user != null;
              return !isLoggedIn
                  ? const Center(child: Text('로그인 해주세요'))
                  : const ChatListPage();
            },
          ),

          Consumer2<KakaoLoginProvider, EmailAuthProvider>(
            builder: (context, loginProvider, emailAuthProvider, child) {
              final isLoggedIn =
                  loginProvider.user != null || emailAuthProvider.user != null;
              return !isLoggedIn
                  ? const Center(child: Text('로그인 해주세요'))
                  : const ProfilePage();
            },
          ), // 나의 금오
        ],
      ),

      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
              backgroundColor: Colors.teal,
              onPressed: _toggleFabMenu,
              child: Icon(
                _isFabMenuOpen ? Icons.close : Icons.add,
                color: Colors.white,
              ),
            )
          : null,
      // 하단 네비게이션 바
      bottomNavigationBar: Consumer2<KakaoLoginProvider, EmailAuthProvider>(
        builder: (context, loginProvider, emailAuthProvider, child) {
          final isLoggedIn =
              loginProvider.user != null || emailAuthProvider.user != null;
          if (!isLoggedIn) return const SizedBox.shrink();

          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: IndexedStackState,
            selectedItemColor: Colors.teal,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_on),
                label: '동네생활',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                label: '채팅',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: '나의 금오'),
            ],
            onTap: (index) {
              if (index == 1) {
                // 동네생활 탭 -> 지도 화면으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
                return;
              }
              setState(() {
                IndexedStackState = index;
              });
            },
          );
        },
      ),
    );
  }

  void _toggleFabMenu() {
    if (_isFabMenuOpen) {
      _removeFabMenu();
    } else {
      _showFabMenu();
    }
  }

  void _showFabMenu() {
    final overlay = Overlay.of(context);

    _fabMenuOverlay = OverlayEntry(
      builder: (context) {
        return _FabMenuOverlay(
          onBackgroundTap: _removeFabMenu,
          onProductTap: () {
            _removeFabMenu();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductCreatePage(),
              ),
            );
          },
          onGroupBuyTap: () {
            _removeFabMenu();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GroupBuyCreatePage(),
              ),
            );
          },
        );
      },
    );

    overlay.insert(_fabMenuOverlay!);
    setState(() {
      _isFabMenuOpen = true;
    });
  }

  void _removeFabMenu({bool disposeOnly = false}) {
    if (!_isFabMenuOpen && !disposeOnly) return;
    _fabMenuOverlay?.remove();
    _fabMenuOverlay = null;
    if (!disposeOnly && mounted) {
      setState(() {
        _isFabMenuOpen = false;
      });
    } else {
      _isFabMenuOpen = false;
    }
  }

  /// 금오 마켓 스타일의 로그인 화면을 생성하는 위젯
  ///
  /// Parameters:
  /// - [loginProvider]: 카카오 로그인 Provider 인스턴스
  ///
  /// Returns:
  /// - [Widget]: 로그인 화면 위젯
  Widget _buildLoginScreen(
    KakaoLoginProvider loginProvider,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 금오 마켓 로고
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_grocery_store,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 32),

          // 환영 메시지
          const Text(
            '금오 마켓에 오신 것을 환영합니다!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          const Text(
            '동네 이웃들과 안전하게 거래해보세요',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // 카카오 로그인 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                await loginProvider.login();
                final isSuccess = loginProvider.user != null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isSuccess ? '카카오 로그인 성공' : '카카오 로그인 실패'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                '카카오로 시작하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 이메일 로그인 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmailAuthPage(),
                  ),
                );
              },
              icon: const Icon(Icons.email_outlined, color: Colors.black87),
              label: const Text(
                '이메일로 시작하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 금오 마켓 스타일의 메인 화면을 생성하는 위젯
  ///
  /// Parameters:
  /// - [kakaoUser]: 카카오 로그인된 사용자 정보 (null 가능)
  /// - [loginProvider]: 카카오 로그인 Provider 인스턴스
  /// - [emailUser]: 이메일 로그인된 사용자 정보 (null 가능)
  /// - [emailAuthProvider]: 이메일 인증 Provider 인스턴스
  /// - [context]: BuildContext
  ///
  /// Returns:
  /// - [Widget]: 메인 화면 위젯
  Widget _buildMainScreen(
    User? kakaoUser,
    KakaoLoginProvider loginProvider,
    dynamic emailUser,
    EmailAuthProvider emailAuthProvider,
    BuildContext context,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품 목록 (임시 데이터)
          _buildProductList(),
        ],
      ),
    );
  }

  /// 카테고리 필터 바를 생성하는 위젯
  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // 스크롤 활성화
        children: [
          // 전체 카테고리
          _buildCategoryChip('전체', null),
          const SizedBox(width: 8),
          // 같이사요 카테고리를 전체 바로 옆에 배치하고 나머지 카테고리 추가
          ...[
            ProductCategory.groupBuy,
            ...ProductCategory.values.where(
              (category) => category != ProductCategory.groupBuy,
            ),
          ].map(
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
    final isGroupBuy = category == ProductCategory.groupBuy;

    final Color? backgroundColor;
    final Color? textColor;
    Border? borderStyle;

    if (isGroupBuy) {
      if (isSelected) {
        backgroundColor = Colors.orange[100];
        textColor = Colors.orange[800];
        borderStyle = Border.all(color: Colors.orange[300]!, width: 1);
      } else {
        backgroundColor = Colors.orange[500];
        textColor = Colors.white;
      }
    } else {
      backgroundColor = isSelected ? Colors.white : Colors.grey[800];
      textColor = isSelected ? Colors.black87 : Colors.white;
      if (isSelected) {
        borderStyle = Border.all(color: Colors.grey[300]!, width: 1);
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
        // 카테고리 선택 시 홈 화면에서 해당 카테고리 상품만 필터링하여 표시
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: borderStyle,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
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
      case ProductCategory.groupBuy:
        return '같이사요';
    }
  }

  /// 상품과 광고를 병합한 리스트를 반환하는 메서드
  List<dynamic> _getMergedList(
    List<Map<String, dynamic>> products,
    List<Ad> ads,
  ) {
    if (products.length < 5) {
      return List<dynamic>.from(products);
    }

    final mergedList = <dynamic>[];
    final activeAds = ads.where((ad) => ad.isActive).toList();
    var adIndex = 0;

    for (var i = 0; i < products.length; i++) {
      mergedList.add(products[i]);

      final isLastAdIndex = (i + 1) >= products.length;
      final shouldInsertAd = (i + 1) % 5 == 0 && adIndex < activeAds.length;

      if (shouldInsertAd && !isLastAdIndex) {
        mergedList.add(activeAds[adIndex]);
        adIndex++;
      }
    }

    return mergedList;
  }

  /// 상품 목록을 생성하는 위젯 (임시 데이터)
  /// 상품 인시 데이터 넣는 부분
  Widget _buildProductList() {
    final allProducts = getMockProducts().map((product) {
      return {
        'title': product.title,
        'price': product.formattedPrice,
        'location': product.location,
        'image': product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
        'category': product.category,
        'product': product,
      };
    }).toList();

    // 선택된 카테고리에 따라 필터링
    final filteredProducts = _selectedCategory == null
        ? allProducts
        : allProducts.where((product) {
            return product['category'] == _selectedCategory;
          }).toList();

    // 필터링된 상품이 없을 때
    if (filteredProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            '해당 카테고리의 상품이 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Consumer<AdProvider>(
      builder: (context, adProvider, child) {
        // 상품과 광고를 병합
        final mergedList = _getMergedList(
          filteredProducts,
          adProvider.activeAds,
        );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mergedList.length,
          itemBuilder: (context, index) {
            final item = mergedList[index];

            // 타입에 따라 Product 또는 Ad 렌더링
            if (item is Ad) {
              return AdCard(ad: item);
            }

            // Map<String, dynamic> 형태의 상품 데이터
            final product = item as Map<String, dynamic>;
            final productModel = product['product'] as Product?;
            return GestureDetector(
              onTap: () {
                if (productModel == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProductDetailPage(product: productModel),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: product['image'] != null
                            ? Image.asset(
                                product['image']! as String,
                                fit: BoxFit.cover,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint(
                                    '❌ 홈 화면 이미지 로드 실패: ${product['image']}',
                                  );
                                  debugPrint('❌ 에러: $error');
                                  debugPrint('❌ StackTrace: $stackTrace');
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
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
                                      if (frame != null ||
                                          wasSynchronouslyLoaded) {
                                        debugPrint(
                                          '✅ 홈 화면 이미지 로드 성공: ${product['image']}',
                                        );
                                        return child;
                                      }
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              )
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 상품 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['title']! as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product['price']! as String,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product['location']! as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

}

class _FabMenuOverlay extends StatelessWidget {
  const _FabMenuOverlay({
    required this.onBackgroundTap,
    required this.onProductTap,
    required this.onGroupBuyTap,
  });

  final VoidCallback onBackgroundTap;
  final VoidCallback onProductTap;
  final VoidCallback onGroupBuyTap;

  @override
  Widget build(BuildContext context) {
    final double bottomOffset =
        kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom + 24;

    return Material(
      color: Colors.black45,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onBackgroundTap,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            right: 16,
            bottom: bottomOffset,
            child: _FabMenuPanel(
              onClose: onBackgroundTap,
              onProductTap: onProductTap,
              onGroupBuyTap: onGroupBuyTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _FabMenuPanel extends StatelessWidget {
  const _FabMenuPanel({
    required this.onClose,
    required this.onProductTap,
    required this.onGroupBuyTap,
  });

  final VoidCallback onClose;
  final VoidCallback onProductTap;
  final VoidCallback onGroupBuyTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _FabMenuItem(
          icon: Icons.storefront,
          iconColor: Colors.teal,
          title: '중고 상품 등록',
          onTap: onProductTap,
        ),
        const SizedBox(height: 12),
        _FabMenuItem(
          icon: Icons.group_add,
          iconColor: Colors.orange,
          title: '같이사요 모집',
          onTap: onGroupBuyTap,
        ),
        const SizedBox(height: 16),
        FloatingActionButton.small(
          heroTag: 'fabMenuClose',
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[800],
          onPressed: onClose,
          child: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _FabMenuItem extends StatelessWidget {
  const _FabMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Life extends StatelessWidget {
  const Life({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(child: Text('동네생활 페이지'));
  }
}
