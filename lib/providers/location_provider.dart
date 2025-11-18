/// 위치 설정 상태 관리 Provider
///
/// Provider 패턴을 사용하여 위치 설정 상태를 관리하는 클래스입니다.
/// ChangeNotifier를 mixin하여 상태 변경 시 UI에 자동으로 알림을 보냅니다.
///
/// 주요 기능:
/// - 현재 위치 선택 상태 관리
/// - 현재 위치 좌표 저장
/// - 위치 필터링 활성화/비활성화
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 위치 필터 타입
enum LocationFilterType {
  /// 필터 없음 (모든 상품 표시)
  none,
  
  /// 현재 위치 주변
  currentLocation,
  
  /// 학교 주변
  school,
}

/// 위치 설정 상태를 관리하는 Provider 클래스
///
/// ChangeNotifier를 mixin하여 상태 변경 시 구독자들에게 알림을 보냅니다.
class LocationProvider with ChangeNotifier {
  /// SharedPreferences 키
  static const String _keyFilterType = 'location_filter_type';
  static const String _keyCurrentLatitude = 'location_current_latitude';
  static const String _keyCurrentLongitude = 'location_current_longitude';
  static const String _keySearchRadius = 'location_search_radius';

  /// 현재 위치의 위도
  double? _currentLatitude;

  /// 현재 위치의 경도
  double? _currentLongitude;

  /// 위치 필터 타입
  LocationFilterType _filterType = LocationFilterType.none;

  /// 초기화 여부
  bool _initialized = false;

  /// LocationProvider 생성자 - 저장된 설정 불러오기
  LocationProvider() {
    _loadSavedSettings();
  }

  /// 학교 위치 (금오공대)
  static const double schoolLatitude = 36.1461;
  static const double schoolLongitude = 128.3939;

  /// 검색 반경 옵션 (미터 단위)
  static const List<double> searchRadiusOptions = [500, 1000, 2000, 5000];

  /// 기본 검색 반경 (미터 단위)
  static const double defaultSearchRadiusMeters = 1000;

  /// 현재 검색 반경 (미터 단위)
  double _searchRadiusMeters = defaultSearchRadiusMeters;

  /// 현재 위치의 위도를 반환합니다.
  double? get currentLatitude => _currentLatitude;

  /// 현재 위치의 경도를 반환합니다.
  double? get currentLongitude => _currentLongitude;

  /// 현재 위치가 선택되었는지 여부를 반환합니다.
  bool get isCurrentLocationSelected => _filterType == LocationFilterType.currentLocation;

  /// 학교가 선택되었는지 여부를 반환합니다.
  bool get isSchoolSelected => _filterType == LocationFilterType.school;

  /// 위치 필터 타입을 반환합니다.
  LocationFilterType get filterType => _filterType;

  /// 검색 반경을 반환합니다.
  double get searchRadius => _searchRadiusMeters;

  /// 검색 반경을 텍스트로 반환합니다 (예: "1km", "500m")
  String get searchRadiusText {
    if (_searchRadiusMeters >= 1000) {
      return '${(_searchRadiusMeters / 1000).toStringAsFixed(0)}km';
    } else {
      return '${_searchRadiusMeters.toInt()}m';
    }
  }

  /// 필터링에 사용할 위도를 반환합니다.
  double? get filterLatitude {
    switch (_filterType) {
      case LocationFilterType.currentLocation:
        return _currentLatitude;
      case LocationFilterType.school:
        return schoolLatitude;
      case LocationFilterType.none:
        return null;
    }
  }

  /// 필터링에 사용할 경도를 반환합니다.
  double? get filterLongitude {
    switch (_filterType) {
      case LocationFilterType.currentLocation:
        return _currentLongitude;
      case LocationFilterType.school:
        return schoolLongitude;
      case LocationFilterType.none:
        return null;
    }
  }

  /// 위치 필터링이 활성화되어 있는지 확인합니다.
  bool get isLocationFilterEnabled => _filterType != LocationFilterType.none;

  /// 저장된 설정을 불러옵니다.
  Future<void> _loadSavedSettings() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 필터 타입 불러오기
      final filterTypeIndex = prefs.getInt(_keyFilterType);
      if (filterTypeIndex != null && filterTypeIndex < LocationFilterType.values.length) {
        _filterType = LocationFilterType.values[filterTypeIndex];
      }
      
      // 현재 위치 좌표 불러오기
      final savedLatitude = prefs.getDouble(_keyCurrentLatitude);
      final savedLongitude = prefs.getDouble(_keyCurrentLongitude);
      if (savedLatitude != null && savedLongitude != null) {
        _currentLatitude = savedLatitude;
        _currentLongitude = savedLongitude;
      }
      
      // 검색 반경 불러오기
      final savedRadius = prefs.getDouble(_keySearchRadius);
      if (savedRadius != null && searchRadiusOptions.contains(savedRadius)) {
        _searchRadiusMeters = savedRadius;
      }
      
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('위치 설정 불러오기 실패: $e');
      _initialized = true;
    }
  }

  /// 설정을 저장합니다.
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt(_keyFilterType, _filterType.index);
      
      if (_currentLatitude != null && _currentLongitude != null) {
        await prefs.setDouble(_keyCurrentLatitude, _currentLatitude!);
        await prefs.setDouble(_keyCurrentLongitude, _currentLongitude!);
      } else {
        await prefs.remove(_keyCurrentLatitude);
        await prefs.remove(_keyCurrentLongitude);
      }
      
      await prefs.setDouble(_keySearchRadius, _searchRadiusMeters);
    } catch (e) {
      debugPrint('위치 설정 저장 실패: $e');
    }
  }

  /// 현재 위치를 설정합니다.
  ///
  /// Parameters:
  /// - [latitude]: 위도
  /// - [longitude]: 경도
  void setCurrentLocation(double latitude, double longitude) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    _filterType = LocationFilterType.currentLocation;
    _saveSettings();
    notifyListeners();
  }

  /// 학교 위치로 설정합니다.
  void setSchoolLocation() {
    _filterType = LocationFilterType.school;
    _saveSettings();
    notifyListeners();
  }

  /// 필터링을 해제합니다 (전체 지역 보기).
  void clearLocationFilter() {
    _filterType = LocationFilterType.none;
    _saveSettings();
    notifyListeners();
  }

  /// 검색 반경을 설정합니다.
  ///
  /// Parameters:
  /// - [radius]: 검색 반경 (미터 단위)
  void setSearchRadius(double radius) {
    if (searchRadiusOptions.contains(radius)) {
      _searchRadiusMeters = radius;
      _saveSettings();
      notifyListeners();
    }
  }
}

