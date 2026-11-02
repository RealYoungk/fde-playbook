---
name: optimization-modeling
description: 입지 선정(거점, 보관함, 점검 지점), 배정(사람을 방/시간대/담당자에), 경로(배송, 순회), 스케줄링(시간표, 교대), 군집, 수요 분석처럼 수학적 모델링이나 데이터 분석이 필요한 과제에서 사용. 문제를 모델로 옮기고, 풀이 방법을 고르고, 결과를 검증하는 절차와 Python opt_kit 사용법.
---

# 최적화와 데이터 모델링

## 원칙
- **코드 전에 모델을 글로 쓴다.** 결정 변수, 목적, 제약, 데이터를 `DECISIONS.md`에 먼저 적는다. 쓰다 보면 담당자에게 물어야 할 것이 나온다 (`$decision-cards`).
- **판정과 계산은 고정 코드로.** AI가 숫자를 추정하게 두지 않는다. 솔버가 낸 해도 독립 코드로 다시 채점한다.
- **설명 가능한 순서로**: 규칙 → 탐욕 → 정확해(MIP) → 메타휴리스틱. 탐욕 해를 먼저 만들어 베이스라인과 교차검증 기준으로 쓴다.
- **정확해의 의미를 정직하게.** "최적"은 모델 안에서의 최적이다. 후보 집합, 거리 근사, 가중치가 가정이면 가정이라고 쓴다.

## 1. 문제 유형 식별
| 담당자 말 | 유형 | opt_kit 함수 |
|---|---|---|
| "거점 N개로 최대한 많은 사람을 덮고 싶다" | 최대 커버리지 (MCLP) | `location.solve_mclp` |
| "모두 5분 안에 닿게 하되 거점은 최소로" | 집합 커버 / 최소 개수 | `location.solve_min_sites` |
| "평균 이동 거리를 줄이고 싶다" | p-median | `location.solve_pmedian` |
| "정원 넘지 않게 사람을 나누고 싶다" | 용량 제약 배정 | `assign.solve_capacitated_assignment` |
| "어떤 순서로 돌지, 몇 대가 필요한지" | 차량 경로 (VRP, 용량, 시간창) | `routing.solve_vrp` |
| "마감 시각에서 거꾸로 일정 짜기" | 역산 시간표 | `timetable.backward_schedule` |
| "근무 시작이 제각각인데 회차를 몇 개로?" | 시간대 묶기 | `timetable.shift_waves` |
| "후보지가 따로 없다" | 수요 군집으로 후보 생성 | `candidates.kmeans_candidates`, `grid_candidates` |
`references/model-catalog.md`에 각 모델의 수식과 주의점이 있다.

## 2. 작업 순서
1. **데이터 점검**: `data.profile(df)`, 좌표 범위, 결측, 중복, 가중치 의미 확인
2. **비용 행렬**: `geo.haversine_matrix` → `walk_minutes`/`drive_minutes`. 우회 계수와 속도는 가정으로 기록
3. **후보 집합**: 기존 지점 + 군집 중심 + (필요시) 격자. 후보가 해의 상한을 정한다
4. **베이스라인 채점**: 기존안을 같은 지표로
5. **탐욕 해** → **MIP 해**: 둘 다 같은 채점 함수로 지표 계산
6. **교차검증**: MIP ≥ 탐욕(최대화 문제), 작은 사례는 완전탐색과 일치, Dart와 Python 결과 비교
7. **민감도**: 핵심 파라미터(기준 시간, 개수 상한)를 바꿔 지표가 어떻게 변하는지 표로 → 담당자 결정 카드의 숫자
8. **보고**: `report.build(...)`로 Dart와 같은 JSON → 웹 화면 `?engine=python`

## 3. 실행
```
cd app/analysis
python3 -m unittest                 # opt_kit 테스트 (완전탐색 대조, 교차검증 포함)
python3 -m opt_kit demo --md        # 데모: MIP 결과 비교표
python3 -m opt_kit demo --md --method greedy
```
과제에서는 `opt_kit/__main__.py`의 `run_demo`를 복사해 도메인 함수로 바꾼다 (입력 로딩, 후보, 지표, 제약, 시나리오).
웹은 `?engine=python`이면 `python3 -m opt_kit ...`을 호출해 JSON을 받는다 (`web_app/lib/main.server.dart`의 `evaluate`).

## 4. 환경
- 필요 패키지: `ortools numpy pandas` (필수), `scikit-learn scipy networkx` (선택)
- 없으면 `pip install --user ortools pandas scikit-learn` (또는 `--break-system-packages`). 설치가 막히면 MIP 함수는 탐욕 해로 대체되고 status가 `GREEDY_FALLBACK`이 된다. 화면과 보고서에 그대로 표시할 것
- 시간 제한: MIP는 `time_limit_s`(기본 20초). `FEASIBLE`이면 최적 증명 전 시간 종료라는 뜻이니 그렇게 보고

## 5. 결과 해석에서 자주 틀리는 것
- 해 없음(INFEASIBLE)을 0개, 0%로 보여주기 → 위반으로 표시하고 무엇을 완화해야 하는지 제시
- 가중치(인원) 없이 지점 수로 커버율 계산
- 직선거리를 실제 이동시간처럼 말하기 → 우회 계수 가정 명시
- 평균만 보고 꼬리(20분 초과 인원)를 안 봄 → 분포와 최악값도 지표로
- 기존안보다 불리해지는 사람 수를 안 셈 → 민원 지표

## 6. 서술형 재료
- 왜 이 모델인가 (담당자 말 → 유형 매핑)
- 탐욕과 MIP의 차이가 얼마였나, 그 차이가 의사결정에 의미가 있나
- 어떤 가정이 결과를 가장 크게 흔드나 (민감도 표)
