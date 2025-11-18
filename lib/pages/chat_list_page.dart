/// 채팅 목록 페이지
///
/// 사용자의 모든 채팅방 목록을 보여주는 페이지입니다.
/// Firebase Firestore를 사용하여 실시간으로 채팅방 목록을 표시합니다.
///
/// 주요 기능:
/// - 실시간 채팅방 목록 표시
/// - 필터링 (전체, 판매, 구매, 안 읽은 채팅방)
/// - 읽지 않은 메시지 카운트 표시
/// - 마지막 메시지 시간 표시
///
/// @author Flutter Sandbox
/// @version 2.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sandbox/pages/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';

/// 채팅방 필터 타입
enum ChatFilter {
  all,      // 전체
  selling,  // 판매
  buying,   // 구매
  unread,   // 안 읽은 채팅방
}

/// 채팅방 정렬 방식
enum ChatSortType {
  latest,   // 최신순
  unread,   // 안 읽은 순
  name,     // 이름순
}

/// 채팅방 모델
class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String productId;
  final String productTitle;
  final String productImage;
  final int productPrice;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final String type;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.productId,
    required this.productTitle,
    required this.productImage,
    required this.productPrice,
    required this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    required this.type,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ChatRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      productId: data['productId'] ?? '',
      productTitle: data['productTitle'] ?? '',
      productImage: data['productImage'] ?? '',
      productPrice: data['productPrice'] ?? 0,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, value as int),
        ) ?? {},
      ),
      type: data['type'] ?? 'purchase',
    );
  }

  /// 상대방 이름 가져오기
  String getOpponentName(String currentUserId) {
    if (type == 'groupBuy') {
      // 그룹 채팅: 상품 제목 표시
      return productTitle.isNotEmpty ? productTitle : '같이사요 채팅';
    }
    
    final opponentId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );
    return participantNames[opponentId] ?? '알 수 없음';
  }

  /// 내 읽지 않은 메시지 수
  int getMyUnreadCount(String currentUserId) {
    return unreadCount[currentUserId] ?? 0;
  }

  /// 구매 채팅방인지 (내가 구매자)
  bool isBuyingChat(String currentUserId) {
    return type == 'purchase' && participants.indexOf(currentUserId) == 0;
  }

  /// 판매 채팅방인지 (내가 판매자)
  bool isSellingChat(String currentUserId) {
    return type == 'purchase' && participants.indexOf(currentUserId) == 1;
  }
}

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  ChatFilter _selectedFilter = ChatFilter.all;
  ChatSortType _sortType = ChatSortType.latest;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<EmailAuthProvider>().user?.uid;
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('채팅'),
        ),
        body: const Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
        children: [
          // 헤더와 필터 버튼들
          _buildFilterButtons(),

          // 채팅 리스트
          Expanded(
            child: Container(
              color: Colors.white,
              child: _buildChatList(currentUserId),
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// 필터 버튼 영역
  Widget _buildFilterButtons() {
    return Column(
      children: [
        // 헤더 (제목 + 액션 버튼)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Text(
                '채팅',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.black87, size: 28),
                iconSize: 28,
                onPressed: () => _showSortDialog(),
              ),
              IconButton(
                icon: Icon(
                  _notificationsEnabled
                      ? Icons.notifications
                      : Icons.notifications_off,
                  color: Colors.black87,
                  size: 28,
                ),
                iconSize: 28,
                onPressed: () => _showNotificationSettings(),
              ),
            ],
          ),
        ),
        // 필터 버튼들
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('전체', ChatFilter.all),
                const SizedBox(width: 8),
                _buildFilterButton('판매', ChatFilter.selling),
                const SizedBox(width: 8),
                _buildFilterButton('구매', ChatFilter.buying),
                const SizedBox(width: 8),
                _buildFilterButton('안 읽은 채팅방', ChatFilter.unread),
              ],
            ),
          ),
        ),
        // 구분선
        Container(
          height: 1,
          color: Colors.grey[200],
        ),
      ],
    );
  }

  /// 필터 버튼 위젯
  Widget _buildFilterButton(String label, ChatFilter filter) {
    final isSelected = _selectedFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 채팅 리스트 빌드
  Widget _buildChatList(String currentUserId) {
    if (AppConfig.useFirebase) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('오류가 발생했습니다\n${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chatRooms = snapshot.data?.docs
                  .map((doc) => ChatRoom.fromFirestore(doc))
                  .toList() ??
              [];

          var filteredChatRooms = _applyFilter(chatRooms, currentUserId);
          filteredChatRooms = _applySort(filteredChatRooms, currentUserId);

          if (filteredChatRooms.isEmpty) {
            return _buildEmptyState();
          }

          return _buildChatRoomList(filteredChatRooms, currentUserId);
        },
      );
    } else {
      return StreamBuilder<List<AppChatRoom>>(
        stream: LocalAppRepository.instance.watchChatRooms(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('오류가 발생했습니다\n${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snapshot.data ?? [];
          final converted = rooms
              .map((room) => _convertLocalRoom(room))
              .toList(growable: false);
          var filtered = _applyFilter(converted, currentUserId);
          filtered = _applySort(filtered, currentUserId);
          if (filtered.isEmpty) {
            return _buildEmptyState();
          }
          return _buildChatRoomList(filtered, currentUserId);
        },
      );
    }
  }

  Widget _buildChatRoomList(List<ChatRoom> chatRooms, String currentUserId) {
    return ListView.separated(
      itemCount: chatRooms.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 80,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        final chatRoom = chatRooms[index];
        return _ChatListItem(
          chatRoom: chatRoom,
          currentUserId: currentUserId,
          onTap: () {
            _navigateToChatPage(chatRoom, currentUserId);
          },
        );
      },
    );
  }

  /// 필터 적용
  List<ChatRoom> _applyFilter(List<ChatRoom> chatRooms, String currentUserId) {
    switch (_selectedFilter) {
      case ChatFilter.all:
        return chatRooms;

      case ChatFilter.selling:
        return chatRooms.where((room) =>
            room.isSellingChat(currentUserId)
        ).toList();

      case ChatFilter.buying:
        return chatRooms.where((room) =>
            room.isBuyingChat(currentUserId)
        ).toList();

      case ChatFilter.unread:
        return chatRooms.where((room) =>
        room.getMyUnreadCount(currentUserId) > 0
        ).toList();
    }
  }

  /// 정렬 적용
  List<ChatRoom> _applySort(List<ChatRoom> chatRooms, String currentUserId) {
    final sorted = List<ChatRoom>.from(chatRooms);
    
    switch (_sortType) {
      case ChatSortType.latest:
        sorted.sort((a, b) {
          final timeA = a.lastMessageTime ?? DateTime(1970);
          final timeB = b.lastMessageTime ?? DateTime(1970);
          return timeB.compareTo(timeA);
        });
        break;
      case ChatSortType.unread:
        sorted.sort((a, b) {
          final unreadA = a.getMyUnreadCount(currentUserId);
          final unreadB = b.getMyUnreadCount(currentUserId);
          if (unreadA != unreadB) {
            return unreadB.compareTo(unreadA);
          }
          final timeA = a.lastMessageTime ?? DateTime(1970);
          final timeB = b.lastMessageTime ?? DateTime(1970);
          return timeB.compareTo(timeA);
        });
        break;
      case ChatSortType.name:
        sorted.sort((a, b) {
          final nameA = a.getOpponentName(currentUserId);
          final nameB = b.getOpponentName(currentUserId);
          return nameA.compareTo(nameB);
        });
        break;
    }
    
    return sorted;
  }

  /// 정렬 다이얼로그 표시
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('정렬 방식'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ChatSortType.values.map((sortType) {
              return RadioListTile<ChatSortType>(
                title: Text(_getSortTypeName(sortType)),
                value: sortType,
                groupValue: _sortType,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortType = value;
                    });
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// 정렬 타입 이름 반환
  String _getSortTypeName(ChatSortType sortType) {
    switch (sortType) {
      case ChatSortType.latest:
        return '최신순';
      case ChatSortType.unread:
        return '안 읽은 순';
      case ChatSortType.name:
        return '이름순';
    }
  }

  /// 알림 설정 다이얼로그 표시
  void _showNotificationSettings() {
    final currentUserId = context.read<EmailAuthProvider>().user?.uid;
    if (currentUserId == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('알림 설정'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SwitchListTile(
                title: const Text('채팅 알림'),
                subtitle: const Text('새 메시지가 도착하면 알림을 받습니다'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  this.setState(() {
                    _notificationsEnabled = value;
                  });
                  
                  // Firestore에 알림 설정 저장
                  if (AppConfig.useFirebase) {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .update({
                      'notificationsEnabled': value,
                    }).catchError((e) {
                      debugPrint('알림 설정 저장 실패: $e');
                    });
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  ChatRoom _convertLocalRoom(AppChatRoom room) {
    final listing = LocalAppRepository.instance.getListing(room.listingId);
    return ChatRoom(
      id: room.id,
      participants: room.participants,
      participantNames: Map<String, String>.from(room.participantNames),
      productId: room.listingId,
      productTitle: room.listingTitle,
      productImage: room.listingImage ?? '',
      productPrice: listing?.price ?? 0,
      lastMessage: room.lastMessage,
      lastMessageTime: room.lastMessageTime,
      unreadCount: Map<String, int>.from(room.unread),
      type: room.listingType == ListingType.groupBuy ? 'group' : 'purchase',
    );
  }

  /// 채팅 페이지로 이동
  void _navigateToChatPage(ChatRoom chatRoom, String currentUserId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatRoomId: chatRoom.id,  // ✅ chatRoomId 전달
          opponentName: chatRoom.getOpponentName(currentUserId),
        ),
      ),
    ).then((_) {
      // 채팅 페이지에서 돌아왔을 때 목록 새로고침
      // StreamBuilder가 자동으로 업데이트하므로 별도 처리 불필요
    });
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    String message = '채팅방이 없어요.';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 채팅 리스트  위젯
class _ChatListItem extends StatelessWidget {
  final ChatRoom chatRoom;
  final String currentUserId;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.chatRoom,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opponentName = chatRoom.getOpponentName(currentUserId);
    final unreadCount = chatRoom.getMyUnreadCount(currentUserId);
    final timeText = _formatTime(chatRoom.lastMessageTime);

    return InkWell(
      onTap: onTap,
      splashColor: Colors.teal.withOpacity(0.1),
      highlightColor: Colors.teal.withOpacity(0.05),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 상품 이미지
            _buildProductImage(),
            const SizedBox(width: 12),

            // 채팅 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상대방 이름과 시간
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          opponentName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 상품 제목
                  Text(
                    chatRoom.productTitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),

                  // 마지막 메시지와 읽지 않은 수
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatRoom.lastMessage.isEmpty
                              ? '새로운 채팅방입니다'
                              : chatRoom.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey[700],
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상품 이미지 위젯
  Widget _buildProductImage() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: chatRoom.productImage.isNotEmpty
            ? (chatRoom.productImage.startsWith('http')
            ? Image.network(
          chatRoom.productImage,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorImage();
          },
        )
            : Image.asset(
          chatRoom.productImage,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorImage();
          },
        ))
            : _buildErrorImage(),
      ),
    );
  }

  /// 에러 이미지 위젯
  Widget _buildErrorImage() {
    return Icon(
      Icons.shopping_bag,
      color: Colors.grey[400],
      size: 28,
    );
  }

  /// 시간 포맷팅
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      // 오늘: 시간 표시 (오후 2:30)
      return DateFormat('a h:mm', 'ko_KR').format(dateTime);
    } else if (difference == 1) {
      // 어제
      return '어제';
    } else if (difference < 7) {
      // 일주일 이내: 요일
      return DateFormat('E요일', 'ko_KR').format(dateTime);
    } else if (dateTime.year == now.year) {
      // 올해: 월/일
      return DateFormat('M월 d일').format(dateTime);
    } else {
      // 작년 이전: 년/월/일
      return DateFormat('yyyy.M.d').format(dateTime);
    }
  }
}