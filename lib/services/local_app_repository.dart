import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_sandbox/models/ad.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/models/product.dart';

/// Firestore 스키마를 로컬 인메모리 데이터로 모사한 저장소
class LocalAppRepository {
  LocalAppRepository._() {
    _seedData();
  }

  static final LocalAppRepository instance = LocalAppRepository._();

  final Map<String, Region> _regions = {};
  final Map<String, University> _universities = {};
  final Map<String, AppUserProfile> _users = {};
  final Map<String, AppUserPrivate> _privateUsers = {};
  final Map<String, Listing> _listings = {};
  final Map<String, AppChatRoom> _chatRooms = {};
  final Map<String, List<AppChatMessage>> _messages = {};
  final List<Ad> _ads = [];
  final Map<String, String> _passwords = {};

  AppUserProfile? _currentUser;

  late final StreamController<AppUserProfile?> _authController =
      StreamController<AppUserProfile?>.broadcast(
    onListen: () {
      _authController.add(_currentUser);
    },
  );
  final Map<String, StreamController<List<AppChatRoom>>> _chatRoomControllers =
      {};
  final Map<String, StreamController<List<AppChatMessage>>>
      _messageControllers = {};

  AppUserProfile? get currentUser => _currentUser;

  Stream<AppUserProfile?> get authStateChanges => _authController.stream;

  List<Ad> get ads => List.unmodifiable(_ads);

  List<Product> getProducts({String? viewerUid}) {
    return _listings.values
        .map((listing) => _listingToProduct(
              listing,
              viewerUid: viewerUid ?? _currentUser?.uid,
            ))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Product? getProductById(String listingId, {String? viewerUid}) {
    final listing = _listings[listingId];
    if (listing == null) return null;
    return _listingToProduct(
      listing,
      viewerUid: viewerUid ?? _currentUser?.uid,
    );
  }

  Listing? getListing(String listingId) => _listings[listingId];

  AppUserProfile? findUser(String uid) => _users[uid];

  List<Listing> getAllListings() => _listings.values.toList();

  String? getUniversityName(String code) => _universities[code]?.name;

  /// 이메일 도메인으로부터 학교 정보를 찾습니다
  University? getUniversityByEmailDomain(String email) {
    final domain = email.split('@').last.toLowerCase();
    return _universities.values.firstWhere(
      (university) => university.emailDomains.any(
        (emailDomain) => domain == emailDomain.toLowerCase(),
      ),
      orElse: () => throw StateError('학교를 찾을 수 없습니다'),
    );
  }

  /// 이메일 도메인으로부터 학교 코드를 찾습니다
  String? getUniversityCodeByEmailDomain(String email) {
    try {
      return getUniversityByEmailDomain(email)?.code;
    } catch (e) {
      return null;
    }
  }

  /// 학교 위치로부터 기본 지역을 반환합니다
  Region? getDefaultRegionByUniversity(String universityCode) {
    final university = _universities[universityCode];
    if (university == null) return null;
    
    // 금오공대의 경우 구미시 인동동
    if (universityCode == 'KUMOH') {
      return _regions['KR-47-구미시-인동동'];
    }
    
    // 기본적으로 첫 번째 지역 반환
    return _regions.values.isNotEmpty ? _regions.values.first : null;
  }

  /// 위도/경도로 실제 속한 지역을 찾습니다
  /// 각 지역의 경계를 체크하여 정확한 동 이름을 반환합니다
  String getRegionNameByLocation(double latitude, double longitude) {
    // 각 지역의 경계 범위를 정의 (실제로는 더 정확한 폴리곤 체크가 필요하지만, 
    // 로컬 환경에서는 간단한 경계 박스로 처리)
    
    // 강남구 역삼동 경계 (대략적인 범위)
    if (latitude >= 37.4900 && latitude <= 37.5050 &&
        longitude >= 127.0200 && longitude <= 127.0350) {
      return '강남구 역삼동';
    }
    
    // 서초구 서초동 경계 (대략적인 범위)
    if (latitude >= 37.4750 && latitude <= 37.4920 &&
        longitude >= 127.0250 && longitude <= 127.0400) {
      return '서초구 서초동';
    }
    
    // 마포구 망원동 경계 (대략적인 범위)
    if (latitude >= 37.5450 && latitude <= 37.5650 &&
        longitude >= 127.9000 && longitude <= 127.9200) {
      return '마포구 망원동';
    }
    
    // 구미시 인동동 경계 (금오공대 주변, 대략적인 범위)
    if (latitude >= 36.1300 && latitude <= 36.1600 &&
        longitude >= 128.3800 && longitude <= 128.4100) {
      return '구미시 인동동';
    }
    
    // 경계에 속하지 않으면 가장 가까운 지역을 찾음
    Region? closestRegion;
    double minDistance = double.infinity;

    for (final region in _regions.values) {
      double distance = _calculateDistance(
        latitude,
        longitude,
        _getRegionCenterLat(region.code),
        _getRegionCenterLng(region.code),
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestRegion = region;
      }
    }

    return closestRegion?.name ?? '알 수 없는 지역';
  }

  /// 위도/경도로 실제 속한 Region 객체를 찾습니다
  Region? getRegionByLocation(double latitude, double longitude) {
    final regionName = getRegionNameByLocation(latitude, longitude);
    return _regions.values.firstWhere(
      (region) => region.name == regionName,
      orElse: () => _regions.values.first,
    );
  }

  double _getRegionCenterLat(String regionCode) {
    // 시드 데이터의 위치를 기준으로 반환
    switch (regionCode) {
      case 'KR-11-강남구-역삼동':
        return 37.4979;
      case 'KR-11-서초구-서초동':
        return 37.4837;
      case 'KR-11-마포구-망원동':
        return 37.5553;
      case 'KR-47-구미시-인동동':
        return 36.1461; // 금오공대 위치
      default:
        return 37.4979; // 기본값
    }
  }

  double _getRegionCenterLng(String regionCode) {
    switch (regionCode) {
      case 'KR-11-강남구-역삼동':
        return 127.0276;
      case 'KR-11-서초구-서초동':
        return 127.0324;
      case 'KR-11-마포구-망원동':
        return 126.9109;
      case 'KR-47-구미시-인동동':
        return 128.3939; // 금오공대 위치
      default:
        return 127.0276; // 기본값
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // 하버사인 공식을 사용한 거리 계산 (km)
    const double earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  Future<String?> login(String email, String password) async {
    AppUserProfile? user;
    try {
      user = _users.values.firstWhere(
        (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
      );
    } on StateError {
      return '등록된 계정이 없습니다.';
    }
    final storedPassword = _passwords[user.uid];
    if (storedPassword == null) {
      return '등록된 계정이 없습니다.';
    }
    if (storedPassword != password) {
      return '비밀번호가 올바르지 않습니다.';
    }
    _setCurrentUser(user);
    return null;
  }

  Future<String?> signUp(String email, String password) async {
    final exists = _users.values.any(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
    );
    if (exists) {
      return '이미 등록된 이메일입니다.';
    }
    if (password.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    final uid = 'local_${_users.length + 1}';
    final defaultRegion = _regions.values.first;
    final newUser = AppUserProfile(
      uid: uid,
      displayName: email.split('@').first,
      email: email,
      region: defaultRegion,
      universityId: _universities.keys.first,
      emailVerified: true,
      createdAt: DateTime.now(),
      photoUrl: null,
    );
    _users[uid] = newUser;
    _passwords[uid] = password;
    _privateUsers[uid] = AppUserPrivate(
      uid: uid,
      phoneNumber: '',
      pushTokens: const <String>[],
      blockedUserIds: const <String>[],
    );
    _setCurrentUser(newUser);
    return null;
  }

  Future<void> logout() async {
    _currentUser = null;
    _authController.add(null);
  }

  bool canDeleteListing(String listingId, String requesterUid) {
    final listing = _listings[listingId];
    if (listing == null) return false;
    return listing.sellerUid == requesterUid;
  }

  Future<void> deleteListing(String listingId) async {
    _listings.remove(listingId);
  }

  Future<void> updateListing({
    required String listingId,
    String? title,
    int? price,
    List<AppGeoPoint>? meetLocations,
    List<String>? images,
    ProductCategory? category,
    String? description,
    ListingStatus? status,
    GroupBuyInfo? groupBuy,
  }) async {
    final listing = _listings[listingId];
    if (listing == null) {
      throw ArgumentError('상품을 찾을 수 없습니다.');
    }

    final updatedListing = listing.copyWith(
      title: title ?? listing.title,
      price: price ?? listing.price,
      meetLocations: meetLocations ?? listing.meetLocations,
      images: images ?? listing.images,
      category: category ?? listing.category,
      description: description ?? listing.description,
      status: status ?? listing.status,
      groupBuy: groupBuy ?? listing.groupBuy,
      updatedAt: DateTime.now(),
    );

    // 위치가 변경된 경우 location도 업데이트
    if (meetLocations != null && meetLocations.isNotEmpty) {
      _listings[listingId] = updatedListing.copyWith(
        location: meetLocations.first,
        meetLocations: meetLocations,
      );
    } else {
      _listings[listingId] = updatedListing;
    }
  }

  void toggleFavorite(String listingId, String userId) {
    final listing = _listings[listingId];
    if (listing == null) return;
    final updatedLikes = Set<String>.from(listing.likedUserIds);
    if (updatedLikes.contains(userId)) {
      updatedLikes.remove(userId);
    } else {
      updatedLikes.add(userId);
    }

    _listings[listingId] = listing.copyWith(
      likeCount: updatedLikes.length,
      likedUserIds: updatedLikes,
      updatedAt: DateTime.now(),
    );
  }

  Future<Listing> createListing({
    required ListingType type,
    required String title,
    required int price,
    required List<AppGeoPoint> meetLocations,
    required List<String> images,
    required ProductCategory category,
    required Region region,
    required String universityId,
    required AppUserProfile seller,
    required String description,
    GroupBuyInfo? groupBuy,
  }) async {
    final id = 'listing_${DateTime.now().microsecondsSinceEpoch}';
    final listing = Listing(
      id: id,
      type: type,
      title: title,
      price: price,
      location: meetLocations.first,
      meetLocations: meetLocations,
      images: images,
      category: category,
      status: ListingStatus.onSale,
      region: region,
      universityId: universityId,
      sellerUid: seller.uid,
      sellerName: seller.displayName,
      sellerPhotoUrl: seller.photoUrl,
      likeCount: 0,
      viewCount: 0,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likedUserIds: {},
      groupBuy: groupBuy,
    );

    _listings[id] = listing;
    return listing;
  }

  Stream<List<AppChatRoom>> watchChatRooms(String userId) {
    final controller = _chatRoomControllers.putIfAbsent(userId, () {
      late final StreamController<List<AppChatRoom>> ctrl;
      ctrl = StreamController<List<AppChatRoom>>.broadcast(
        onListen: () => ctrl.add(_chatRoomsForUser(userId)),
      );
      return ctrl;
    });
    controller.add(_chatRoomsForUser(userId));
    return controller.stream;
  }

  Stream<List<AppChatMessage>> watchMessages(String roomId) {
    final controller = _messageControllers.putIfAbsent(roomId, () {
      late final StreamController<List<AppChatMessage>> ctrl;
      ctrl = StreamController<List<AppChatMessage>>.broadcast(
        onListen: () => ctrl.add(_messagesForRoom(roomId)),
      );
      return ctrl;
    });
    controller.add(_messagesForRoom(roomId));
    return controller.stream;
  }

  Future<String> ensureChatRoom({
    required String listingId,
    required String buyerUid,
  }) async {
    final listing = _listings[listingId];
    if (listing == null) {
      throw ArgumentError('상품을 찾을 수 없습니다.');
    }
    try {
      final existing = _chatRooms.values.firstWhere(
        (room) =>
            room.listingId == listingId &&
            room.participants.contains(buyerUid) &&
            room.participants.contains(listing.sellerUid),
      );
      return existing.id;
    } on StateError {
      // 기존 채팅방이 없으면 새로 생성
      final newRoom = _createChatRoom(listing: listing, buyerUid: buyerUid);
      return newRoom.id;
    }
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderUid,
    required String text,
  }) async {
    final room = _chatRooms[roomId];
    if (room == null) {
      throw ArgumentError('채팅방을 찾을 수 없습니다.');
    }
    final now = DateTime.now();
    final message = AppChatMessage(
      id: 'msg_${now.microsecondsSinceEpoch}_${math.Random().nextInt(9999)}',
      roomId: roomId,
      senderUid: senderUid,
      text: text,
      sentAt: now,
      readBy: {senderUid},
    );
    final messages = _messages.putIfAbsent(roomId, () => []);
    messages.add(message);

    final updatedUnread = Map<String, int>.from(room.unread);
    for (final uid in room.participants) {
      if (uid == senderUid) {
        updatedUnread[uid] = 0;
      } else {
        updatedUnread[uid] = (updatedUnread[uid] ?? 0) + 1;
      }
    }
    _chatRooms[roomId] = room.copyWith(
      lastMessage: text,
      lastMessageTime: now,
      unread: updatedUnread,
      updatedAt: now,
    );

    _emitMessages(roomId);
    _emitChatRooms();
  }

  Future<void> markMessagesAsRead({
    required String roomId,
    required String userId,
  }) async {
    final roomMessages = _messages[roomId];
    if (roomMessages != null) {
      for (var i = 0; i < roomMessages.length; i++) {
        final message = roomMessages[i];
        if (message.readBy.contains(userId)) continue;
        roomMessages[i] = message.copyWith(
          readBy: {...message.readBy, userId},
        );
      }
      _emitMessages(roomId);
    }

    final room = _chatRooms[roomId];
    if (room != null) {
      final updatedUnread = Map<String, int>.from(room.unread);
      updatedUnread[userId] = 0;
      _chatRooms[roomId] = room.copyWith(
        unread: updatedUnread,
        updatedAt: DateTime.now(),
      );
      _emitChatRooms();
    }
  }

  void _emitChatRooms() {
    for (final entry in _chatRoomControllers.entries) {
      if (!entry.value.hasListener) continue;
      entry.value.add(_chatRoomsForUser(entry.key));
    }
  }

  void _emitMessages(String roomId) {
    final controller = _messageControllers[roomId];
    if (controller == null || !controller.hasListener) return;
    controller.add(_messagesForRoom(roomId));
  }

  List<AppChatRoom> _chatRoomsForUser(String userId) {
    return _chatRooms.values
        .where((room) => room.participants.contains(userId))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<AppChatMessage> _messagesForRoom(String roomId) {
    final list = _messages[roomId] ?? [];
    return List<AppChatMessage>.from(list)
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  void _setCurrentUser(AppUserProfile? user) {
    _currentUser = user;
    _authController.add(user);
  }

  AppChatRoom _createChatRoom({
    required Listing listing,
    required String buyerUid,
  }) {
    final buyer = _users[buyerUid];
    if (buyer == null) {
      throw ArgumentError('구매자 정보를 찾을 수 없습니다.');
    }
    final roomId = '${listing.id}_$buyerUid';
    final now = DateTime.now();
    final newRoom = AppChatRoom(
      id: roomId,
      type: ChatRoomType.privateRoom,
      listingId: listing.id,
      listingTitle: listing.title,
      listingImage: listing.images.isNotEmpty ? listing.images.first : null,
      listingType: listing.type,
      hostUid: listing.sellerUid,
      participants: [buyerUid, listing.sellerUid],
      participantNames: {
        buyerUid: buyer.displayName,
        listing.sellerUid: listing.sellerName,
      },
      unread: {buyerUid: 0, listing.sellerUid: 0},
      lastMessage: '',
      lastMessageTime: now,
      isClosed: false,
      createdAt: now,
      updatedAt: now,
    );
    _chatRooms[roomId] = newRoom;
    _messages[roomId] = [];
    _emitChatRooms();
    return newRoom;
  }

  void _seedData() {
    final now = DateTime.now();

    final regionGangnam = Region(
      code: 'KR-11-강남구-역삼동',
      name: '강남구 역삼동',
      level: 'neighborhood',
      parent: 'KR-11-강남구',
    );
    final regionSeocho = Region(
      code: 'KR-11-서초구-서초동',
      name: '서초구 서초동',
      level: 'neighborhood',
      parent: 'KR-11-서초구',
    );
    final regionMapo = Region(
      code: 'KR-11-마포구-망원동',
      name: '마포구 망원동',
      level: 'neighborhood',
      parent: 'KR-11-마포구',
    );
    final regionGumi = Region(
      code: 'KR-47-구미시-인동동',
      name: '구미시 인동동',
      level: 'neighborhood',
      parent: 'KR-47-구미시',
    );

    _regions[regionGangnam.code] = regionGangnam;
    _regions[regionSeocho.code] = regionSeocho;
    _regions[regionMapo.code] = regionMapo;
    _regions[regionGumi.code] = regionGumi;

    final kumoh = University(
      code: 'KUMOH',
      name: '금오공과대학교',
      emailDomains: const ['kumoh.ac.kr'],
      location: const AppGeoPoint(latitude: 36.1461, longitude: 128.3932),
    );
    _universities[kumoh.code] = kumoh;

    final userAlice = AppUserProfile(
      uid: 'user_alice',
      displayName: '김철수',
      email: 'alice@kumoh.ac.kr',
      region: regionGangnam,
      universityId: kumoh.code,
      emailVerified: true,
      createdAt: now.subtract(const Duration(days: 45)),
      photoUrl:
          'https://cdn.pixabay.com/photo/2020/07/01/12/58/avatar-5357766_1280.png',
    );
    final userBob = AppUserProfile(
      uid: 'user_bob',
      displayName: '이영희',
      email: 'bob@kumoh.ac.kr',
      region: regionMapo,
      universityId: kumoh.code,
      emailVerified: true,
      createdAt: now.subtract(const Duration(days: 20)),
      photoUrl:
          'https://cdn.pixabay.com/photo/2021/02/21/18/39/avatar-6039862_1280.png',
    );
    final userCharlie = AppUserProfile(
      uid: 'user_charlie',
      displayName: '박민수',
      email: 'charlie@kumoh.ac.kr',
      region: regionSeocho,
      universityId: kumoh.code,
      emailVerified: true,
      createdAt: now.subtract(const Duration(days: 12)),
      photoUrl:
          'https://cdn.pixabay.com/photo/2016/03/31/19/14/avatar-1295401_1280.png',
    );

    _users[userAlice.uid] = userAlice;
    _users[userBob.uid] = userBob;
    _users[userCharlie.uid] = userCharlie;

    _privateUsers[userAlice.uid] = AppUserPrivate(
      uid: userAlice.uid,
      phoneNumber: '010-1111-2222',
      pushTokens: const <String>[],
      blockedUserIds: const <String>[],
    );
    _privateUsers[userBob.uid] = AppUserPrivate(
      uid: userBob.uid,
      phoneNumber: '010-3333-4444',
      pushTokens: const <String>[],
      blockedUserIds: const <String>[],
    );
    _privateUsers[userCharlie.uid] = AppUserPrivate(
      uid: userCharlie.uid,
      phoneNumber: '010-5555-6666',
      pushTokens: const [],
      blockedUserIds: const [],
    );

    _passwords[userAlice.uid] = 'password123';
    _passwords[userBob.uid] = 'password123';
    _passwords[userCharlie.uid] = 'password123';

    // 기본 사용자는 설정하지 않음 (로그인 화면에서 선택하도록)
    // _setCurrentUser(userAlice);

    final listing1 = Listing(
      id: 'listing_iphone14',
      type: ListingType.market,
      title: '아이폰 14 Pro 256GB',
      price: 800000,
      location: const AppGeoPoint(latitude: 37.4979, longitude: 127.0276),
      meetLocations: const [
        AppGeoPoint(latitude: 37.4979, longitude: 127.0276),
      ],
      images: const ['lib/dummy_data/아이폰.jpeg'],
      category: ProductCategory.digital,
      status: ListingStatus.onSale,
      region: regionGangnam,
      universityId: kumoh.code,
      sellerUid: userAlice.uid,
      sellerName: userAlice.displayName,
      sellerPhotoUrl: userAlice.photoUrl,
      likeCount: 10,
      viewCount: 120,
      description: '거의 새 제품입니다. 케이스와 보호필름 포함',
      createdAt: now.subtract(const Duration(hours: 4)),
      updatedAt: now.subtract(const Duration(hours: 1)),
      likedUserIds: {userBob.uid},
    );
    final listing2 = Listing(
      id: 'listing_textbook',
      type: ListingType.market,
      title: '운영체제 전공책 세트',
      price: 35000,
      location: const AppGeoPoint(latitude: 37.5553, longitude: 126.9109),
      meetLocations: const [
        AppGeoPoint(latitude: 37.5553, longitude: 126.9109),
      ],
      images: const ['lib/dummy_data/아이폰.jpeg'],
      category: ProductCategory.textbooks,
      status: ListingStatus.onSale,
      region: regionMapo,
      universityId: kumoh.code,
      sellerUid: userBob.uid,
      sellerName: userBob.displayName,
      sellerPhotoUrl: userBob.photoUrl,
      likeCount: 6,
      viewCount: 80,
      description: 'OS, 자료구조 전공 필독서 세트입니다.',
      createdAt: now.subtract(const Duration(hours: 10)),
      updatedAt: now.subtract(const Duration(hours: 2)),
      likedUserIds: {userAlice.uid},
    );
    final listing3 = Listing(
      id: 'listing_group_buy',
      type: ListingType.groupBuy,
      title: '콜라 1.5L 4개 같이 사요',
      price: 12000,
      location: const AppGeoPoint(latitude: 37.4979, longitude: 127.0276),
      meetLocations: const [
        AppGeoPoint(latitude: 37.4979, longitude: 127.0276),
      ],
      images: const ['lib/dummy_data/에어포스.jpeg'],
      category: ProductCategory.groupBuy,
      status: ListingStatus.onSale,
      region: regionGangnam,
      universityId: kumoh.code,
      sellerUid: userCharlie.uid,
      sellerName: userCharlie.displayName,
      sellerPhotoUrl: userCharlie.photoUrl,
      likeCount: 3,
      viewCount: 30,
      description: '역삼역 앞에서 나눠 가질 분을 모집합니다.',
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(minutes: 20)),
      likedUserIds: {userAlice.uid, userBob.uid},
      groupBuy: GroupBuyInfo(
        itemSummary: '콜라 1.5L 4개 세트',
        maxMembers: 4,
        currentMembers: 2,
        pricePerPerson: 3000,
        orderDeadline: now.add(const Duration(hours: 6)),
        meetPlaceText: '역삼역 3번 출구 앞',
      ),
    );

    _listings[listing1.id] = listing1;
    _listings[listing2.id] = listing2;
    _listings[listing3.id] = listing3;

    _ads.addAll([
      Ad(
        id: 'ad_local_1',
        title: '배달비 아끼는 꿀팁',
        description: '같이사요로 배달비를 절약해보세요!',
        imageUrl: 'https://picsum.photos/seed/ad1/400/200',
        linkUrl: 'https://example.com',
        isActive: true,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Ad(
        id: 'ad_local_2',
        title: '학생 전용 기숙사 할인',
        description: '금오대 전용 기숙사 가전 렌탈 할인중!',
        imageUrl: 'https://picsum.photos/seed/ad2/400/200',
        linkUrl: 'https://example.com/2',
        isActive: true,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);

    final room = AppChatRoom(
      id: 'room_${listing1.id}_${userBob.uid}',
      type: ChatRoomType.privateRoom,
      listingId: listing1.id,
      listingTitle: listing1.title,
      listingImage: listing1.images.isNotEmpty ? listing1.images.first : null,
      listingType: listing1.type,
      hostUid: listing1.sellerUid,
      participants: [userBob.uid, listing1.sellerUid],
      participantNames: {
        userBob.uid: userBob.displayName,
        listing1.sellerUid: listing1.sellerName,
      },
      unread: {userBob.uid: 0, listing1.sellerUid: 1},
      lastMessage: '혹시 에눌 가능할까요?',
      lastMessageTime: now.subtract(const Duration(minutes: 30)),
      isClosed: false,
      createdAt: now.subtract(const Duration(hours: 3)),
      updatedAt: now.subtract(const Duration(minutes: 20)),
    );
    _chatRooms[room.id] = room;
    _messages[room.id] = [
      AppChatMessage(
        id: 'msg1',
        roomId: room.id,
        senderUid: userBob.uid,
        text: '안녕하세요! 상품 아직 판매중인가요?',
        sentAt: now.subtract(const Duration(hours: 2)),
        readBy: {userBob.uid, listing1.sellerUid},
      ),
      AppChatMessage(
        id: 'msg2',
        roomId: room.id,
        senderUid: listing1.sellerUid,
        text: '네, 아직 판매중입니다!',
        sentAt: now.subtract(const Duration(hours: 2, minutes: 30)),
        readBy: {userBob.uid, listing1.sellerUid},
      ),
      AppChatMessage(
        id: 'msg3',
        roomId: room.id,
        senderUid: userBob.uid,
        text: '혹시 에눌 가능할까요?',
        sentAt: now.subtract(const Duration(minutes: 30)),
        readBy: {userBob.uid},
      ),
    ];
  }

  Product _listingToProduct(
    Listing listing, {
    String? viewerUid,
  }) {
    final primaryLocation = listing.meetLocations.isNotEmpty
        ? listing.meetLocations.first
        : listing.location;
    // 실제 판매 위치에 따라 지역 이름을 동적으로 결정
    final locationName = getRegionNameByLocation(
      primaryLocation.latitude,
      primaryLocation.longitude,
    );
    return Product(
      id: listing.id,
      title: listing.title,
      description: listing.description,
      price: listing.price,
      imageUrls: listing.images,
      category: listing.category,
      status: _mapStatus(listing.status),
      sellerId: listing.sellerUid,
      sellerNickname: listing.sellerName,
      sellerProfileImageUrl: listing.sellerPhotoUrl,
      location: locationName,
      createdAt: listing.createdAt,
      updatedAt: listing.updatedAt,
      viewCount: listing.viewCount,
      likeCount: listing.likeCount,
      isLiked:
          viewerUid == null ? false : listing.likedUserIds.contains(viewerUid),
      x: primaryLocation.latitude,
      y: primaryLocation.longitude,
    );
  }

  ProductStatus _mapStatus(ListingStatus status) {
    switch (status) {
      case ListingStatus.onSale:
        return ProductStatus.onSale;
      case ListingStatus.reserved:
        return ProductStatus.reserved;
      case ListingStatus.sold:
        return ProductStatus.sold;
    }
  }
}

