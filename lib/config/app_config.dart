class AppConfig {
  /// Firebase 연동 여부를 제어하는 전역 플래그
  ///
  /// - `true`: Firebase 초기화 및 실시간 백엔드 사용
  /// - `false`: 로컬 인메모리(Mock) 데이터로 모든 기능 수행
  static const bool useFirebase = true;
}