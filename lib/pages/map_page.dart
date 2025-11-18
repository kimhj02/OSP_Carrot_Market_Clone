import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle, rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sandbox/models/firestore_schema.dart';
import 'package:flutter_sandbox/pages/product_detail_page.dart';
import 'package:flutter_sandbox/services/local_app_repository.dart';

class MapScreen extends StatefulWidget {
  final bool moveToCurrentLocationOnInit;
  
  const MapScreen({Key? key, this.moveToCurrentLocationOnInit = false}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final LocalAppRepository _repository = LocalAppRepository.instance;

  final List<_ListingPin> _pins = [];
  final Map<String, BitmapDescriptor> _markerCache = {};

  final LatLng kumoh = const LatLng(36.1461, 128.3939); //금오공대 위치
  static const double _searchRadiusMeters = 1000;

  @override
  void initState() {
    super.initState();
    // 초기 위치 설정 (지도 표시를 위해 필요)
    _currentPosition = kumoh;
    if (!widget.moveToCurrentLocationOnInit) {
      _refreshListings(kumoh);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // 지도가 생성된 후 현재 위치로 이동해야 하는 경우
    if (widget.moveToCurrentLocationOnInit) {
      _moveToCurrentLocation(false);
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
    _refreshListings(kumoh);
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

    _refreshListings(LatLng(position.latitude, position.longitude));
   }


  Future<void> _refreshListings(LatLng center) async {
    final listings = _repository.getAllListings();
    final pins = <_ListingPin>[];
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
        if (distance <= _searchRadiusMeters) {
          pins.add(
            _ListingPin(
              listing: listing,
              point: point,
              markerId: '${listing.id}_$i',
            ),
          );
        }
      }
    }
    setState(() {
      _pins
        ..clear()
        ..addAll(pins);
    });
    await _preloadMarkerIcons();
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

    return markers;
  }

  @override
  Widget build(BuildContext context) {
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
      targetWidth: 150,
      targetHeight: 150,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    const double width = 180;
    const double height = 210;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final background = Paint()..color = Colors.white;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(18),
    );
    canvas.drawRRect(rrect, background);

    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(10, 10, 160, 120),
      image: image,
      fit: BoxFit.cover,
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);

    final pricePainter = TextPainter(
      text: TextSpan(
        text: price,
        style: const TextStyle(
          color: Colors.teal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 160);

    titlePainter.paint(canvas, const Offset(10, 140));
    pricePainter.paint(canvas, const Offset(10, 160));

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
