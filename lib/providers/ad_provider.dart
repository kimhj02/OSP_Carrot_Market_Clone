/// 광고 상태 관리 Provider
///
/// Provider 패턴을 사용하여 Firestore의 광고 데이터를 관리하는 클래스입니다.
/// ChangeNotifier를 mixin하여 상태 변경 시 UI에 자동으로 알림을 보냅니다.
///
/// 주요 기능:
/// - 활성 광고 목록 조회
/// - 광고 추가/수정/삭제
/// - Firestore와 실시간 동기화
///
/// @author Flutter Sandbox
/// @version 1.0.0
/// @since 2024-01-01

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sandbox/models/ad.dart';

/// 광고 상태를 관리하는 Provider 클래스
///
/// ChangeNotifier를 mixin하여 상태 변경 시 구독자들에게 알림을 보냅니다.
/// Firestore를 사용하여 실제 데이터를 관리합니다.
class AdProvider with ChangeNotifier {
  /// Firestore 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 광고 목록
  List<Ad> _ads = [];

  /// 로딩 상태
  bool _loading = false;

  /// 에러 메시지
  String? _errorMessage;

  /// Firestore 스트림 구독
  StreamSubscription<QuerySnapshot>? _adsSubscription;

  /// 광고 목록을 반환합니다.
  List<Ad> get ads => _ads;

  /// 활성화된 광고 목록만 반환합니다.
  List<Ad> get activeAds => _ads.where((ad) => ad.isActive).toList();

  /// 로딩 상태를 반환합니다.
  bool get loading => _loading;

  /// 에러 메시지를 반환합니다.
  String? get errorMessage => _errorMessage;

  /// 생성자 - Firestore 스트림 구독 시작
  AdProvider() {
    _subscribeToAds();
  }

  /// Firestore의 ads 컬렉션을 실시간으로 구독합니다.
  void _subscribeToAds() {
    _adsSubscription = _firestore
        .collection('ads')
        .snapshots()
        .listen(
          (snapshot) {
            _ads = snapshot.docs
                .map((doc) => Ad.fromFirestore(doc.data(), doc.id))
                .toList();
            _errorMessage = null;
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = '광고 목록 조회 중 오류 발생: $error';
            notifyListeners();
          },
        );
  }

  /// 광고를 추가합니다.
  ///
  /// Parameters:
  ///   - ad: 추가할 광고 객체
  ///
  /// Returns:
  ///   - 성공 시 광고 ID, 실패 시 null
  Future<String?> addAd(Ad ad) async {
    try {
      setState(loading: true, errorMessage: null);

      final docRef = await _firestore.collection('ads').add(ad.toFirestore());

      setState(loading: false);
      return docRef.id;
    } catch (e) {
      final errorMsg = '광고 추가 중 오류 발생: $e';
      setState(loading: false, errorMessage: errorMsg);
      return null;
    }
  }

  /// 광고를 수정합니다.
  ///
  /// Parameters:
  ///   - ad: 수정할 광고 객체
  ///
  /// Returns:
  ///   - 성공 시 true, 실패 시 false
  Future<bool> updateAd(Ad ad) async {
    try {
      setState(loading: true, errorMessage: null);

      await _firestore
          .collection('ads')
          .doc(ad.id)
          .update(ad.copyWith(updatedAt: DateTime.now()).toFirestore());

      setState(loading: false);
      return true;
    } catch (e) {
      final errorMsg = '광고 수정 중 오류 발생: $e';
      setState(loading: false, errorMessage: errorMsg);
      return false;
    }
  }

  /// 광고를 삭제합니다.
  ///
  /// Parameters:
  ///   - adId: 삭제할 광고 ID
  ///
  /// Returns:
  ///   - 성공 시 true, 실패 시 false
  Future<bool> deleteAd(String adId) async {
    try {
      setState(loading: true, errorMessage: null);

      await _firestore.collection('ads').doc(adId).delete();

      setState(loading: false);
      return true;
    } catch (e) {
      final errorMsg = '광고 삭제 중 오류 발생: $e';
      setState(loading: false, errorMessage: errorMsg);
      return false;
    }
  }

  /// 광고 활성화 상태를 토글합니다.
  ///
  /// Parameters:
  ///   - adId: 토글할 광고 ID
  ///   - isActive: 활성화 여부
  ///
  /// Returns:
  ///   - 성공 시 true, 실패 시 false
  Future<bool> toggleAdActive(String adId, bool isActive) async {
    try {
      setState(loading: true, errorMessage: null);

      await _firestore.collection('ads').doc(adId).update({
        'isActive': isActive,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      setState(loading: false);
      return true;
    } catch (e) {
      final errorMsg = '광고 상태 변경 중 오류 발생: $e';
      setState(loading: false, errorMessage: errorMsg);
      return false;
    }
  }

  /// 상태를 업데이트하는 헬퍼 메서드
  void setState({bool? loading, String? errorMessage}) {
    if (loading != null) _loading = loading;
    if (errorMessage != null) _errorMessage = errorMessage;
    notifyListeners();
  }

  /// 리소스를 정리합니다.
  @override
  void dispose() {
    _adsSubscription?.cancel();
    super.dispose();
  }
}
