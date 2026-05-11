# Diesel Carbon Analyzer MVP

OBD 앱(Torque, Car Scanner 등)에서 내보낸 CSV 파일을 불러와 연비 손실 가능성, 카본 누적 의심도, 공회전 비율을 계산하는 Flutter 안드로이드 MVP입니다.

## 실행 방법

1. Flutter 설치
2. 이 폴더에서 아래 명령 실행

```bash
flutter pub get
flutter run
```

## CSV 예시 컬럼

앱은 아래와 같은 이름을 자동 인식합니다.

- 시간: `time`, `timestamp`, `seconds`
- RPM: `rpm`, `engine rpm`
- 속도: `speed`, `vehicle speed`
- 흡기량: `maf`, `mass air flow`
- 연료소모: `fuel_rate`, `fuel rate`, `fuel consumption`

예시:

```csv
time,rpm,speed,maf,fuel_rate
0,720,0,11.2,1.3
1,725,0,11.1,1.2
2,1500,20,18.3,3.2
```

## 현재 분석 항목

- 종합 엔진 효율 점수
- 연비 손실 가능성
- 카본 누적 의심도
- 공회전 비율
- 평균 RPM
- 평균 속도
- 평균 MAF
- 평균 연료소모

## 주의

이 앱은 정비 확정 진단기가 아니라 OBD CSV 데이터 기반 상태 추정 MVP입니다.
