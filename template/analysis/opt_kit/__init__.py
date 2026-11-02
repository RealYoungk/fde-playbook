"""opt_kit: 운영 문제용 최적화/분석 도구 모음.

- geo: 거리 행렬, 도보/차량 시간 환산
- data: CSV 로딩, 데이터 프로파일
- candidates: 후보지 생성 (k-means, 격자, 기존 지점)
- location: 입지 선정 (최대 커버리지 MCLP, p-median, 최소 개수 커버) + 탐욕 대조군
- assign: 용량 제약 배정
- routing: 차량 경로 (VRP, 용량, 시간창)
- timetable: 도착 목표 시각 기준 역산 시간표
- report: Dart ops_core와 같은 JSON 스키마로 결과 출력

모든 MIP 함수는 OR-Tools가 없으면 탐욕 해로 대체하고 status에 그 사실을 남긴다.
"""

__all__ = [
    "geo",
    "data",
    "candidates",
    "location",
    "assign",
    "routing",
    "timetable",
    "report",
]
