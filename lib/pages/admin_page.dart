/// 관리자 페이지
///
/// 광고를 관리하는 관리자 전용 페이지입니다.
/// 광고 목록 표시, 추가, 수정, 삭제 기능을 제공합니다.
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sandbox/models/ad.dart';
import 'package:flutter_sandbox/providers/ad_provider.dart';

/// 관리자 페이지 위젯
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '광고 관리',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showAddAdDialog(context),
          ),
        ],
      ),
      body: Consumer<AdProvider>(
        builder: (context, adProvider, child) {
          if (adProvider.loading && adProvider.ads.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (adProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    adProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (adProvider.ads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 광고가 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오른쪽 상단의 + 버튼을 눌러 광고를 추가하세요',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: adProvider.ads.length,
            itemBuilder: (context, index) {
              final ad = adProvider.ads[index];
              return _buildAdCard(context, ad, adProvider);
            },
          );
        },
      ),
    );
  }

  /// 광고 카드를 생성하는 위젯
  Widget _buildAdCard(BuildContext context, Ad ad, AdProvider adProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 광고 제목과 상태
            Row(
              children: [
                Expanded(
                  child: Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ad.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ad.isActive ? '활성' : '비활성',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 광고 설명
            Text(
              ad.description,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 광고 이미지
            if (ad.imageUrl.isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ad.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // 광고 정보
            Row(
              children: [
                Icon(Icons.link, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ad.linkUrl,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 활성화/비활성화 토글
                TextButton.icon(
                  onPressed: () async {
                    final success = await adProvider.toggleAdActive(
                      ad.id,
                      !ad.isActive,
                    );
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ad.isActive ? '광고가 비활성화되었습니다' : '광고가 활성화되었습니다',
                          ),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    ad.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(ad.isActive ? '비활성화' : '활성화'),
                ),
                const SizedBox(width: 8),
                // 수정 버튼
                TextButton.icon(
                  onPressed: () => _showEditAdDialog(context, ad),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('수정'),
                ),
                const SizedBox(width: 8),
                // 삭제 버튼
                TextButton.icon(
                  onPressed: () =>
                      _showDeleteConfirmDialog(context, ad, adProvider),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 광고 추가 다이얼로그 표시
  void _showAddAdDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final imageUrlController = TextEditingController();
    final linkUrlController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('광고 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: '이미지 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkUrlController,
                  decoration: const InputDecoration(
                    labelText: '링크 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('활성화'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final adProvider = Provider.of<AdProvider>(
                  context,
                  listen: false,
                );
                final ad = Ad(
                  id: '',
                  title: titleController.text,
                  description: descriptionController.text,
                  imageUrl: imageUrlController.text,
                  linkUrl: linkUrlController.text,
                  isActive: isActive,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final adId = await adProvider.addAd(ad);
                if (adId != null && context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('광고가 추가되었습니다')));
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(adProvider.errorMessage ?? '광고 추가에 실패했습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  /// 광고 수정 다이얼로그 표시
  void _showEditAdDialog(BuildContext context, Ad ad) {
    final titleController = TextEditingController(text: ad.title);
    final descriptionController = TextEditingController(text: ad.description);
    final imageUrlController = TextEditingController(text: ad.imageUrl);
    final linkUrlController = TextEditingController(text: ad.linkUrl);
    bool isActive = ad.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('광고 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: '이미지 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkUrlController,
                  decoration: const InputDecoration(
                    labelText: '링크 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('활성화'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final adProvider = Provider.of<AdProvider>(
                  context,
                  listen: false,
                );
                final updatedAd = ad.copyWith(
                  title: titleController.text,
                  description: descriptionController.text,
                  imageUrl: imageUrlController.text,
                  linkUrl: linkUrlController.text,
                  isActive: isActive,
                  updatedAt: DateTime.now(),
                );

                final success = await adProvider.updateAd(updatedAd);
                if (success && context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('광고가 수정되었습니다')));
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(adProvider.errorMessage ?? '광고 수정에 실패했습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('수정'),
            ),
          ],
        ),
      ),
    );
  }

  /// 광고 삭제 확인 다이얼로그 표시
  void _showDeleteConfirmDialog(
    BuildContext context,
    Ad ad,
    AdProvider adProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('광고 삭제'),
        content: Text('"${ad.title}" 광고를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final success = await adProvider.deleteAd(ad.id);
              if (success && context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('광고가 삭제되었습니다')));
              } else if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(adProvider.errorMessage ?? '광고 삭제에 실패했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
