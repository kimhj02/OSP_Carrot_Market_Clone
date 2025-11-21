/// 상품 모델 클래스
///
/// 당근 마켓의 상품 정보를 나타내는 데이터 모델입니다.
/// 상품의 기본 정보, 가격, 위치, 상태 등을 포함합니다.
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';

/// 상품 상태를 나타내는 enum
enum ProductStatus {
  /// 판매중
  onSale,

  /// 예약중
  reserved,

  /// 판매완료
  sold,
}

/// 상품 카테고리를 나타내는 enum
enum ProductCategory {
  /// 전자기기
  digital,

  /// 전공책
  textbooks,

  /// 생활용품
  daily,

  /// 가구/주거
  housing,

  /// 패션/잡화
  fashion,

  /// 취미/레저
  hobby,

  /// 기타
  etc,

  /// 같이사요 (공동구매/합배송)
  groupBuy,
}

/// 당근 마켓 상품 모델 클래스
class Product {
  /// 상품 고유 ID
  final String id;

  /// 상품 제목
  final String title;

  /// 상품 설명
  final String description;

  /// 상품 가격 (원 단위)
  final int price;

  /// 상품 이미지 URL 목록
  final List<String> imageUrls;

  /// 상품 카테고리
  final ProductCategory category;

  /// 상품 상태
  final ProductStatus status;

  /// 판매자 ID
  final String sellerId;

  /// 판매자 닉네임
  final String sellerNickname;

  /// 판매자 프로필 이미지 URL
  final String? sellerProfileImageUrl;

  /// 상품 위치 (동네)
  final String location;

  /// 상품 등록일
  final DateTime createdAt;

  /// 상품 수정일
  final DateTime updatedAt;

  /// 상품 조회수
  final int viewCount;

  /// 상품 찜 수
  final int likeCount;

  /// 상품이 찜되었는지 여부
  final bool isLiked;

  final double x; //위도

  final double y; //경도

  /// 상세 거래 위치 (예: "금오공대 정문 앞 편의점", "인동동 마트 앞")
  final String? meetLocationDetail;

  /// 같이사요 정보 (같이사요 상품인 경우에만 존재)
  final GroupBuyInfo? groupBuy;

  /// Product 생성자
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrls,
    required this.category,
    required this.status,
    required this.sellerId,
    required this.sellerNickname,
    this.sellerProfileImageUrl,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.x = 0.0,
    this.y = 0.0,
    this.meetLocationDetail,
    this.groupBuy,
  });

  /// 안전한 Enum 파싱 헬퍼 메서드
  ///
  /// Firestore나 JSON에서 받은 정수 값을 Enum으로 안전하게 변환합니다.
  /// 값이 범위를 벗어나거나 잘못된 타입인 경우 기본값을 반환합니다.
  ///
  /// [values] Enum 값들의 리스트 (예: ProductCategory.values)
  /// [value] 변환할 값 (정수여야 함)
  /// [defaultValue] 변환 실패 시 반환할 기본값
  ///
  /// Returns: 변환된 Enum 값 또는 기본값
  static T safeParseEnum<T>(
    List<T> values,
    dynamic value,
    T defaultValue,
  ) {
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    return defaultValue;
  }

  /// Firestore DocumentSnapshot에서 Product 객체를 생성하는 팩토리 생성자
  ///
  /// 안전한 Enum 파싱을 통해 RangeError를 방지합니다.
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 위치 정보 파싱 (GeoPoint와 region 정보)
    final location = data['location'] as GeoPoint?;
    final region = data['region'] as Map<String, dynamic>?;
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    
    return Product(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      imageUrls: List<String>.from(data['images'] ?? []),
      category: safeParseEnum(
        ProductCategory.values,
        data['category'],
        ProductCategory.etc,
      ),
      status: safeParseEnum(
        ProductStatus.values,
        data['status'],
        ProductStatus.onSale,
      ),
      sellerId: data['sellerUid'] as String? ?? data['sellerId'] as String? ?? '',
      sellerNickname: data['sellerName'] as String? ?? data['sellerNickname'] as String? ?? '',
      sellerProfileImageUrl: data['sellerPhotoUrl'] as String? ?? data['sellerProfileImageUrl'] as String?,
      location: region?['name'] as String? ?? '알 수 없는 지역',
      createdAt: createdAt?.toDate() ?? DateTime.now(),
      updatedAt: updatedAt?.toDate() ?? DateTime.now(),
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      isLiked: data['isLiked'] as bool? ?? false,
      x: location?.latitude ?? (data['x'] as num?)?.toDouble() ?? (data['latitude'] as num?)?.toDouble() ?? 0.0,
      y: location?.longitude ?? (data['y'] as num?)?.toDouble() ?? (data['longitude'] as num?)?.toDouble() ?? 0.0,
      meetLocationDetail: data['meetLocationDetail'] as String?,
      groupBuy: parseGroupBuyInfo(data['groupBuy']),
    );
  }

  /// GroupBuyInfo 파싱 헬퍼 메서드
  ///
  /// Firestore나 JSON에서 받은 GroupBuyInfo 데이터를 안전하게 파싱합니다.
  /// 유효하지 않은 데이터인 경우 null을 반환합니다.
  static GroupBuyInfo? parseGroupBuyInfo(dynamic groupBuyData) {
    if (groupBuyData == null || groupBuyData is! Map<String, dynamic>) {
      return null;
    }
    
    try {
      final orderDeadline = groupBuyData['orderDeadline'];
      DateTime parsedDeadline;
      
      if (orderDeadline is Timestamp) {
        parsedDeadline = orderDeadline.toDate();
      } else if (orderDeadline is String && orderDeadline.isNotEmpty) {
        try {
          parsedDeadline = DateTime.parse(orderDeadline);
        } catch (e) {
          // 유효하지 않은 날짜 문자열인 경우 null 반환
          return null;
        }
      } else {
        // orderDeadline이 없거나 유효하지 않은 타입인 경우 null 반환
        return null;
      }
      
      return GroupBuyInfo(
        itemSummary: groupBuyData['itemSummary'] as String? ?? '',
        maxMembers: (groupBuyData['maxMembers'] as num?)?.toInt() ?? 0,
        currentMembers: (groupBuyData['currentMembers'] as num?)?.toInt() ?? 0,
        pricePerPerson: (groupBuyData['pricePerPerson'] as num?)?.toInt() ?? 0,
        orderDeadline: parsedDeadline,
        meetPlaceText: groupBuyData['meetPlaceText'] as String? ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  /// JSON에서 Product 객체를 생성하는 팩토리 생성자
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: json['price'] as int,
      imageUrls: List<String>.from(json['imageUrls'] as List),
      category: safeParseEnum(
        ProductCategory.values,
        json['category'],
        ProductCategory.etc,
      ),
      status: safeParseEnum(
        ProductStatus.values,
        json['status'],
        ProductStatus.onSale,
      ),
      sellerId: json['sellerId'] as String,
      sellerNickname: json['sellerNickname'] as String,
      sellerProfileImageUrl: json['sellerProfileImageUrl'] as String?,
      location: json['location'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      viewCount: json['viewCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      meetLocationDetail: json['meetLocationDetail'] as String?,
      groupBuy: parseGroupBuyInfo(json['groupBuy']),
    );
  }

  /// Product 객체를 JSON으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'category': category.index,
      'status': status.index,
      'sellerId': sellerId,
      'sellerNickname': sellerNickname,
      'sellerProfileImageUrl': sellerProfileImageUrl,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'viewCount': viewCount,
      'likeCount': likeCount,
      'isLiked': isLiked,
      'meetLocationDetail': meetLocationDetail,
      'groupBuy': groupBuy != null
          ? {
              'itemSummary': groupBuy!.itemSummary,
              'maxMembers': groupBuy!.maxMembers,
              'currentMembers': groupBuy!.currentMembers,
              'pricePerPerson': groupBuy!.pricePerPerson,
              'orderDeadline': groupBuy!.orderDeadline.toIso8601String(),
              'meetPlaceText': groupBuy!.meetPlaceText,
            }
          : null,
    };
  }

  /// 가격을 포맷된 문자열로 반환하는 메서드
  String get formattedPrice {
    if (price >= 10000) {
      return '${(price / 10000).toStringAsFixed(0)}만원';
    } else {
      return '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
    }
  }

  /// 상품 상태를 한글로 반환하는 메서드
  String get statusText {
    switch (status) {
      case ProductStatus.onSale:
        return '판매중';
      case ProductStatus.reserved:
        return '예약중';
      case ProductStatus.sold:
        return '판매완료';
    }
  }

  /// 카테고리를 한글로 반환하는 메서드
  String get categoryText {
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

  /// 상품이 판매 가능한 상태인지 확인하는 메서드
  bool get isAvailable => status == ProductStatus.onSale;

  /// 상품 복사본을 생성하는 메서드 (일부 필드 수정 가능)
  Product copyWith({
    String? id,
    String? title,
    String? description,
    int? price,
    List<String>? imageUrls,
    ProductCategory? category,
    ProductStatus? status,
    String? sellerId,
    String? sellerNickname,
    String? sellerProfileImageUrl,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    int? likeCount,
    bool? isLiked,
    String? meetLocationDetail,
    GroupBuyInfo? groupBuy,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category ?? this.category,
      status: status ?? this.status,
      sellerId: sellerId ?? this.sellerId,
      sellerNickname: sellerNickname ?? this.sellerNickname,
      sellerProfileImageUrl:
          sellerProfileImageUrl ?? this.sellerProfileImageUrl,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      meetLocationDetail: meetLocationDetail ?? this.meetLocationDetail,
      groupBuy: groupBuy ?? this.groupBuy,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, title: $title, price: $formattedPrice, status: $statusText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
