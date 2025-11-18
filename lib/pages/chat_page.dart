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

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isRead,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
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
      });
      if (_currentUserId != null) {
        _markMessagesAsRead();
      }
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

    if (AppConfig.useFirebase) {
      try {
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .collection(ChatConstants.messagesCollection)
            .where('senderId', isNotEqualTo: _currentUserId)
            .where('isRead', isEqualTo: false)
            .get();

        final batch = FirebaseFirestore.instance.batch();

        for (var doc in messagesSnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }

        await batch.commit();

        await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .update({
          '${ChatConstants.unreadCount}.$_currentUserId': 0,
        });
      } catch (e) {
        debugPrint('메시지 읽음 처리 실패: $e');
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
        final recipientId = participants.firstWhere(
              (id) => id != _currentUserId,
          orElse: () => '',
        );

        await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .collection(ChatConstants.messagesCollection)
            .add({
          'senderId': _currentUserId,
          'text': message,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        await FirebaseFirestore.instance
            .collection(ChatConstants.chatRoomsCollection)
            .doc(widget.chatRoomId)
            .update({
          ChatConstants.lastMessage: message,
          ChatConstants.lastMessageTime: FieldValue.serverTimestamp(),
          '${ChatConstants.unreadCount}.$recipientId': FieldValue.increment(1),
        });
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
        title: Text(
          widget.opponentName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              /// 더보기 메뉴 (향후 구현)
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
            _MessageBubble(
              message: message,
              isMine: isMine,
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

  const _MessageBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
      isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isMine) ...[
          /// 내 메시지: 시간 표시
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
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