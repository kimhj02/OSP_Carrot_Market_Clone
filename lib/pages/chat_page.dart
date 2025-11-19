/// 1:1 채팅 페이지
///
/// Firebase Firestore를 사용한 실시간 채팅 기능을 제공합니다.
///
/// 주요 기능:
/// - 실시간 메시지 송수신
/// - 메시지 읽음 처리
/// - 자동 스크롤
/// - 시간 표시
///
/// @author Flutter Sandbox
/// @version 2.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sandbox/config/app_config.dart';
import 'package:flutter_sandbox/providers/email_auth_provider.dart';
import 'package:flutter_sandbox/providers/location_provider.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/services/fcm_service.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';

/// Firestore 컬렉션 및 필드 상수
class ChatConstants {
  static const String chatRoomsCollection = 'chatRooms';
  static const String messagesCollection = 'messages';
  static const String lastMessage = 'lastMessage';
  static const String lastMessageTime = 'lastMessageTime';
  static const String unreadCount = 'unreadCount';
}

/// 메시지 모델
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final Set<String> readBy; // 읽은 사람들의 ID 집합

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isRead,
    required this.readBy,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // readBy 필드가 있으면 사용, 없으면 isRead 기반으로 추론
    Set<String> readBySet;
    if (data['readBy'] != null) {
      readBySet = Set<String>.from(data['readBy'] as List? ?? []);
    } else {
      // 기존 isRead 필드가 있으면 senderId를 readBy에 추가 (하위 호환성)
      readBySet = (data['isRead'] as bool? ?? false) 
          ? {data['senderId'] as String? ?? ''}
          : <String>{};
    }
    
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      readBy: readBySet,
    );
  }
  
  /// 읽지 않은 사람 수를 계산 (보낸 사람 제외)
  int getUnreadCount(List<String> participants, String senderId) {
    // 보낸 사람을 제외한 참여자 중 읽지 않은 사람 수
    final otherParticipants = participants.where((id) => id != senderId).toList();
    final unreadCount = otherParticipants.where((id) => !readBy.contains(id)).length;
    return unreadCount;
  }
  
  /// 1대1 채팅에서 상대방이 읽었는지 확인
  bool isReadByOpponent(String opponentId) {
    return readBy.contains(opponentId);
  }
}

/// 채팅 페이지
class ChatPage extends StatefulWidget {
  final String chatRoomId;
  final String opponentName;

  const ChatPage({
    super.key,
    required this.chatRoomId,
    required this.opponentName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  String? _currentUserId;
  DateTime? _lastMarkAsReadTime; // 마지막 읽음 처리 시간
  bool _hasMarkedAsRead = false; // 읽음 처리 여부 플래그

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<EmailAuthProvider>().user?.uid;
    if (uid != _currentUserId) {
      setState(() {
        _currentUserId = uid;
        _hasMarkedAsRead = false; // 사용자 변경 시 플래그 리셋
      });
    }
    
    // 채팅 페이지에 처음 들어왔을 때 읽음 처리
    if (_currentUserId != null && !_hasMarkedAsRead) {
      _hasMarkedAsRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markMessagesAsRead();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 메시지를 읽음으로 표시
  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null) return;

    // 중복 호출 방지: 1초 이내에 다시 호출되면 무시
    final now = DateTime.now();
    if (_lastMarkAsReadTime != null &&
        now.difference(_lastMarkAsReadTime!).inSeconds < 1) {
      return;
    }
    _lastMarkAsReadTime = now;

    if (AppConfig.useFirebase) {
      try {
        debugPrint('📖 읽음 처리 시작: chatRoomId=${widget.chatRoomId}, userId=$_currentUserId');

        // 읽지 않은 메시지 찾기 (인덱스 오류 방지를 위해 senderId 조건만 사용)
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .collection(ChatConstants.messagesCollection)
            .where('senderId', isNotEqualTo: _currentUserId)
            .get();

        // 클라이언트 측에서 읽지 않은 메시지만 필터링 (readBy에 현재 사용자가 없는 메시지)
        final unreadMessages = messagesSnapshot.docs.where((doc) {
          final data = doc.data();
          final readBy = List<String>.from(data['readBy'] ?? []);
          return !readBy.contains(_currentUserId);
        }).toList();

        debugPrint('📖 읽지 않은 메시지 수: ${unreadMessages.length}');

        final batch = FirebaseFirestore.instance.batch();

        // 읽지 않은 메시지를 읽음으로 표시 (readBy에 현재 사용자 추가)
        for (var doc in unreadMessages) {
          final data = doc.data();
          final readBy = List<String>.from(data['readBy'] ?? []);
          if (!readBy.contains(_currentUserId)) {
            readBy.add(_currentUserId!);
            batch.update(doc.reference, {
              'readBy': readBy,
              'isRead': readBy.length > 0, // 하위 호환성을 위해 유지
            });
          }
        }

        if (unreadMessages.isNotEmpty) {
          await batch.commit();
          debugPrint('✅ 메시지 읽음 처리 완료: ${unreadMessages.length}개');
        }

        // unreadCount를 0으로 업데이트 (중첩 필드 업데이트)
        final chatRoomRef = FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId);
        
        // 현재 unreadCount Map 가져오기
        final chatRoomDoc = await chatRoomRef.get();
        if (chatRoomDoc.exists) {
          final currentUnreadCount = chatRoomDoc.data()?['unreadCount'] as Map<String, dynamic>? ?? {};
          final updatedUnreadCount = Map<String, dynamic>.from(currentUnreadCount);
          updatedUnreadCount[_currentUserId!] = 0;
          
          await chatRoomRef.update({
            'unreadCount': updatedUnreadCount,
          });
          
          debugPrint('✅ unreadCount 업데이트 완료: ${_currentUserId} -> 0');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ 메시지 읽음 처리 실패: $e');
        debugPrint('❌ StackTrace: $stackTrace');
      }
    } else {
      await LocalAppRepository.instance.markMessagesAsRead(
        roomId: widget.chatRoomId,
        userId: _currentUserId!,
      );
    }
  }

  /// 위치 정보 메시지 전송
  Future<void> _sendLocationMessage() async {
    if (_isSending || _currentUserId == null) return;

    try {
      setState(() => _isSending = true);

      final locationProvider = context.read<LocationProvider>();
      String locationMessage = '위치 정보를 공유합니다';
      
      if (locationProvider.isLocationFilterEnabled &&
          locationProvider.filterLatitude != null &&
          locationProvider.filterLongitude != null) {
        final latitude = locationProvider.filterLatitude!;
        final longitude = locationProvider.filterLongitude!;
        locationMessage = '위치: 위도 $latitude, 경도 $longitude\n지도에서 확인하기: https://www.google.com/maps?q=$latitude,$longitude';
      } else {
        // 현재 위치 가져오기
        final hasPermission = await _checkLocationPermission();
        if (hasPermission) {
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            locationMessage = '위치: 위도 ${position.latitude}, 경도 ${position.longitude}\n지도에서 확인하기: https://www.google.com/maps?q=${position.latitude},${position.longitude}';
          } catch (e) {
            _showSnackBar('위치 정보를 가져올 수 없습니다');
            return;
          }
        } else {
          _showSnackBar('위치 권한이 필요합니다');
          return;
        }
      }

      if (AppConfig.useFirebase) {
        await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .collection(ChatConstants.messagesCollection)
            .add({
          'senderId': _currentUserId,
          'text': locationMessage,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'readBy': [_currentUserId], // 보낸 사람은 자동으로 읽은 것으로 처리
        });
      } else {
        await LocalAppRepository.instance.sendMessage(
          roomId: widget.chatRoomId,
          text: locationMessage,
          senderUid: _currentUserId!,
        );
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('위치 메시지 전송 실패: $e');
      _showSnackBar('위치 정보 전송에 실패했습니다');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// 위치 권한 확인
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 메시지 전송
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isSending || _currentUserId == null) {
      return;
    }

    setState(() => _isSending = true);

    try {
      if (AppConfig.useFirebase) {
        final chatRoomDoc = await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .get();

        if (!chatRoomDoc.exists) {
          throw Exception('채팅방을 찾을 수 없습니다');
        }

        final participants = List<String>.from(
            chatRoomDoc.data()?['participants'] ?? []
        );
        
        // 받는 사람 목록 (본인 제외)
        final recipientIds = participants.where((id) => id != _currentUserId).toList();

        await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .collection(ChatConstants.messagesCollection)
            .add({
          'senderId': _currentUserId,
          'text': message,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'readBy': [_currentUserId], // 보낸 사람은 자동으로 읽은 것으로 처리
        });

        // 읽지 않은 메시지 수 업데이트 (모든 참여자에게)
        final unreadCountUpdates = <String, dynamic>{};
        for (final recipientId in recipientIds) {
          unreadCountUpdates['${ChatConstants.unreadCount}.$recipientId'] = FieldValue.increment(1);
        }

        await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .update({
          ChatConstants.lastMessage: message,
          ChatConstants.lastMessageTime: FieldValue.serverTimestamp(),
          ...unreadCountUpdates,
        });

        // 알림 전송 (모든 참여자에게)
        final senderName = context.read<EmailAuthProvider>().user?.displayName ?? '알 수 없음';
        for (final recipientId in recipientIds) {
          if (recipientId.isNotEmpty) {
            await FCMService().sendChatNotification(
              recipientUid: recipientId,
              senderName: senderName,
              message: message,
              chatRoomId: widget.chatRoomId,
            );
          }
        }
      } else {
        await LocalAppRepository.instance.sendMessage(
          roomId: widget.chatRoomId,
          senderUid: _currentUserId!,
          text: message,
        );
      }

      /// 입력창 초기화
      _messageController.clear();

      _scrollToBottom();
    } catch (e) {
      debugPrint('메시지 전송 실패: $e');
      _showSnackBar('메시지 전송에 실패했습니다');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// 스크롤을 맨 아래로 이동
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection(ChatConstants.chatRoomsCollection)
              .doc(widget.chatRoomId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Text(
                widget.opponentName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
            
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final chatRoomType = data?['type'] ?? 'purchase';
            final isGroupChat = chatRoomType == 'groupBuy';
            
            if (isGroupChat) {
              // 그룹 채팅: 상품 제목 표시
              final productTitle = data?['productTitle'] as String? ?? '같이사요 채팅';
              final participants = List<String>.from(data?['participants'] ?? []);
              final otherParticipants = participants
                  .where((id) => id != _currentUserId)
                  .length;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    productTitle,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (otherParticipants > 0)
                    Text(
                      '${otherParticipants}명 참여',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              );
            } else {
              // 1:1 채팅: 기존대로 상대방 이름 표시
              return Text(
                widget.opponentName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // 더보기 메뉴 (필요 시 구현)
            },
          ),
        ],
      ),
      body: Column(
        children: [
          /// 메시지 목록
          Expanded(
            child: _buildMessageList(),
          ),

          /// 입력창
          _ChatInput(
            controller: _messageController,
            onSend: _sendMessage,
            onSendLocation: _sendLocationMessage,
            isSending: _isSending,
          ),
        ],
      ),
    );
  }

  /// 메시지 목록 위젯
  Widget _buildMessageList() {
    if (AppConfig.useFirebase) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .collection(ChatConstants.messagesCollection)
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('오류가 발생했습니다: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final messages = snapshot.data?.docs
                  .map((doc) => ChatMessage.fromFirestore(doc))
                  .toList() ??
              [];
          
          // 읽지 않은 메시지가 있는지 확인하고 읽음 처리
          final hasUnreadMessages = messages.any((msg) => 
            msg.senderId != _currentUserId && !msg.isRead
          );
          
          if (hasUnreadMessages && _currentUserId != null) {
            // 읽지 않은 메시지가 있으면 읽음 처리
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markMessagesAsRead();
            });
          }
          
          return _buildMessageListView(messages);
        },
      );
    } else {
      return StreamBuilder<List<AppChatMessage>>(
        stream: LocalAppRepository.instance.watchMessages(widget.chatRoomId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('오류가 발생했습니다: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages =
              snapshot.data?.map(_convertLocalMessage).toList() ?? [];
          
          // 읽지 않은 메시지가 있는지 확인하고 읽음 처리
          final hasUnreadMessages = messages.any((msg) => 
            msg.senderId != _currentUserId && !msg.isRead
          );
          
          if (hasUnreadMessages && _currentUserId != null) {
            // 읽지 않은 메시지가 있으면 읽음 처리
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markMessagesAsRead();
            });
          }
          
          return _buildMessageListView(messages);
        },
      );
    }
  }

  Widget _buildMessageListView(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          '메시지가 없습니다\n첫 메시지를 보내보세요!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMine = message.senderId == _currentUserId;

        bool showDateDivider = false;
        if (index == 0) {
          showDateDivider = true;
        } else {
          final prevMessage = messages[index - 1];
          showDateDivider = !_isSameDay(
            prevMessage.createdAt,
            message.createdAt,
          );
        }

        return Column(
          children: [
            if (showDateDivider) _DateDivider(date: message.createdAt),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(ChatConstants.chatRoomsCollection)
                  .doc(widget.chatRoomId)
                  .snapshots(),
              builder: (context, roomSnapshot) {
                if (!roomSnapshot.hasData) {
                  return _MessageBubble(
                    message: message,
                    isMine: isMine,
                    participants: const [],
                    currentUserId: _currentUserId ?? '',
                  );
                }
                
                final data = roomSnapshot.data!.data() as Map<String, dynamic>?;
                final isGroupChat = data?['type'] == 'groupBuy';
                final participantNames = data?['participantNames'] != null
                    ? Map<String, String>.from(data!['participantNames'] as Map)
                    : <String, String>{};
                final participants = List<String>.from(data?['participants'] ?? []);
                
                return _MessageBubble(
                  message: message,
                  isMine: isMine,
                  isGroupChat: isGroupChat,
                  participantNames: participantNames,
                  participants: participants,
                  currentUserId: _currentUserId ?? '',
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  ChatMessage _convertLocalMessage(AppChatMessage message) {
    return ChatMessage(
      id: message.id,
      senderId: message.senderUid,
      text: message.text,
      createdAt: message.sentAt,
      isRead: message.readBy.contains(_currentUserId),
      readBy: message.readBy,
    );
  }

  /// 같은 날짜인지 확인
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

/// 날짜 구분선 위젯
class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = '오늘';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateText = '어제';
    } else {
      dateText = DateFormat('M월 d일').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }
}

/// 메시지 말풍선 위젯
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool isGroupChat;
  final Map<String, String> participantNames;
  final List<String> participants;
  final String currentUserId;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.isGroupChat = false,
    this.participantNames = const {},
    required this.participants,
    required this.currentUserId,
  });

  /// 읽음 표시가 있는지 확인
  bool _hasReadIndicator() {
    if (isGroupChat) {
      // 그룹 채팅: 읽지 않은 사람 수 표시
      final unreadCount = message.getUnreadCount(participants, message.senderId);
      return unreadCount > 0;
    } else {
      // 1대1 채팅: 상대방이 읽었는지 확인
      final opponentId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      
      if (opponentId.isEmpty) {
        return false;
      }
      
      return !message.isReadByOpponent(opponentId);
    }
  }

  /// 읽음 표시 위젯 생성
  Widget _buildReadIndicator() {
    if (isGroupChat) {
      // 그룹 채팅: 읽지 않은 사람 수 표시
      final unreadCount = message.getUnreadCount(participants, message.senderId);
      if (unreadCount == 0) {
        // 모두 읽었으면 표시 없음
        return const SizedBox.shrink();
      }
      // 읽지 않은 사람 수 표시
      return Text(
        '$unreadCount',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      // 1대1 채팅: 상대방이 읽었는지 확인
      final opponentId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      
      if (opponentId.isEmpty) {
        return const SizedBox.shrink();
      }
      
      if (message.isReadByOpponent(opponentId)) {
        // 읽었으면 표시 없음
        return const SizedBox.shrink();
      } else {
        // 읽지 않았으면 "1" 표시
        return const Text(
          '1',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderName = participantNames[message.senderId] ?? '알 수 없음';
    
    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // 그룹 채팅이고 내 메시지가 아닐 때 발신자 이름 표시
        if (isGroupChat && !isMine) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              senderName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        Row(
          mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isMine) ...[
              /// 내 메시지: 읽음 표시 및 시간 표시
              Builder(
                builder: (context) {
                  // 읽음 표시가 있는지 확인
                  final hasReadIndicator = _hasReadIndicator();
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      clipBehavior: Clip.none,
                      children: [
                        // 시간 표시
                        Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        // 읽음 표시 (시간의 마지막 글자 위)
                        if (hasReadIndicator)
                          Positioned(
                            bottom: 16,
                            right: 0,
                            child: _buildReadIndicator(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],

            /// 메시지 말풍선
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine ? Colors.teal : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 18),
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isMine ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            if (!isMine) ...[
              /// 상대방 메시지 시간 표시
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 채팅 입력창 위젯
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onSendLocation;
  final bool isSending;

  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.onSendLocation,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            /// 위치 공유 버튼
            IconButton(
              icon: const Icon(Icons.location_on, color: Colors.teal),
              onPressed: isSending ? null : onSendLocation,
              tooltip: '위치 공유',
            ),
            /// 입력창
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '메시지를 입력하세요',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (!isSending) {
                      onSend();
                    }
                  },
                  enabled: !isSending,
                ),
              ),
            ),

            const SizedBox(width: 8),

            /// 전송 버튼
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isSending ? null : onSend,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSending ? Colors.grey[300] : Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: isSending
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}