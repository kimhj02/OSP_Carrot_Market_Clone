import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:geolocator/geolocator.dart';

class LocalData {
  final LatLng position;
  final String imageUrl;
  final String title;
  final String price;
  final String description;

  LocalData({
    required this.position,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.description,
  });
}

class Server {

  static final List<LocalData> _items = [
    // ---- 금오공대 주변 상품(반경 500m 내 위치한 상품들) ----
    LocalData(
      position: LatLng(36.1462, 128.3942),
      imageUrl: 'https://codingapple1.github.io/app/img0.jpg',
      title: '금오공대 냉장고 팝니다',
      price: '45,000원',
      description: '금오공대 기숙사 근처에서 거래 가능!',
    ),
    LocalData(
      position: LatLng(36.1458, 128.3935),
      imageUrl: 'https://codingapple1.github.io/app/img1.jpg',
      title: '책상 판매',
      price: '20,000원',
      description: '학생 사용하던 책상입니다.',
    ),

    // ---- 대구 수성구 교학로 11길 46 주변 상품 ----
    LocalData(
      position: LatLng(35.8480, 128.6543),
      imageUrl: 'https://codingapple1.github.io/app/img2.jpg',
      title: '냉장고 팝니다',
      price: '50,000원',
      description: '대구 수성구에서 직거래',
    ),
    LocalData(
      position: LatLng(35.8497, 128.6505),
      imageUrl: 'https://codingapple1.github.io/app/img3.jpg',
      title: '의자 판매',
      price: '10,000원',
      description: '쿠션 편안합니다.',
    ),
  ];

  ///  반경 radius(m) 이내의 상품만 반환
  static Future<List<LocalData>> getItemsWithinRadius(
      LatLng center, double radiusMeters) async {
    List<LocalData> result = [];

    for (var item in _items) {
      final distance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        item.position.latitude,
        item.position.longitude,
      );

      if (distance <= radiusMeters) {
        result.add(item);
      }
    }

    return result;
  }
}



class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final Map<String, BitmapDescriptor> _markerIcons = {};

  List<LocalData> mytownLocalData = [];

  final kumoh = LatLng(36.1461, 128.3939); //금오공대 위치

  Future<void> _fetchServerItems(LatLng center) async {

    final items = await Server.getItemsWithinRadius(center, 500);



    setState(() {
      mytownLocalData = items; // 🔥 기존 리스트를 서버 데이터로 교체
    });

    _loadMarkerIcons(); // 🔥 새 아이콘 다시 그림
  }

  @override
  void initState() {
    super.initState();
    _getUniversityLocation();
    _fetchServerItems(kumoh);
  }

  Future<void> _getUniversityLocation() async {
    // default 금오공대
    _currentPosition = kumoh;
    setState(() {});
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
    _fetchServerItems(kumoh);
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

    _fetchServerItems(LatLng(position.latitude, position.longitude));
   }


  Future<void> _loadMarkerIcons() async {
    for (int i = 0; i < mytownLocalData.length; i++) {
      final data = mytownLocalData[i];
      final icon = await CustomMarkerHelper.createCustomMarker(
        imageUrl: data.imageUrl,
        title: data.title,
        price: data.price,
      );
      _markerIcons['local_$i'] = icon;
    }
    setState(() {});
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

    for (int i = 0; i < mytownLocalData.length; i++) {
      final data = mytownLocalData[i];
      markers.add(Marker(
        markerId: MarkerId('local_$i'),
        position: data.position,
        icon: _markerIcons['local_$i'] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => Container(
              padding: const EdgeInsets.all(16),
              height: 380,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      data.imageUrl,
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.price,
                    style: const TextStyle(
                        color: Colors.teal,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
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

        onMapCreated: (controller) => _mapController = controller,
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

/// 🔹 Helper 클래스: 사진 + 제목 + 가격을 마커 이미지로 그려주는 부분
class CustomMarkerHelper {
  static Future<BitmapDescriptor> createCustomMarker({
    required String imageUrl,
    required String title,
    required String price,
  }) async {
    final ByteData bytes =
    await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl);
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 150,
      targetHeight: 150,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 160;
    const double height = 190;

    final paint = Paint()..color = Colors.white;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, paint);

    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(5, 5, 150, 110),
      image: image,
      fit: BoxFit.cover,
    );

    final textPainter1 = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
            color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);

    final textPainter2 = TextPainter(
      text: TextSpan(
        text: price,
        style: const TextStyle(color: Colors.teal, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);

    textPainter1.paint(canvas, const Offset(10, 120));
    textPainter2.paint(canvas, const Offset(10, 140));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final pngBytes =
    (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }
}
