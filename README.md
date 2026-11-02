# fde-playbook

현업 담당자와 대화하며 모호한 운영 문제를 풀고 웹 결과물로 내는 과제(FDE 스타일 AI 협업 과제)용 개인 작업 키트.

AI 코딩 에이전트(Codex 등)가 읽는 작업 규칙과 스킬, 기록 템플릿, Dart 풀스택 앱 템플릿으로 구성된다.
특정 과제의 풀이는 포함하지 않는다. 포함된 도메인 코드는 동작 확인용 합성 데이터 데모뿐이다.

## 구성
```
AGENTS.md                    에이전트 작업 규칙 (기록, 질문, 베이스라인, 검증)
.agents/skills/
  fde-pilot/                 시험 진행 조종석: 시간표, 단계 게이트, 복붙용 담당자 메시지, 사람이 정할 판단 하나
  fde-discovery/             관계도, 도메인 모델, 업무 흐름, 인터뷰, 서면 합의 (팔란티어, 스페이스와이 방법론)
  decision-cards/            결정 포인트를 선택지 카드로 만들어 담당자에게 받기
  web-design/                업무용 화면 정보 구조, 디자인 토큰, 점검표
  optimization-modeling/     입지, 배정, 경로, 시간표 모델링과 검증 (Python opt_kit)
  objective-and-tradeoffs/   목표, 제약, 지표 정의와 시나리오 비교
  baseline-and-verify/       데이터 점검, 베이스라인 채점, 검증 체크리스트
  decision-log/              의사결정, AI 제안 기록, 운영 리스크, 결과 보고
  handoff/                   단계별 인계 문서와 세션 전환
  cognition-prep/            후속 서술형 대비 브리프
  dart-web-stack/            Jaspr/Serverpod 사용법과 환경 점검
vendor-skills/              외부 공식 스킬 (각 폴더에 라이선스 포함)
  jaspr/                     Jaspr 0.23.5 공식 스킬 5개 (MIT)
  serverpod/                 Serverpod 4.1.0 공식 스킬 29개 (BSD-3)
  design/frontend-design     Anthropic frontend-design (Apache 2.0)
  design/impeccable          Impeccable 4.8 (Apache 2.0)
docs/
  PLAYBOOK.md                180분 운영안
  guide.html                 스페이스와이식 AX 방법론 학습 페이지 (브라우저로 열기)
  templates/                 STAKEHOLDERS, ONTOLOGY, REQUIREMENTS, QUESTIONS, OPEN_DECISIONS, AGREEMENT, DECISIONS, VERIFY, HANDOFF, RESULT
scripts/
  install.sh                 작업 폴더에 위 파일 설치 (덮어쓰지 않음)
  env_check.sh               환경 점검 (dart, flutter, root, IPv6, pub.dev, 포트)
template/
  core/                      순수 Dart 평가 하네스 (CSV, 프로파일, 입력 검증, 지표, 제약, 시나리오 비교, 최대 커버리지)
  web_app/                   Jaspr 서버 렌더링 + shelf API 비교 화면 (KPI, SVG 지도, 엔진 전환)
  analysis/                  Python opt_kit (MCLP, 최소 커버, p-median, 배정, VRP, 시간표, 군집)
  data/                      데모 CSV (Dart와 Python 교차검증용)
```

## 빠른 시작
```
git clone https://github.com/<계정>/fde-playbook.git /tmp/fde-playbook
bash /tmp/fde-playbook/scripts/install.sh . --app   # 기본 47개: 우리 11 + Jaspr 5 + Serverpod 29 + frontend-design + impeccable
# 가볍게: --minimal (17개)
codex   # 그다음: $fde-pilot 시작 19:05
bash /tmp/fde-playbook/scripts/env_check.sh
cd app/web_app && dart pub get && jaspr serve   # http://localhost:8080
```

## 요구 환경
- Dart 3.10 이상, `jaspr_cli` 0.23 (`dart pub global activate jaspr_cli`)
- 템플릿 확인 버전: Dart 3.13.7, jaspr 0.23.5, serverpod 4.1.0

## 테스트
```
cd template/core && dart test
cd template/web_app && dart test
cd template/analysis && python3 -m unittest
```
