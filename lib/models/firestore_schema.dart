import 'package:flutter_sandbox/models/product.dart';

/// 위도/경도를 표현하는 간단한 구조체
class AppGeoPoint {
  final double latitude;
  final double longitude;

  const AppGeoPoint({
    required this.latitude,
    required this.longitude,
  });
}

class Region {
  final String code;
  final String name;
  final String? parent;
  final String level;

  const Region({
    required this.code,
    required this.name,
    required this.level,
    this.parent,
  });
}

const Region defaultRegion = Region(
  code: 'REGION-UNKNOWN',
  name: '대표 동네 미설정',
  level: 'unknown',
  parent: null,
);

class University {
  final String code;
  final String name;
  final List<String> emailDomains;
  final AppGeoPoint location;

  const University({
    required this.code,
    required this.name,
    required this.emailDomains,
    required this.location,
  });
}

class AppUserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final Region region;
  final String universityId;
  final bool emailVerified;
  final DateTime createdAt;

  const AppUserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.region,
    required this.universityId,
    required this.emailVerified,
    required this.createdAt,
    this.photoUrl,
  });

  AppUserProfile copyWith({
    String? displayName,
    String? email,
    Region? region,
    String? universityId,
    bool? emailVerified,
    String? photoUrl,
  }) {
    return AppUserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      region: region ?? this.region,
      universityId: universityId ?? this.universityId,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

class AppUserPrivate {
  final String uid;
  final String phoneNumber;
  final List<String> pushTokens;
  final List<String> blockedUserIds;

  const AppUserPrivate({
    required this.uid,
    required this.phoneNumber,
    required this.pushTokens,
    required this.blockedUserIds,
  });
}

enum ListingType { market, groupBuy }

enum ListingStatus { onSale, reserved, sold }

class GroupBuyInfo {
  final String itemSummary;
  final int maxMembers;
  final int currentMembers;
  final int pricePerPerson;
  final DateTime orderDeadline;
  final String meetPlaceText;

  const GroupBuyInfo({
    required this.itemSummary,
    required this.maxMembers,
    required this.currentMembers,
    required this.pricePerPerson,
    required this.orderDeadline,
    required this.meetPlaceText,
  });
}

class Listing {
  final String id;
  final ListingType type;
  final String title;
  final int price;
  final AppGeoPoint location;
  final List<AppGeoPoint> meetLocations;
  final List<String> images;
  final ProductCategory category;
  final ListingStatus status;
  final Region region;
  final String universityId;
  final String sellerUid;
  final String sellerName;
  final String? sellerPhotoUrl;
  final int likeCount;
  final int viewCount;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Set<String> likedUserIds;
  final GroupBuyInfo? groupBuy;

  const Listing({
    required this.id,
    required this.type,
    required this.title,
    required this.price,
    required this.location,
    required this.meetLocations,
    required this.images,
    required this.category,
    required this.status,
    required this.region,
    required this.universityId,
    required this.sellerUid,
    required this.sellerName,
    required this.sellerPhotoUrl,
    required this.likeCount,
    required this.viewCount,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.likedUserIds,
    this.groupBuy,
  });

  Listing copyWith({
    String? title,
    int? price,
    ListingStatus? status,
    int? likeCount,
    int? viewCount,
    DateTime? updatedAt,
    Set<String>? likedUserIds,
    List<AppGeoPoint>? meetLocations,
    List<String>? images,
    ProductCategory? category,
    String? description,
    AppGeoPoint? location,
    GroupBuyInfo? groupBuy,
  }) {
    return Listing(
      id: id,
      type: type,
      title: title ?? this.title,
      price: price ?? this.price,
      location: location ?? this.location,
      meetLocations: meetLocations ?? this.meetLocations,
      images: images ?? this.images,
      category: category ?? this.category,
      status: status ?? this.status,
      region: region ?? this.region,
      universityId: universityId ?? this.universityId,
      sellerUid: sellerUid,
      sellerName: sellerName,
      sellerPhotoUrl: sellerPhotoUrl,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likedUserIds: likedUserIds ?? this.likedUserIds,
      groupBuy: groupBuy ?? this.groupBuy,
    );
  }
}

enum ChatRoomType { privateRoom, groupRoom }

class ChatParticipant {
  final String uid;
  final String name;
  final String? photoUrl;

  const ChatParticipant({
    required this.uid,
    required this.name,
    this.photoUrl,
  });
}

class AppChatRoom {
  final String id;
  final ChatRoomType type;
  final String listingId;
  final String listingTitle;
  final String? listingImage;
  final ListingType listingType;
  final String hostUid;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, int> unread;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppChatRoom({
    required this.id,
    required this.type,
    required this.listingId,
    required this.listingTitle,
    required this.listingImage,
    required this.listingType,
    required this.hostUid,
    required this.participants,
    required this.participantNames,
    required this.unread,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isClosed,
    required this.createdAt,
    required this.updatedAt,
  });

  AppChatRoom copyWith({
    Map<String, int>? unread,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isClosed,
    DateTime? updatedAt,
  }) {
    return AppChatRoom(
      id: id,
      type: type,
      listingId: listingId,
      listingTitle: listingTitle,
      listingImage: listingImage,
      listingType: listingType,
      hostUid: hostUid,
      participants: participants,
      participantNames: participantNames,
      unread: unread ?? this.unread,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isClosed: isClosed ?? this.isClosed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AppChatMessage {
  final String id;
  final String roomId;
  final String senderUid;
  final String text;
  final String? imageUrl;
  final DateTime sentAt;
  final Set<String> readBy;

  const AppChatMessage({
    required this.id,
    required this.roomId,
    required this.senderUid,
    required this.text,
    required this.sentAt,
    required this.readBy,
    this.imageUrl,
  });

  AppChatMessage copyWith({
    Set<String>? readBy,
  }) {
    return AppChatMessage(
      id: id,
      roomId: roomId,
      senderUid: senderUid,
      text: text,
      sentAt: sentAt,
      imageUrl: imageUrl,
      readBy: readBy ?? this.readBy,
    );
  }
}

class Deal {
  final String id;
  final String listingId;
  final String buyerUid;
  final String sellerUid;
  final String status;
  final String? meetingPlace;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Deal({
    required this.id,
    required this.listingId,
    required this.buyerUid,
    required this.sellerUid,
    required this.status,
    required this.meetingPlace,
    required this.createdAt,
    required this.updatedAt,
  });
}

class AppNotification {
  final String id;
  final String toUid;
  final String type;
  final Map<String, dynamic> payload;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.toUid,
    required this.type,
    required this.payload,
    required this.read,
    required this.createdAt,
  });
}

class Report {
  final String id;
  final String targetType;
  final String targetId;
  final String reporterUid;
  final String reason;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reporterUid,
    required this.reason,
    required this.createdAt,
  });
}

