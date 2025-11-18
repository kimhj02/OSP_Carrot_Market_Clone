import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle, rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/models/product.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';
import 'package:flutter_sandbox/providers/location_provider.dart';
import 'package:flutter_sandbox/config/app_config.dart';

class MapScreen extends StatefulWidget {
  final bool moveToCurrentLocationOnInit;
  
  const MapScreen({Key? key, this.moveToCurrentLocationOnInit = false}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final LocalAppRepository _repository = LocalAppRepository.instance;

  final List<_ListingPin> _pins = [];
  final Map<String, BitmapDescriptor> _markerCache = {};

  final LatLng kumoh = const LatLng(36.1461, 128.3939); //금오공대 위치
  static const double _searchRadiusMeters = 5000; // 기본 검색 반경을 5km로 증가

  @override
  void initState() {
    super.initState();
    // 초기 위치 설정 (지도 표시를 위해 필요)
    _currentPosition = kumoh;
    // 앱 생명주기 관찰자 추가 (페이지로 돌아올 때 새로고침)
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _lastRefreshTime;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지가 다시 표시될 때 상품 새로고침 (상품 등록 후 돌아올 때)
    // 마커가 없거나, 마지막 새로고침 후 2초 이상 지났으면 새로고침
    final now = DateTime.now();
    final shouldRefresh = _mapController != null && 
                         _currentPosition != null && 
                         (_pins.isEmpty || 
                          _lastRefreshTime == null || 
                          now.difference(_lastRefreshTime!).inSeconds > 2);
    
    if (shouldRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final locationProvider = context.read<LocationProvider>();
        _refreshListings(_currentPosition!, locationProvider);
        _lastRefreshTime = DateTime.now();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 포그라운드로 돌아올 때 상품 새로고침
    if (state == AppLifecycleState.resumed && _mapController != null && _currentPosition != null) {
      final locationProvider = context.read<LocationProvider>();
      _refreshListings(_currentPosition!, locationProvider);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // 지도가 생성된 후 현재 위치로 이동해야 하는 경우
    if (widget.moveToCurrentLocationOnInit) {
      _moveToCurrentLocation(false);
    } else {
      // LocationProvider의 필터 설정에 따라 지도 업데이트
      final locationProvider = context.read<LocationProvider>();
      LatLng center;
      if (locationProvider.isLocationFilterEnabled &&
          locationProvider.filterLatitude != null &&
          locationProvider.filterLongitude != null) {
        center = LatLng(
          locationProvider.filterLatitude!,
          locationProvider.filterLongitude!,
        );
        _currentPosition = center;
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: center,
              zoom: 17,
            ),
          ),
        );
      } else {
        // 필터가 없으면 기본 위치(금오공대) 사용
        center = kumoh;
      }
      // 항상 상품 로드
      _refreshListings(center, locationProvider);
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // GPS 켜져있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS가 꺼져 있습니다. 설정에서 켜주세요.')),
      );

      await Geolocator.openLocationSettings();
      return false;
    }

    // 권한 확인
    permission = await Geolocator.checkPermission();
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

  Future<void> _moveToCurrentLocation(bool isBack) async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

  // 금오공대로 복귀하는 경우
    if (isBack) {
      setState(() {
        _currentPosition = kumoh;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: 17,
          ),
        ),
      );
    final locationProvider = context.read<LocationProvider>();
    _refreshListings(kumoh, locationProvider);
    return;
  }

  // 현재 위치로 이동하는 경우
    late Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 가져올 수 없습니다.')),
        );
      }
      return;
    }

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition!,
          zoom: 17,
        ),
      ),
    );

    final locationProvider = context.read<LocationProvider>();
    _refreshListings(LatLng(position.latitude, position.longitude), locationProvider);
   }


  Future<void> _refreshListings(LatLng center, LocationProvider locationProvider) async {
    final pins = <_ListingPin>[];
    
    // LocationProvider의 검색 반경 사용 (필터가 활성화된 경우)
    final searchRadius = locationProvider.isLocationFilterEnabled
        ? locationProvider.searchRadius
        : _searchRadiusMeters;
    
    debugPrint('🗺️ 지도 상품 로드 시작: 중심(${center.latitude}, ${center.longitude}), 반경: ${searchRadius}m');
    
    if (AppConfig.useFirebase) {
      // Firebase 모드: Firestore에서 상품 가져오기 (실시간 업데이트)
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .snapshots()
            .first; // 첫 번째 스냅샷만 가져오기 (실시간 업데이트는 build에서 처리)
        
        debugPrint('📦 Firestore에서 ${snapshot.docs.length}개 상품 조회됨');
        
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final location = data['location'] as GeoPoint?;
            final meetLocations = data['meetLocations'] as List?;
            
            if (location == null) {
              debugPrint('⚠️ 상품 ${doc.id}: location이 null입니다.');
              continue;
            }
            
            // Listing 객체로 변환
          // 안전한 타입 변환 헬퍼 함수
          int? _safeInt(dynamic value) {
            if (value == null) return null;
            if (value is int) return value;
            if (value is String) return int.tryParse(value);
            return null;
          }
          
          String? _safeString(dynamic value) {
            if (value == null) return null;
            if (value is String) return value;
            return value.toString();
          }
          
          Map<String, dynamic>? _safeMap(dynamic value) {
            if (value == null) return null;
            if (value is Map) return Map<String, dynamic>.from(value);
            return null;
          }
          
          final categoryValue = _safeInt(data['category']) ?? 0;
          final statusValue = _safeInt(data['status']) ?? 0;
          final priceValue = _safeInt(data['price']) ?? 0;
          final likeCountValue = _safeInt(data['likeCount']) ?? 0;
          final viewCountValue = _safeInt(data['viewCount']) ?? 0;
          
          final regionMap = _safeMap(data['region']);
          final groupBuyMap = _safeMap(data['groupBuy']);
          
          final listing = Listing(
            id: doc.id,
            type: data['type'] == 'market' ? ListingType.market : ListingType.groupBuy,
            title: _safeString(data['title']) ?? '',
            price: priceValue,
            location: AppGeoPoint(
              latitude: location.latitude,
              longitude: location.longitude,
            ),
            meetLocations: meetLocations?.map((loc) {
              if (loc is GeoPoint) {
                return AppGeoPoint(
                  latitude: loc.latitude,
                  longitude: loc.longitude,
                );
              }
              return null;
            }).whereType<AppGeoPoint>().toList() ?? [],
            images: data['images'] is List 
                ? (data['images'] as List).map((e) => _safeString(e) ?? '').where((e) => e.isNotEmpty).cast<String>().toList()
                : [],
            category: ProductCategory.values[categoryValue.clamp(0, ProductCategory.values.length - 1)],
            status: ListingStatus.values[statusValue.clamp(0, ListingStatus.values.length - 1)],
            region: Region(
              code: _safeString(regionMap?['code']) ?? '',
              name: _safeString(regionMap?['name']) ?? '',
              level: _safeString(regionMap?['level']) ?? 
                     _safeInt(regionMap?['level'])?.toString() ?? '0',
              parent: _safeString(regionMap?['parent']),
            ),
            universityId: _safeString(data['universityId']) ?? '',
            sellerUid: _safeString(data['sellerUid']) ?? '',
            sellerName: _safeString(data['sellerName']) ?? '',
            sellerPhotoUrl: _safeString(data['sellerPhotoUrl']),
            likeCount: likeCountValue,
            viewCount: viewCountValue,
            description: _safeString(data['description']) ?? '',
            createdAt: data['createdAt'] is Timestamp 
                ? (data['createdAt'] as Timestamp).toDate() 
                : DateTime.now(),
            updatedAt: data['updatedAt'] is Timestamp 
                ? (data['updatedAt'] as Timestamp).toDate() 
                : DateTime.now(),
            likedUserIds: data['likedUserIds'] is List
                ? Set<String>.from((data['likedUserIds'] as List).map((e) => _safeString(e) ?? '').where((e) => e.isNotEmpty).cast<String>())
                : <String>{},
            groupBuy: groupBuyMap != null ? GroupBuyInfo(
              itemSummary: _safeString(groupBuyMap['itemSummary']) ?? '',
              maxMembers: _safeInt(groupBuyMap['maxMembers']) ?? 0,
              currentMembers: _safeInt(groupBuyMap['currentMembers']) ?? 1,
              pricePerPerson: _safeInt(groupBuyMap['pricePerPerson']) ?? 0,
              orderDeadline: groupBuyMap['orderDeadline'] is Timestamp
                  ? (groupBuyMap['orderDeadline'] as Timestamp).toDate()
                  : DateTime.now(),
              meetPlaceText: _safeString(groupBuyMap['meetPlaceText']) ?? '',
            ) : null,
          );
          
          final points = listing.meetLocations.isEmpty 
              ? [listing.location] 
              : listing.meetLocations;
          
          for (var i = 0; i < points.length; i++) {
            final point = points[i];
            final distance = Geolocator.distanceBetween(
              center.latitude,
              center.longitude,
              point.latitude,
              point.longitude,
            );
            if (distance <= searchRadius) {
              pins.add(
                _ListingPin(
                  listing: listing,
                  point: point,
                  markerId: '${listing.id}_$i',
                ),
              );
              debugPrint('📍 마커 추가: ${listing.title} (거리: ${distance.toStringAsFixed(0)}m)');
            } else {
              debugPrint('❌ 거리 초과로 제외: ${listing.title} (거리: ${distance.toStringAsFixed(0)}m > ${searchRadius}m)');
            }
          }
          } catch (e, stackTrace) {
            debugPrint('❌ 상품 ${doc.id} 처리 실패: $e');
            debugPrint('❌ 스택 트레이스: $stackTrace');
            // 개별 상품 오류는 무시하고 계속 진행
            continue;
          }
        }
        
        debugPrint('✅ 총 ${pins.length}개 마커 생성됨');
      } catch (e) {
        debugPrint('❌ 지도 상품 로드 실패: $e');
        debugPrint('❌ 스택 트레이스: ${StackTrace.current}');
      }
    } else {
      // 로컬 모드
      final listings = _repository.getAllListings();
      debugPrint('📦 로컬 모드: ${listings.length}개 상품 조회됨');
      
      for (final listing in listings) {
        final points =
            listing.meetLocations.isEmpty ? [listing.location] : listing.meetLocations;
        for (var i = 0; i < points.length; i++) {
          final point = points[i];
          final distance = Geolocator.distanceBetween(
            center.latitude,
            center.longitude,
            point.latitude,
            point.longitude,
          );
          if (distance <= searchRadius) {
            pins.add(
              _ListingPin(
                listing: listing,
                point: point,
                markerId: '${listing.id}_$i',
              ),
            );
            debugPrint('📍 마커 추가: ${listing.title} (거리: ${distance.toStringAsFixed(0)}m)');
          } else {
            debugPrint('❌ 거리 초과로 제외: ${listing.title} (거리: ${distance.toStringAsFixed(0)}m > ${searchRadius}m)');
          }
        }
      }
      
      debugPrint('✅ 총 ${pins.length}개 마커 생성됨');
    }
    
    debugPrint('🔄 마커 업데이트: ${pins.length}개');
    setState(() {
      _pins
        ..clear()
        ..addAll(pins);
      _lastRefreshTime = DateTime.now();
    });
    await _preloadMarkerIcons();
    debugPrint('✅ 마커 아이콘 로드 완료');
  }

  Future<void> _preloadMarkerIcons() async {
    for (final pin in _pins) {
      if (_markerCache.containsKey(pin.markerId)) continue;
      final firstImage =
          pin.listing.images.isNotEmpty ? pin.listing.images.first : null;
      final icon = await CustomMarkerHelper.createCustomMarker(
        title: pin.listing.title,
        price: NumberFormat.simpleCurrency(locale: 'ko_KR', name: '')
            .format(pin.listing.price),
        imageUrl: firstImage,
      );
      if (!mounted) return;
      setState(() {
        _markerCache[pin.markerId] = icon;
      });
    }
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('my_location'),
        position: _currentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: '내 위치'),
      ));
    }

    debugPrint('🗺️ 마커 빌드: _pins 개수 = ${_pins.length}');
    for (final pin in _pins) {
      final position = LatLng(pin.point.latitude, pin.point.longitude);
      markers.add(Marker(
        markerId: MarkerId(pin.markerId),
        position: position,
        icon: _markerCache[pin.markerId] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _ListingBottomSheet(pin: pin),
          );
        },
      ));
    }

    debugPrint('🗺️ 총 ${markers.length}개 마커 생성됨 (내 위치 포함)');
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        // LocationProvider가 변경될 때마다 지도 업데이트
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (locationProvider.isLocationFilterEnabled &&
              locationProvider.filterLatitude != null &&
              locationProvider.filterLongitude != null) {
            final filterCenter = LatLng(
              locationProvider.filterLatitude!,
              locationProvider.filterLongitude!,
            );
            if (_currentPosition != filterCenter) {
              _currentPosition = filterCenter;
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: filterCenter,
                    zoom: 17,
                  ),
                ),
              );
              _refreshListings(filterCenter, locationProvider);
            }
          } else if (_pins.isEmpty && _mapController != null) {
            // 마커가 없고 지도가 생성되었으면 초기 로드
            final center = _currentPosition ?? kumoh;
            _refreshListings(center, locationProvider);
          }
        });
        
        return Scaffold(
          appBar: AppBar(title: const Text('내 주변 보기')),
          body: _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition:
                      CameraPosition(target: _currentPosition!, zoom: 17),
                  myLocationEnabled: true,
                  markers: _buildMarkers(),
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(

            mainAxisSize: MainAxisSize.min,
            children:[

              FloatingActionButton(
                onPressed: (){



                  _moveToCurrentLocation(false);
                },
                child: const Icon(Icons.my_location),
              ),
              FloatingActionButton(
                heroTag: "goBack",
                onPressed: ()async{

                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      const CameraPosition(
                        target: LatLng(36.1461, 128.3939),
                        zoom: 17,   // 👍 여기 확대값 적용
                      ),
                    ),
                  );



                  _moveToCurrentLocation(true);
                },
                child: const Icon(Icons.school),
              ),
              const SizedBox(height: 12),
            ]
        ),
      ),
        );
      },
    );
  }
}

class _ListingPin {
  const _ListingPin({
    required this.listing,
    required this.point,
    required this.markerId,
  });

  final Listing listing;
  final AppGeoPoint point;
  final String markerId;
}

class _ListingBottomSheet extends StatelessWidget {
  const _ListingBottomSheet({required this.pin});

  final _ListingPin pin;

  @override
  Widget build(BuildContext context) {
    final listing = pin.listing;
    final priceText = NumberFormat.simpleCurrency(
      locale: 'ko_KR',
      name: '',
    ).format(listing.price);
    final imageUrl = listing.images.isNotEmpty ? listing.images.first : null;

    Widget imageWidget;
    if (imageUrl == null) {
      imageWidget = Container(
        height: 200,
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 48, color: Colors.grey),
      );
    } else if (imageUrl.startsWith('http')) {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    } else {
      imageWidget = Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageWidget,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: Colors.teal,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, listing);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(
                        product: LocalAppRepository.instance
                            .getProductById(listing.id)!,
                      ),
                    ),
                  );
                },
                child: const Text('상세보기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            listing.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '거래 위치: (${pin.point.latitude.toStringAsFixed(4)}, ${pin.point.longitude.toStringAsFixed(4)})',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class CustomMarkerHelper {
  static Future<BitmapDescriptor> createCustomMarker({
    required String title,
    required String price,
    String? imageUrl,
  }) async {
    final bytes = await _loadImageBytes(imageUrl);
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 200,  // 240 -> 200 (약간 축소)
      targetHeight: 200, // 240 -> 200 (약간 축소)
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    const double width = 230;  // 280 -> 230 (약간 축소)
    const double height = 270; // 330 -> 270 (약간 축소)
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final background = Paint()..color = Colors.white;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(20), // 22 -> 20
    );
    canvas.drawRRect(rrect, background);

    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(12, 12, 206, 155), // 이미지 영역 축소 (15,15,250,190 -> 12,12,206,155)
      image: image,
      fit: BoxFit.cover,
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16, // 18 -> 16 (약간 축소)
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 206); // 250 -> 206

    final pricePainter = TextPainter(
      text: TextSpan(
        text: price,
        style: const TextStyle(
          color: Colors.teal,
          fontSize: 15, // 16 -> 15 (약간 축소)
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 206); // 250 -> 206

    titlePainter.paint(canvas, const Offset(12, 180)); // 15,220 -> 12,180
    pricePainter.paint(canvas, const Offset(12, 200)); // 15,245 -> 12,200

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final pngBytes =
        (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }

  static Future<ByteData> _loadImageBytes(String? imageUrl) async {
    if (imageUrl == null) {
      return rootBundle.load('lib/dummy_data/아이폰.jpeg');
    }
    if (imageUrl.startsWith('http')) {
      return await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl);
    }
    return await rootBundle.load(imageUrl);
  }
}
