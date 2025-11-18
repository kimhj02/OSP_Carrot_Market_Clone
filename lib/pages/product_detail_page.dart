/// 상품 상세 페이지
///
/// 당근 마켓의 상품 상세 정보를 표시하는 화면입니다.
/// 상품의 모든 정보와 판매자 정보, 채팅하기 등의 기능을 제공합니다.
///
/// 주요 기능:
/// - 상품 이미지 표시 (여러 장일 경우 슬라이더)
/// - 상품 상세 정보 표시
/// - 판매자 정보 표시 및 판매자 프로필 페이지 이동
/// - 채팅하기 버튼 (채팅방 생성 또는 기존 채팅방으로 이동)
/// - 찜하기 기능
/// - 위치 정보 및 거리 표시
/// - 지도에서 위치 보기
/// - 상품 공유 기능
/// - 상품 삭제 기능 (판매자만 가능)
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/pages/chat_page.dart';
import 'package:flutter_sandbox/pages/map_page.dart';
import 'package:flutter_sandbox/pages/seller_profile_page.dart';
import 'package:flutter_sandbox/pages/product_edit_page.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/providers/location_provider.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;

enum _ProductMoreAction {
  edit,
  delete,
  changeStatus,
}

/// 상품 상세 정보를 표시하는 페이지
class ProductDetailPage extends StatefulWidget {
  /// 표시할 상품 정보
  final Product product;

  const ProductDetailPage({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {

  /// 기본 메시지
  static const String _defaultMessage = '안녕하세요. 관심 있어서 문의드려요.';

  /// 입력창 컨트롤러
  final TextEditingController _messageController = TextEditingController();


  int _currentImageIndex = 0;   /// 현재 이미지 인덱스 (여러 이미지인 경우)
  bool _isLiked = false;      /// 찜하기 상태
  bool _isSending = false;  /// 메시지 전송 상태
  bool _hasText = false;  /// 입력창의 텍스트 여부
  bool _isDeleting = false; /// 상품 삭제 진행 상태

  @override
  void initState() {
    super.initState();

    /// 초기값 설정
    _messageController.text = _defaultMessage;
    _hasText = true;
    _isLiked = widget.product.isLiked;

    /// 입력창 상태 관리
    _messageController.addListener(() {
      setState(() {
        _hasText = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// 이미지 URL이 asset 경로인지 확인하는 메서드
  bool _isAssetImage(String imageUrl) {
    return imageUrl.contains('dummy_data') ||
        imageUrl.startsWith('lib/') ||
        imageUrl.startsWith('assets/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () => _shareProduct(),
          ),
          PopupMenuButton<_ProductMoreAction>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            enabled: !_isDeleting,
            onSelected: (action) {
              switch (action) {
                case _ProductMoreAction.edit:
                  _navigateToEditPage();
                  break;
                case _ProductMoreAction.delete:
                  _confirmDeleteProduct();
                  break;
                case _ProductMoreAction.changeStatus:
                  _showStatusChangeDialog();
                  break;
              }
            },
            itemBuilder: (context) {
              final entries = <PopupMenuEntry<_ProductMoreAction>>[];
              if (_canDeleteProduct) {
                entries.add(
                  PopupMenuItem<_ProductMoreAction>(
                    value: _ProductMoreAction.edit,
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined, color: Colors.teal),
                        SizedBox(width: 12),
                        Text('상품 수정'),
                      ],
                    ),
                  ),
                );
                entries.add(
                  PopupMenuItem<_ProductMoreAction>(
                    value: _ProductMoreAction.changeStatus,
                    child: const Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.orange),
                        SizedBox(width: 12),
                        Text('상태 변경'),
                      ],
                    ),
                  ),
                );
                entries.add(
                  const PopupMenuDivider(),
                );
                entries.add(
                  PopupMenuItem<_ProductMoreAction>(
                    value: _ProductMoreAction.delete,
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text('상품 삭제'),
                      ],
                    ),
                  ),
                );
              } else {
                entries.add(
                  const PopupMenuItem<_ProductMoreAction>(
                    enabled: false,
                    child: Text('수정 권한이 없습니다'),
                  ),
                );
              }
              return entries;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지 섹션
            _buildImageSection(),

            // 상품 정보 섹션
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 판매자 정보
                  _buildSellerInfo(),
                  const Divider(height: 32),

                  // 상품 제목
                  Text(
                    widget.product.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 카테고리와 상태
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.product.categoryText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.product.status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.product.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(widget.product.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 가격
                  Text(
                    widget.product.formattedPrice,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 조회수와 찜 수
                  Row(
                    children: [
                      Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '조회 ${widget.product.viewCount}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '찜 ${widget.product.likeCount}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // 상품 설명
                  const Text(
                    '상품 설명',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 위치 정보
                  Consumer<LocationProvider>(
                    builder: (context, locationProvider, child) {
                      String distanceText = '';
                      if (locationProvider.isLocationFilterEnabled &&
                          locationProvider.filterLatitude != null &&
                          locationProvider.filterLongitude != null &&
                          widget.product.x != 0.0 &&
                          widget.product.y != 0.0) {
                        final distance = Geolocator.distanceBetween(
                          locationProvider.filterLatitude!,
                          locationProvider.filterLongitude!,
                          widget.product.x,
                          widget.product.y,
                        );
                        if (distance >= 1000) {
                          distanceText = ' • ${(distance / 1000).toStringAsFixed(1)}km';
                        } else {
                          distanceText = ' • ${distance.toInt()}m';
                        }
                      }
                      
                      return InkWell(
                        onTap: () {
                          // 지도에서 위치 보기
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MapScreen(),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 20, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.product.location}$distanceText',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateTime.now().difference(widget.product.createdAt).inDays}일 전',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// 상품 이미지 섹션을 생성하는 위젯
  Widget _buildImageSection() {
    final images = widget.product.imageUrls;
    if (images.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // 이미지 페이지뷰
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final imagePath = images[index];
              return _isAssetImage(imagePath)
                  ? Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('상세 페이지 이미지 로드 실패: $imagePath');
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              size: 64, color: Colors.grey),
                        );
                      },
                    )
                  : Image.network(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              size: 64, color: Colors.grey),
                        );
                      },
                    );
            },
          ),

          // 이미지 인덱스 인디케이터
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 판매자 정보를 생성하는 위젯
  Widget _buildSellerInfo() {
    return Row(
      children: [
        // 판매자 프로필 이미지
        CircleAvatar(
          radius: 25,
          backgroundImage: widget.product.sellerProfileImageUrl != null
              ? NetworkImage(widget.product.sellerProfileImageUrl!)
              : null,
          child: widget.product.sellerProfileImageUrl == null
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        // 판매자 정보
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.sellerNickname,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.product.location,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // 판매자 프로필 보기 버튼
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SellerProfilePage(
                  sellerId: widget.product.sellerId,
                  sellerNickname: widget.product.sellerNickname,
                  sellerProfileImageUrl: widget.product.sellerProfileImageUrl,
                ),
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
          child: const Text('프로필 보기'),
        ),
      ],
    );
  }

  /// 하단 바를 생성하는 위젯
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [

            // 찜하기 버튼
            IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.grey,
              ),
              onPressed: _toggleLike,
            ),
            const SizedBox(width: 8),

            // 메시지 입력창
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _defaultMessage,
                  hintStyle: TextStyle(
                    color: Colors.grey[300],),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: 1,
                enabled: !_isSending,

                ///  클릭 시 전체 선택
                onTap: () {
                  _messageController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _messageController.text.length,
                  );
                },

                /// 엔터 시 전송
                onSubmitted: (_) {
                  if (widget.product.isAvailable && !_isSending && _hasText) {
                    _sendFirstMessage();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // 보내기 버튼
            ElevatedButton(
              onPressed: (widget.product.isAvailable && !_isSending && _hasText)
                  ? _sendFirstMessage  /// 메시지 전송 함수
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),

              ///버튼 내용
              child: _isSending /// 전송 중일 때 로딩 표시
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                widget.product.isAvailable ? '보내기' : widget.product.statusText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상품에 대한 구매자의 첫 채팅 관리
  Future<void> _sendFirstMessage() async {
    ///  메시지 검증
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('메시지를 입력해주세요');
      return;
    }

    setState(() => _isSending = true);

    try {
      /// 2. 현재 사용자 확인
      final authProvider = context.read<EmailAuthProvider>();
      final appUser = authProvider.user;
      if (appUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final buyerId = appUser.uid;
      final sellerId = widget.product.sellerId;

      /// 3. 본인 상품 체크
      if (buyerId == sellerId) {
        throw Exception('본인의 상품에는 채팅할 수 없습니다');
      }

      String chatRoomId;
      if (AppConfig.useFirebase) {
        final existingRoomId = await _findExistingChatRoom(
          buyerId,
          sellerId,
          widget.product.id,
        );
        chatRoomId = existingRoomId ?? await _createChatRoom(buyerId, sellerId);
        await _sendMessage(chatRoomId, buyerId, message);
      } else {
        final repo = LocalAppRepository.instance;
        chatRoomId = await repo.ensureChatRoom(
          listingId: widget.product.id,
          buyerUid: buyerId,
        );
        await repo.sendMessage(
          roomId: chatRoomId,
          senderUid: buyerId,
          text: message,
        );
        await repo.markMessagesAsRead(roomId: chatRoomId, userId: buyerId);
      }

      // 7. 채팅 페이지로 이동
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            chatRoomId: chatRoomId,
            opponentName: widget.product.sellerNickname,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('오류: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// 기존 채팅방 찾기
  Future<String?> _findExistingChatRoom(String buyerId, String sellerId,
                                        String productId,) async {

    final querySnapshot = await FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participants', arrayContains: buyerId)
        .where('productId', isEqualTo: productId)
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);

      if (participants.contains(sellerId)) {
        return doc.id;
      }
    }
    return null;
  }

  /// 새 채팅방 생성
  Future<String> _createChatRoom(String buyerId, String sellerId) async {

    /// 구매자 정보 가져오기
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(buyerId)
        .get();

    final buyerName = userDoc.exists
        ? (userDoc.data()?['name'] ?? '구매자')
        : '구매자';

    /// 채팅방 데이터 생성
    final chatRoomData = {
      'participants': [buyerId, sellerId],
      'participantNames': {
        buyerId: buyerName,
        sellerId: widget.product.sellerNickname,
      },

      'productId': widget.product.id,
      'productTitle': widget.product.title,
      'productImage': widget.product.imageUrls.isNotEmpty
          ? widget.product.imageUrls.first
          : '',
      'productPrice': widget.product.price,

      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),

      'unreadCount': {
        buyerId: 0,
        sellerId: 0,
      },

      'createdAt': FieldValue.serverTimestamp(),
      'type': 'purchase',
    };

    /// Firestore에 저장
    final docRef = await FirebaseFirestore.instance
                  .collection('chatRooms')
                  .add(chatRoomData);

    return docRef.id;
  }

  /// 메시지 전송
  Future<void> _sendMessage(String chatRoomId, String senderId, String message,) async {
    // 메시지 추가
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    /// 채팅방 정보 업데이트
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(chatRoomId)
        .update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.${widget.product.sellerId}': FieldValue.increment(1),
    });
  }


  /// 상품 상태에 따른 색상을 반환하는 메서드
  Color _getStatusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.onSale:
        return Colors.teal;
      case ProductStatus.reserved:
        return Colors.orange;
      case ProductStatus.sold:
        return Colors.grey;
    }
  }

  /// 수정 페이지로 이동
  Future<void> _navigateToEditPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductEditPage(product: widget.product),
      ),
    );
    
    if (result == true && mounted) {
      // 수정 완료 후 상품 정보 새로고침
      Navigator.pop(context, true);
    }
  }

  /// 상태 변경 다이얼로그 표시
  void _showStatusChangeDialog() {
    final currentStatus = widget.product.status;
    final availableStatuses = <ProductStatus>[];
    
    // 현재 상태에 따라 변경 가능한 상태 목록 생성
    switch (currentStatus) {
      case ProductStatus.onSale:
        availableStatuses.addAll([ProductStatus.reserved, ProductStatus.sold]);
        break;
      case ProductStatus.reserved:
        availableStatuses.addAll([ProductStatus.onSale, ProductStatus.sold]);
        break;
      case ProductStatus.sold:
        availableStatuses.add(ProductStatus.onSale);
        break;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('상품 상태 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableStatuses.map((status) {
              return ListTile(
                title: Text(_getStatusText(status)),
                onTap: () {
                  Navigator.pop(context);
                  _changeProductStatus(status);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  /// 상태 텍스트 반환
  String _getStatusText(ProductStatus status) {
    switch (status) {
      case ProductStatus.onSale:
        return '판매중';
      case ProductStatus.reserved:
        return '예약중';
      case ProductStatus.sold:
        return '판매완료';
    }
  }

  /// 상품 상태 변경
  Future<void> _changeProductStatus(ProductStatus newStatus) async {
    try {
      ListingStatus listingStatus;
      switch (newStatus) {
        case ProductStatus.onSale:
          listingStatus = ListingStatus.onSale;
          break;
        case ProductStatus.reserved:
          listingStatus = ListingStatus.reserved;
          break;
        case ProductStatus.sold:
          listingStatus = ListingStatus.sold;
          break;
      }

      if (AppConfig.useFirebase) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .update({'status': listingStatus.index});
      } else {
        await LocalAppRepository.instance.updateListing(
          listingId: widget.product.id,
          status: listingStatus,
        );
      }

      if (mounted) {
        _showSnackBar('상품 상태가 변경되었습니다');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('상태 변경에 실패했습니다: $e');
      }
    }
  }

  /// 스낵바 표시
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  /// 상품 공유 기능
  Future<void> _shareProduct() async {
    try {
      final shareText = '${widget.product.title}\n'
          '${widget.product.formattedPrice}\n'
          '${widget.product.description}\n'
          '위치: ${widget.product.location}';
      
      await Share.share(
        shareText,
        subject: widget.product.title,
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('공유 중 오류가 발생했습니다');
      }
    }
  }

  void _toggleLike() {
    final authProvider = context.read<EmailAuthProvider>();
    final uid = authProvider.user?.uid;
    if (!AppConfig.useFirebase && uid != null) {
      LocalAppRepository.instance.toggleFavorite(widget.product.id, uid);
    }
    setState(() {
      _isLiked = !_isLiked;
    });
    _showSnackBar(_isLiked ? '찜 목록에 추가했습니다' : '찜을 취소했습니다');
  }

  bool get _canDeleteProduct {
    if (AppConfig.useFirebase) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      return currentUser.uid == widget.product.sellerId;
    }
    final authProvider = context.read<EmailAuthProvider>();
    final uid = authProvider.user?.uid;
    if (uid == null) return false;
    return uid == widget.product.sellerId;
  }

  Future<void> _confirmDeleteProduct() async {
    if (!_canDeleteProduct) {
      _showSnackBar('삭제 권한이 없습니다');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('상품 삭제'),
          content: const Text('해당 상품을 정말 삭제하시겠습니까? 삭제 후에는 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _deleteProduct();
  }

  Future<void> _deleteProduct() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      if (AppConfig.useFirebase) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .delete();
      } else {
        await LocalAppRepository.instance.deleteListing(widget.product.id);
      }

      if (!mounted) return;
      _showSnackBar('상품을 삭제했습니다');
      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      final message = e.message ?? '알 수 없는 오류가 발생했습니다';
      if (kDebugMode) {
        debugPrint('❌ 상품 삭제 실패: $message');
      }
      if (mounted) {
        _showSnackBar('상품 삭제에 실패했습니다: $message');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 상품 삭제 실패: $e');
      }
      if (mounted) {
        _showSnackBar('상품 삭제에 실패했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

}





