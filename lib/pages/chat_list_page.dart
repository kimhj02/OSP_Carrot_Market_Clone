/// 채팅 목록 페이지
///
/// 사용자의 모든 채팅방 목록을 보여주는 페이지입니다.

import 'package:flutter/material.dart';
import 'package:flutter_sandbox/pages/chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 임시 채팅 목록 데이터 (나중에 Firebase에서 가져올 예정)
    final chatList = [
      {
        'id': '1',
        'opponentName': '김철수',
        'lastMessage': '안녕하세요! 상품 관심 있어요.',
        'lastMessageTime': '오후 2:30',
        'unreadCount': 2,
        'productImage': 'https://via.placeholder.com/60',
      },
      {
        'id': '2',
        'opponentName': '이영희',
        'lastMessage': '네, 가능합니다!',
        'lastMessageTime': '오후 1:15',
        'unreadCount': 0,
        'productImage': 'https://via.placeholder.com/60',
      },
      {
        'id': '3',
        'opponentName': '박민수',
        'lastMessage': '직거래 가능한가요?',
        'lastMessageTime': '오전 11:20',
        'unreadCount': 1,
        'productImage': 'https://via.placeholder.com/60',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '채팅',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // 검색 기능 (추후 구현)
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // 추가 메뉴 (추후 구현)
            },
          ),
        ],
      ),
      body: chatList.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              itemCount: chatList.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 80,
              ),
              itemBuilder: (context, index) {
                final chat = chatList[index];
                return _ChatListItem(
                  opponentName: chat['opponentName'] as String,
                  lastMessage: chat['lastMessage'] as String,
                  lastMessageTime: chat['lastMessageTime'] as String,
                  unreadCount: chat['unreadCount'] as int,
                  productImage: chat['productImage'] as String,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          opponentName: chat['opponentName'] as String,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
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
            '아직 시작된 채팅이 없습니다',
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

class _ChatListItem extends StatelessWidget {
  final String opponentName;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final String productImage;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.opponentName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.productImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 프로필 이미지 (또는 상품 이미지)
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(
                      productImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: Colors.grey[400],
                          size: 28,
                        );
                      },
                    ),
                  ),
                ),
                // 온라인 상태 표시 (선택사항)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // 채팅 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        lastMessageTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
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
                            '$unreadCount',
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
}

