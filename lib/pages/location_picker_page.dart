import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialLocations = const [],
  });

  final List<LatLng> initialLocations;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // 금오공과대학교 위치를 기본 중심으로 설정
  static const LatLng _defaultCenter = LatLng(36.1461, 128.3939);

  late List<LatLng> _selectedLocations;

  @override
  void initState() {
    super.initState();
    _selectedLocations = List<LatLng>.from(widget.initialLocations);
  }

  void _toggleLocation(LatLng latLng) {
    setState(() {
      _selectedLocations.add(latLng);
    });
  }

  void _removeLocation(int index) {
    setState(() {
      _selectedLocations.removeAt(index);
    });
  }

  void _onConfirm() {
    Navigator.pop(context, _selectedLocations);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 위치 선택'),
        actions: [
          TextButton(
            onPressed:
                _selectedLocations.isEmpty ? null : () => setState(() => _selectedLocations.clear()),
            child: const Text('전체 삭제'),
          ),
          TextButton(
            onPressed: _selectedLocations.isEmpty ? null : _onConfirm,
            child: const Text('완료'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _defaultCenter,
                zoom: 14,
              ),
              onMapCreated: (_) {},
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _buildMarkers(),
              onTap: _toggleLocation,
            ),
          ),
          if (_selectedLocations.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '선택된 위치',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._selectedLocations.asMap().entries.map(
                        (entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '위도 ${entry.value.latitude.toStringAsFixed(5)}, 경도 ${entry.value.longitude.toStringAsFixed(5)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeLocation(entry.key),
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedLocations.isEmpty ? null : _onConfirm,
        label: Text(_selectedLocations.isEmpty ? '위치를 선택하세요' : '추가 완료'),
        icon: const Icon(Icons.check),
        tooltip: _selectedLocations.isEmpty 
            ? '지도를 탭하여 위치를 선택하세요' 
            : '선택한 위치로 완료',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Set<Marker> _buildMarkers() {
    return _selectedLocations
        .asMap()
        .entries
        .map(
          (entry) => Marker(
            markerId: MarkerId('selected_${entry.key}'),
            position: entry.value,
            infoWindow: InfoWindow(
              title: '거래 위치 ${entry.key + 1}',
              snippet:
                  'lat ${entry.value.latitude.toStringAsFixed(5)}, lng ${entry.value.longitude.toStringAsFixed(5)}',
            ),
          ),
        )
        .toSet();
  }
}

