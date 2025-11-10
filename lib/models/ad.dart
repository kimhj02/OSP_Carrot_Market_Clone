/// 광고 모델 클래스
///
/// 네이티브 광고 정보를 나타내는 데이터 모델입니다.
/// 상품 목록에 삽입되는 광고의 기본 정보를 포함합니다.
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:cloud_firestore/cloud_firestore.dart';

/// 광고 모델 클래스
class Ad {
  /// 광고 고유 ID
  final String id;

  /// 광고 제목
  final String title;

  /// 광고 설명
  final String description;

  /// 광고 이미지 URL
  final String imageUrl;

  /// 광고 링크 URL (클릭 시 이동할 주소)
  final String linkUrl;

  /// 광고 활성화 여부
  final bool isActive;

  /// 광고 생성일
  final DateTime createdAt;

  /// 광고 수정일
  final DateTime updatedAt;

  /// Ad 생성자
  const Ad({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.linkUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore 문서에서 Ad 객체를 생성하는 팩토리 생성자
  factory Ad.fromFirestore(Map<String, dynamic> data, String id) {
    return Ad(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      linkUrl: data['linkUrl'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestore 문서로 변환하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// JSON에서 Ad 객체를 생성하는 팩토리 생성자
  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      linkUrl: json['linkUrl'] as String,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Ad 객체를 JSON으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Ad 복사본을 생성하는 메서드 (일부 필드 수정 가능)
  Ad copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ad(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Ad(id: $id, title: $title, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ad && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
