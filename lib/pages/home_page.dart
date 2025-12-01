/// 당근 마켓 스타일 홈 페이지 위젯
///
/// 당근 마켓과 유사한 UI/UX를 제공하는 메인 화면입니다.
/// Provider 패턴을 사용하여 로그인 상태에 따라 다른 UI를 표시합니다.
///
/// 주요 기능:
/// - 당근 마켓 스타일의 네비게이션 바
/// - 로그인 상태에 따른 조건부 UI 렌더링
/// - 상품 목록 표시 (위치 필터링 지원)
/// - 지도 기능 (위치 기반 상품 표시)
/// - 채팅 기능 (실시간 메시지 송수신)
/// - 위치 필터링 (현재 위치/학교 주변)
/// - 검색 반경 조정 (500m, 1km, 2km, 5km)
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sandbox/pages/search_page.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_sandbox/providers/kakao_login_provider.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/pages/product_create_page.dart';
import 'package:flutter_sandbox/pages/group_buy_create_page.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/pages/chat_list_page.dart';
import 'package:flutter_sandbox/pages/email_auth_page.dart';
import 'package:flutter_sandbox/pages/map_page.dart';
import 'package:flutter_sandbox/pages/profile_page.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/providers/ad_provider.dart';
import 'package:flutter_sandbox/models/ad.dart';
import 'package:flutter_sandbox/widgets/ad_card.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/providers/location_provider.dart';

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

  /// 이미지 URL이 asset 경로인지 확인하는 메서드
  bool _isAssetImage(String imageUrl) {
    return imageUrl.startsWith('lib/dummy_data/') ||
        imageUrl.startsWith('assets/');
  }


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
    final AppUserProfile? appUser = context.watch<EmailAuthProvider>().user;
    final locationLabel =
        appUser != null ? _resolveLocationLabel(appUser) : '강남구 역삼동';
    // 로그인하지 않은 경우와 채팅(2), 내 정보(3) 탭에서는 AppBar 숨김
    final shouldShowAppBar =
        isLoggedIn && IndexedStackState != 2 && IndexedStackState != 3;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // 금오 마켓 스타일의 앱바
      appBar: shouldShowAppBar ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            // 금오 마켓 아이콘
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_grocery_store,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            // 위치 정보
            Row(
              children: [
                Consumer2<LocationProvider, EmailAuthProvider>(
                  builder: (context, locationProvider, emailAuthProvider, child) {
                    String displayText;
                    if (locationProvider.isCurrentLocationSelected) {
                      displayText = '내 현재 위치';
                    } else if (locationProvider.isSchoolSelected) {
                      // 학교 선택 시 이메일로 등록한 학교 이름 표시
                      final appUser = emailAuthProvider.user;
                      if (appUser != null) {
                        final schoolName = _resolveLocationLabel(appUser);
                        displayText = schoolName;
                      } else {
                        displayText = '학교';
                      }
                    } else {
                      displayText = locationLabel;
                    }
                    
                    // 위치 필터링이 활성화되어 있으면 반경 표시 추가
                    if (locationProvider.isLocationFilterEnabled) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayText,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
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
                      );
                    } else {
                      return Text(
                        displayText,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                  },
                ),
                GestureDetector(
                  onTap: () {
                    _showLocationSelectionDialog();
                  },
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.black87,
                    size: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 검색 아이콘
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87, size: 28),
            iconSize: 28,
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
      ) : null,

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
                  ? _buildLoginScreen(context) // 로그인되지 않은 경우
                  : Container(
                      color: Colors.grey[50],
                      child: Column(
                        children: [
                          // 위치 필터링 상태 및 상품 개수 표시
                          _buildLocationFilterInfo(),
                          // 카테고리 필터 바
                          _buildCategoryFilter(),
                          // 메인 콘텐츠
                          Expanded(
                            child: Container(
                              color: Colors.grey[50],
                              child: _buildMainScreen(
                                kakaoUser,
                                loginProvider,
                                emailUser,
                                emailAuthProvider,
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
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
          ), // 내 정보
        ],
      ),

      floatingActionButton: isLoggedIn && shouldShowAppBar
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
              BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
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

  String _resolveLocationLabel(AppUserProfile user) {
    // 학교 이름만 표시
    final universityName =
        LocalAppRepository.instance.getUniversityName(user.universityId);
    if (universityName != null && universityName.isNotEmpty) {
      return universityName;
    }
    // 학교 정보가 없으면 기본값
    return '대표 동네 미설정';
  }

  Future<bool> _handleLocationPermission() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // GPS 켜져있는지 확인
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS가 꺼져 있습니다. 설정에서 켜주세요.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        final opened = await Geolocator.openLocationSettings();
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('설정을 열 수 없습니다. 수동으로 GPS를 켜주세요.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // 권한 확인
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('위치 권한이 필요합니다. 앱 설정에서 권한을 허용해주세요.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '설정 열기',
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
              ),
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위치 권한 확인 중 오류가 발생했습니다: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  void _showLocationSelectionDialog() {
    final locationProvider = context.read<LocationProvider>();
    final appUser = context.read<EmailAuthProvider>().user;
    final schoolName = appUser != null ? _resolveLocationLabel(appUser) : '학교';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('위치 선택'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 필터링 해제 옵션 (필터가 활성화되어 있을 때만 표시)
                    if (locationProvider.isLocationFilterEnabled)
                      ListTile(
                        leading: const Icon(Icons.location_off, color: Colors.grey),
                        title: const Text('전체 지역 보기'),
                        subtitle: const Text('모든 지역의 상품을 보여줍니다'),
                        onTap: () {
                          locationProvider.clearLocationFilter();
                          Navigator.pop(context);
                        },
                      ),
                    if (locationProvider.isLocationFilterEnabled)
                      const Divider(),
                    
                    // 위치 선택 옵션
                    if (!locationProvider.isCurrentLocationSelected)
                      ListTile(
                        leading: const Icon(Icons.my_location, color: Colors.teal),
                        title: const Text('내 현재 위치'),
                        subtitle: Text('현재 위치 주변 ${locationProvider.searchRadiusText} 내 상품을 보여줍니다'),
                        onTap: () {
                          Navigator.pop(context);
                          _selectCurrentLocation();
                        },
                      ),
                    if (!locationProvider.isSchoolSelected)
                      ListTile(
                        leading: const Icon(Icons.school, color: Colors.teal),
                        title: Text(schoolName),
                        subtitle: Text('학교 주변 ${locationProvider.searchRadiusText} 내 상품을 보여줍니다'),
                        onTap: () {
                          Navigator.pop(context);
                          _selectSchool();
                        },
                      ),
                    
                    // 검색 반경 선택 (필터가 활성화되어 있을 때만 표시)
                    if (locationProvider.isLocationFilterEnabled) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '검색 반경',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      ...LocationProvider.searchRadiusOptions.map((radius) {
                        final radiusText = radius >= 1000
                            ? '${(radius / 1000).toStringAsFixed(0)}km'
                            : '${radius.toInt()}m';
                        return RadioListTile<double>(
                          title: Text(radiusText),
                          value: radius,
                          groupValue: locationProvider.searchRadius,
                          onChanged: (value) {
                            if (value != null) {
                              locationProvider.setSearchRadius(value);
                              setState(() {});
                            }
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectCurrentLocation() async {
    final locationProvider = context.read<LocationProvider>();
    
    // 캐시된 위치가 있으면 즉시 사용 (즉시 UI 업데이트)
    if (locationProvider.currentLatitude != null && 
        locationProvider.currentLongitude != null) {
      locationProvider.setCurrentLocation(
        locationProvider.currentLatitude!,
        locationProvider.currentLongitude!,
      );
      
      // 화면 리로드
      if (mounted) {
        setState(() {});
      }
      
      // 백그라운드에서 최신 위치 가져오기
      _updateCurrentLocationInBackground();
      return;
    }

    // 캐시된 위치가 없으면 위치 가져오기
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('현재 위치를 가져오는 중...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final hasPermission = await _handleLocationPermission();
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('위치 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (!mounted) return;
      
      locationProvider.setCurrentLocation(
        position.latitude,
        position.longitude,
      );
      
      // 화면 리로드
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('현재 위치 주변 ${locationProvider.searchRadiusText} 내 상품을 표시합니다'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치 정보를 가져오는 데 시간이 오래 걸립니다. 네트워크 상태를 확인해주세요.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('현재 위치를 가져올 수 없습니다: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '다시 시도',
            onPressed: () => _selectCurrentLocation(),
          ),
        ),
      );
    }
  }

  /// 백그라운드에서 현재 위치를 업데이트하는 메서드
  Future<void> _updateCurrentLocationInBackground() async {
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission || !mounted) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // 빠른 응답을 위해 medium 사용
        timeLimit: const Duration(seconds: 5),
      );
      
      if (!mounted) return;
      
      final locationProvider = context.read<LocationProvider>();
      // 위치가 크게 변경되었을 때만 업데이트 (100m 이상)
      if (locationProvider.currentLatitude != null && 
          locationProvider.currentLongitude != null) {
        final distance = Geolocator.distanceBetween(
          locationProvider.currentLatitude!,
          locationProvider.currentLongitude!,
          position.latitude,
          position.longitude,
        );
        
        // 100m 이상 이동했을 때만 업데이트
        if (distance < 100) return;
      }
      
      locationProvider.setCurrentLocation(
        position.latitude,
        position.longitude,
      );
      
      // 화면 리로드
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // 백그라운드 업데이트 실패는 무시 (사용자 경험에 영향 없음)
      debugPrint('백그라운드 위치 업데이트 실패: $e');
    }
  }

  void _selectSchool() {
    context.read<LocationProvider>().setSchoolLocation();
    // 화면 리로드
    if (mounted) {
      setState(() {});
    }
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

  /// 금오 마켓 스타일의 환영 화면을 생성하는 위젯
  ///
  /// Returns:
  /// - [Widget]: 환영 화면 위젯
  Widget _buildLoginScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // 금오 마켓 로고
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_grocery_store,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 40),

              // 환영 메시지
              const Text(
                '바로 마켓에 오신 것을\n환영합니다!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                '동네 이웃들과 안전하게 거래해보세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // 이메일 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailAuthPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.email_outlined, size: 22),
                  label: const Text(
                    '이메일로 시작하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Firestore 문서가 필터링 반경 내에 있는지 확인하는 헬퍼 함수
  ///
  /// Parameters:
  /// - [doc]: Firestore 문서 스냅샷 (QueryDocumentSnapshot)
  /// - [locationProvider]: LocationProvider 인스턴스
  ///
  /// Returns:
  /// - [bool]: 반경 내에 위치가 하나라도 있으면 true, 없으면 false
  bool _isProductInRadius(
    QueryDocumentSnapshot doc,
    LocationProvider locationProvider,
  ) {
    if (locationProvider.filterLatitude == null ||
        locationProvider.filterLongitude == null) {
      return false;
    }
    final data = doc.data() as Map<String, dynamic>;
    return _isFirestoreDocWithinRadius(
      data,
      locationProvider.filterLatitude!,
      locationProvider.filterLongitude!,
      locationProvider.searchRadius,
    );
  }

  /// Firestore 문서가 필터링 반경 내에 있는지 확인하는 헬퍼 함수
  ///
  /// Parameters:
  /// - [data]: Firestore 문서 데이터 (Map<String, dynamic>)
  /// - [filterLat]: 필터링 기준 위도
  /// - [filterLng]: 필터링 기준 경도
  /// - [radius]: 검색 반경 (미터 단위)
  ///
  /// Returns:
  /// - [bool]: 반경 내에 위치가 하나라도 있으면 true, 없으면 false
  bool _isFirestoreDocWithinRadius(
    Map<String, dynamic> data,
    double filterLat,
    double filterLng,
    double radius,
  ) {
    final location = data['location'] as GeoPoint?;
    final meetLocations = data['meetLocations'] as List?;

    // meetLocations가 있으면 모든 위치를 확인
    if (meetLocations != null && meetLocations.isNotEmpty) {
      for (final loc in meetLocations) {
        GeoPoint? geoPoint;
        if (loc is GeoPoint) {
          geoPoint = loc;
        } else if (loc is Map) {
          final lat = loc['latitude'] as double?;
          final lng = loc['longitude'] as double?;
          if (lat != null && lng != null) {
            geoPoint = GeoPoint(lat, lng);
          }
        }

        if (geoPoint != null) {
          final distance = Geolocator.distanceBetween(
            filterLat,
            filterLng,
            geoPoint.latitude,
            geoPoint.longitude,
          );
          if (distance <= radius) {
            return true; // 하나라도 범위 내에 있으면 포함
          }
        }
      }
      return false; // 모든 위치가 범위 밖이면 제외
    }

    // meetLocations가 없으면 기본 location 확인
    if (location != null) {
      final distance = Geolocator.distanceBetween(
        filterLat,
        filterLng,
        location.latitude,
        location.longitude,
      );
      return distance <= radius;
    }

    return false; // 위치 정보가 없으면 제외
  }

  /// Listing 모델이 필터링 반경 내에 있는지 확인하는 헬퍼 함수
  ///
  /// Parameters:
  /// - [listing]: Listing 모델 인스턴스
  /// - [filterLat]: 필터링 기준 위도
  /// - [filterLng]: 필터링 기준 경도
  /// - [radius]: 검색 반경 (미터 단위)
  ///
  /// Returns:
  /// - [bool]: 반경 내에 위치가 하나라도 있으면 true, 없으면 false
  bool _isListingWithinRadius(
    Listing listing,
    double filterLat,
    double filterLng,
    double radius,
  ) {
    // meetLocations가 있으면 모든 위치를 확인
    if (listing.meetLocations.isNotEmpty) {
      for (final loc in listing.meetLocations) {
        final distance = Geolocator.distanceBetween(
          filterLat,
          filterLng,
          loc.latitude,
          loc.longitude,
        );
        if (distance <= radius) {
          return true; // 하나라도 범위 내에 있으면 포함
        }
      }
      return false; // 모든 위치가 범위 밖이면 제외
    }

    // meetLocations가 없으면 기본 location 확인
    final distance = Geolocator.distanceBetween(
      filterLat,
      filterLng,
      listing.location.latitude,
      listing.location.longitude,
    );
    return distance <= radius;
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

  /// 위치 필터링 정보를 표시하는 위젯
  Widget _buildLocationFilterInfo() {
    return Consumer2<LocationProvider, EmailAuthProvider>(
      builder: (context, locationProvider, emailAuthProvider, child) {
        if (!locationProvider.isLocationFilterEnabled) {
          return const SizedBox.shrink();
        }

        final viewerUid = emailAuthProvider.user?.uid;

        // Firebase 사용 시 StreamBuilder로 실시간 상품 개수 계산
        if (AppConfig.useFirebase) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final products = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _firestoreDocToProduct(doc.id, data, viewerUid);
              }).toList();

              // 위치 필터링이 활성화된 경우 meetLocations를 확인하여 필터링
              // 판매 완료 상품 제외
              var filteredCount = products.where((product) => product.status != ProductStatus.sold).length;
              if (locationProvider.isLocationFilterEnabled) {
                filteredCount = snapshot.data!.docs
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = Product.safeParseEnum(
                        ProductStatus.values,
                        data['status'],
                        ProductStatus.onSale,
                      );
                      return _isProductInRadius(doc, locationProvider) && status != ProductStatus.sold;
                    })
                    .length;
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
                        '주변 상품 $filteredCount개',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.teal[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

        // 로컬 모드
        var listings = LocalAppRepository.instance.getAllListings();
        
        var filteredCount = listings.length;
        if (locationProvider.filterLatitude != null &&
            locationProvider.filterLongitude != null) {
          filteredCount = listings.where((listing) {
            return _isListingWithinRadius(
              listing,
              locationProvider.filterLatitude!,
              locationProvider.filterLongitude!,
              locationProvider.searchRadius,
            );
          }).length;
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
                  '주변 상품 $filteredCount개',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 카테고리 필터 바를 생성하는 위젯
  Widget _buildCategoryFilter() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
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
      backgroundColor = isSelected ? Colors.teal : Colors.grey[100];
      textColor = isSelected ? Colors.white : Colors.black87;
      if (isSelected) {
        borderStyle = Border.all(color: Colors.teal, width: 1.5);
      } else {
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

  /// Firestore 문서를 Product로 변환
  /// Firestore 문서를 Product로 변환
  Product _firestoreDocToProduct(
      String docId,
      Map<String, dynamic> data,
      String? viewerUid,
      ) {
    final location = data['location'] as GeoPoint?;
    final region = data['region'] as Map<String, dynamic>?;
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    final likedUserIds = List<String>.from(data['likedUserIds'] ?? []);

    // 🔥 이미지 필드 통합: imageUrls가 우선, 없으면 images 사용
    final dynamic rawImages = data['imageUrls'] ?? data['images'] ?? [];
    final List<String> imageUrls = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : <String>[];

    return Product(
      id: docId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      imageUrls: imageUrls,
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
      groupBuy: Product.parseGroupBuyInfo(data['groupBuy']),
    );
  }


  /// 상품 목록을 생성하는 위젯
  Widget _buildProductList() {
    final viewerUid = context.read<EmailAuthProvider>().user?.uid;
    
    // LocationProvider 변경 감지를 위해 Consumer로 감싸기
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        // Firebase 사용 시 StreamBuilder로 실시간 업데이트
        if (AppConfig.useFirebase) {
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
                return const Center(
                  child: Text('등록된 상품이 없습니다.'),
                );
              }
              
              // 위치 필터링이 활성화된 경우 meetLocations를 확인하여 필터링
              var docs = snapshot.data!.docs;
              if (locationProvider.isLocationFilterEnabled) {
                docs = docs
                    .where((doc) => _isProductInRadius(doc, locationProvider))
                    .toList();
              }
              
              final products = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _firestoreDocToProduct(doc.id, data, viewerUid);
              }).where((product) => product.status != ProductStatus.sold).toList();
              
              return _buildProductGridView(products);
            },
          );
        }
        
        // 로컬 모드
        var listings = LocalAppRepository.instance.getAllListings();
        
        // 위치 필터링이 활성화된 경우 meetLocations를 확인하여 필터링
        if (locationProvider.isLocationFilterEnabled &&
            locationProvider.filterLatitude != null &&
            locationProvider.filterLongitude != null) {
          listings = listings.where((listing) {
            return _isListingWithinRadius(
              listing,
              locationProvider.filterLatitude!,
              locationProvider.filterLongitude!,
              locationProvider.searchRadius,
            );
          }).toList();
        }
        
        // 필터링된 listings를 Product로 변환
        final products = listings
            .map((listing) => LocalAppRepository.instance.getProductById(
                  listing.id,
                  viewerUid: viewerUid,
                ))
            .whereType<Product>()
            .where((product) => product.status != ProductStatus.sold)
            .toList();
        
        return _buildProductGridView(products);
      },
    );
  }
  
  /// Product 리스트를 GridView로 표시
  Widget _buildProductGridView(List<Product> products) {
    var allProducts = products.map((product) {
      // 같이사요 상품인 경우 만나는 위치(meetPlaceText)를 우선 표시
      // 그 외 상품은 상세 위치 정보가 있으면 우선 표시, 없으면 기본 위치 정보 표시
      String locationText;
      if (product.category == ProductCategory.groupBuy && product.groupBuy != null) {
        locationText = product.groupBuy!.meetPlaceText.isNotEmpty
            ? product.groupBuy!.meetPlaceText
            : product.location;
      } else {
        locationText = product.meetLocationDetail?.isNotEmpty == true
            ? product.meetLocationDetail!
            : product.location;
      }
      return {
        'title': product.title,
        'price': product.formattedPrice,
        'location': locationText,
        'image': product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
        'category': product.category,
        'product': product,
      };
    }).toList();

    // 위치 필터링 적용 (현재 위치 또는 학교 주변)
    // 주의: _buildProductGridView는 이미 필터링된 Product 리스트를 받으므로
    // 여기서는 추가 필터링을 하지 않습니다.
    // 위치 필터링은 _buildProductList에서 Firestore 문서 단계에서 수행됩니다.

    // 선택된 카테고리에 따라 필터링
    final filteredProducts = _selectedCategory == null
        ? allProducts
        : allProducts.where((product) {
            return product['category'] == _selectedCategory;
          }).toList();

    // 필터링된 상품이 없을 때
    if (filteredProducts.isEmpty) {
      final locationProvider = context.read<LocationProvider>();
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
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (locationProvider.isLocationFilterEnabled && _selectedCategory == null) ...[
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
            return InkWell(
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
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.teal.withValues(alpha: 0.1),
              highlightColor: Colors.teal.withValues(alpha: 0.05),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                        child: () {
                          final String? imagePath =
                          product['image'] as String?;

                          if (imagePath == null || imagePath.isEmpty) {
                            return const Icon(
                              Icons.image,
                              color: Colors.grey,
                            );
                          }

                          // 🔥 asset / network 구분
                          if (_isAssetImage(imagePath)) {
                            return Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                debugPrint(
                                    '❌ 홈 Asset 이미지 로드 실패: $imagePath');
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
                              frameBuilder: (
                                  context,
                                  child,
                                  frame,
                                  wasSynchronouslyLoaded,
                                  ) {
                                if (frame != null ||
                                    wasSynchronouslyLoaded) {
                                  debugPrint(
                                      '✅ 홈 Asset 이미지 로드 성공: $imagePath');
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
                            );
                          } else {
                            return Image.network(
                              imagePath,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                debugPrint(
                                    '❌ 홈 Network 이미지 로드 실패: $imagePath');
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
                            );
                          }
                        }(),
                      ),

                    ),
                    const SizedBox(width: 12),

                    // 상품 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['title']! as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // 같이사요 배지
                              if (productModel?.category == ProductCategory.groupBuy)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[500],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '같이사요',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
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
              color: Colors.black.withValues(alpha: 0.25),
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
                color: iconColor.withValues(alpha: 0.12),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('동네 생활'),
      ),
      body: Container(child: const Text('동네생활 페이지')),
    );
  }
}
