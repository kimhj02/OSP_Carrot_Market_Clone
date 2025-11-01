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
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:flutter_sandbox/providers/kakao_login_provider.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/pages/product_list_page.dart';
import 'package:flutter_sandbox/pages/product_create_page.dart';
import 'package:flutter_sandbox/pages/product_delete_page.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/pages/chat_list_page.dart';
import 'package:flutter_sandbox/pages/email_auth_page.dart';
import 'package:flutter_sandbox/pages/map_page.dart';
import 'package:flutter_sandbox/models/product.dart';

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

  @override
  Widget build(BuildContext context) {
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
              // 검색 기능 (향후 구현)
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
                  : _buildMainScreen(
                      kakaoUser,
                      loginProvider,
                      emailUser,
                      emailAuthProvider,
                      context,
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
        ],
      ),

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
    // 로그인된 사용자 정보 (카카오 또는 이메일)
    final isKakaoLogin = kakaoUser != null;
    // 타입 안전성을 위한 사용자 정보 추출
    final kakaoUserNonNull = kakaoUser;
    final emailUserNonNull = emailUser;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 배너 영역
          Container(
            width: double.infinity,
            height: 120,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '안녕하세요!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '오늘도 좋은 하루 되세요',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // 카테고리 섹션
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '카테고리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // 카테고리 그리드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              children: [
                _buildCategoryItem(Icons.phone_android, '디지털기기', context),
                _buildCategoryItem(Icons.home, '가구/인테리어', context),
                _buildCategoryItem(Icons.child_care, '유아동', context),
                _buildCategoryItem(Icons.pets, '반려동물', context),
                _buildCategoryItem(Icons.sports_soccer, '스포츠/레저', context),
                _buildCategoryItem(Icons.woman, '여성의류', context),
                _buildCategoryItem(Icons.man, '남성의류', context),
                _buildCategoryItem(Icons.more_horiz, '기타', context),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 인기 상품 섹션
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '인기 상품',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductListPage(),
                      ),
                    );
                  },
                  child: const Text(
                    '더보기',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 상품 목록 (임시 데이터)
          _buildProductList(),

          const SizedBox(height: 24),

          // 바로 가기 섹션 (상품 등록/삭제/채팅)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '바로 가기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProductCreatePage(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            side: const BorderSide(color: Colors.teal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('상품 등록'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProductDeletePage(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('상품 삭제'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 1:1 채팅 바로가기 버튼 제거됨
              ],
            ),
          ),

          // 사용자 정보 및 로그아웃 버튼
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // 프로필 정보
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: isKakaoLogin
                          ? (kakaoUserNonNull
                                        ?.kakaoAccount
                                        ?.profile
                                        ?.profileImageUrl !=
                                    null
                                ? NetworkImage(
                                    kakaoUserNonNull!
                                        .kakaoAccount!
                                        .profile!
                                        .profileImageUrl!,
                                  )
                                : null)
                          : (emailUserNonNull?.photoURL != null
                                ? NetworkImage(emailUserNonNull.photoURL!)
                                : null),
                      child: isKakaoLogin
                          ? (kakaoUserNonNull
                                        ?.kakaoAccount
                                        ?.profile
                                        ?.profileImageUrl ==
                                    null
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null)
                          : (emailUserNonNull?.photoURL == null
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isKakaoLogin
                                ? (kakaoUserNonNull
                                          ?.kakaoAccount
                                          ?.profile
                                          ?.nickname ??
                                      '사용자')
                                : (emailUserNonNull?.displayName ??
                                      emailUserNonNull?.email ??
                                      '사용자'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isKakaoLogin
                                ? 'ID: ${kakaoUserNonNull?.id ?? ''}'
                                : '이메일: ${emailUserNonNull?.email ?? ''}',
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
                const SizedBox(height: 16),

                // 로그아웃 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        IndexedStackState = 0;
                      });
                      if (isKakaoLogin) {
                        loginProvider.logout();
                      } else {
                        emailAuthProvider.logout();
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
          ),
        ],
      ),
    );
  }

  /// 카테고리 아이템을 생성하는 위젯
  Widget _buildCategoryItem(IconData icon, String label, BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 카테고리별 상품 목록으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProductListPage()),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.teal, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 상품 목록을 생성하는 위젯 (임시 데이터)
  /// 상품 인시 데이터 넣는 부분
  Widget _buildProductList() {
    final products = [
      {
        'title': '아이폰 14 Pro',
        'price': '800,000원',
        'location': '역삼동',
        'image': 'lib/dummy_data/아이폰.jpeg',
      },
      {
        'title': '맥북 에어 M2',
        'price': '1,200,000원',
        'location': '역삼동',
        'image': 'lib/dummy_data/맥북.jpeg',
      },
      {
        'title': '나이키 에어포스',
        'price': '80,000원',
        'location': '역삼동',
        'image': 'lib/dummy_data/에어포스.jpeg',
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () {
            // 임시 Product 객체 생성하여 상세 페이지로 이동
            // 실제로는 상품 ID를 통해 데이터를 가져와야 함
            final productModel = Product(
              id: 'temp_${product['title']}',
              title: product['title'] as String,
              description: '상세 정보를 확인하세요',
              price: int.parse(
                (product['price'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
              ),
              imageUrls: product['image'] != null
                  ? [product['image'] as String]
                  : [],
              category: ProductCategory.digital,
              status: ProductStatus.onSale,
              sellerId: 'seller_temp',
              sellerNickname: '판매자',
              location: product['location'] as String,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailPage(product: productModel),
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
                            product['image']!,
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
                                  if (frame != null || wasSynchronouslyLoaded) {
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
                        product['title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product['price']!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product['location']!,
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
  }
}

class Life extends StatelessWidget {
  const Life({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(child: Text('동네생활 페이지'));
  }
}

