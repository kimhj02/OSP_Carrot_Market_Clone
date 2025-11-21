# 같이사요 게시물 위치 표기 개선

## 📋 변경 사항

같이사요 상품의 위치 표시를 판매자 위치가 아닌 **만나는 위치**로 변경했습니다.

### 주요 변경 내용

1. **Product 모델에 GroupBuyInfo 필드 추가**
   - `Product` 클래스에 `GroupBuyInfo? groupBuy` 필드 추가
   - Firestore 및 JSON 파싱 시 `groupBuy` 정보 포함
   - `fromFirestore`, `fromJson`, `toJson`, `copyWith` 메서드에 `groupBuy` 처리 추가

2. **홈 화면 위치 표시 로직 개선**
   - 같이사요 상품인 경우 `groupBuy.meetPlaceText`를 우선 표시
   - 일반 상품은 기존 로직 유지 (`meetLocationDetail` → `location`)

3. **로컬 모드 지원**
   - `LocalAppRepository`의 `_listingToProduct` 메서드에서 `groupBuy` 정보 포함

## 🎯 개선 효과

- ✅ 같이사요 상품의 경우 판매자 위치(예: "구미시 인동동") 대신 만나는 위치(예: "금오공대 정문 앞")가 표시됩니다
- ✅ 사용자가 실제 만날 장소를 더 명확하게 확인할 수 있습니다
- ✅ 일반 상품과 같이사요 상품의 위치 표시가 구분됩니다

## 📝 테스트

- [x] 같이사요 상품의 위치가 `meetPlaceText`로 표시되는지 확인
- [x] 일반 상품의 위치 표시가 정상적으로 작동하는지 확인
- [x] Firestore 모드에서 정상 작동 확인
- [x] 로컬 모드에서 정상 작동 확인

## 🔗 관련 이슈

같이사요 상품의 위치 표시 개선 요청
