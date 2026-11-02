---
name: dart-web-stack
description: 결과물 웹서비스를 Dart로 만들 때(Jaspr 서버 렌더링 + shelf, 또는 Serverpod) 사용. 템플릿 실행, 데모를 과제 도메인으로 교체, Serverpod 환경 점검과 연동 방법 포함.
---

# Dart 웹 스택

## 플랜 A (기본): Jaspr 서버 렌더링 + shelf API
한 프로세스에서 HTML 페이지와 JSON API를 같이 제공. Flutter, DB, Docker 불필요.

```
app/
  core/      순수 Dart. 도메인 모델, 풀이, 지표, 제약. dart test로 검증
  web_app/   Jaspr (mode: server). lib/main.server.dart에 API와 엔진 선택, lib/app.dart에 화면
  analysis/  Python opt_kit. 정확해(MIP), 경로, 배정. JSON 스키마는 core와 같음
  data/      입력 CSV
```
- 엔진: `?engine=dart`(기본) 또는 `?engine=python`. 두 엔진 모두 `EvaluationReport.fromJson`을 거쳐 같은 화면으로 그린다. Python이 실패하면 Dart로 대체하고 화면에 알린다.
- 환경변수: `OPT_KIT_DIR`(기본 `../analysis`), `DATA_DIR`(기본 `../data`), `PORT`(기본 8080)
- 실행: `dart install jaspr_cli` 또는 `dart pub global activate jaspr_cli` 후 `cd app/web_app && dart pub get && jaspr serve`
- 접속: http://localhost:8080 , API: `/api/evaluate?파라미터=값`, `/api/report.md`
- 화면은 GET 폼 제출로 재계산하므로 클라이언트 JS 빌드가 필요 없다.
- 서버는 IPv4(0.0.0.0) 8080 포트로 뜬다. 8080이 이미 쓰이면 `lib/main.server.dart`의 기본 포트를 바꾼다.

### 데모를 과제 도메인으로 바꾸는 순서
1. `core/lib/src/demo/demo_problem.dart`를 복사해 `core/lib/src/<domain>.dart`를 만든다.
2. 입력 모델과 로더(`readCsvFile`, `readJsonRecords`) 작성 → 데이터 프로파일 출력.
3. 해(solution) 클래스, `Metric` 목록, `Constraint` 목록, `ParamSpec` 목록, 시나리오 목록 정의.
4. `solve(input, scenario)` 작성. 처음엔 단순 규칙으로.
5. 기존안이 있으면 해 객체로 만들어 `scoreSolution`으로 베이스라인 채점.
6. `runXxx({overrides})` 함수를 만들고 `web_app`의 `runDemo`, `demoParamSpecs` 참조를 교체.
7. 도메인 고유 화면(지도, 시간표 표 등)은 `app.dart`에 섹션으로 추가.
8. demo 파일과 관련 테스트 삭제.

## 플랜 B: Serverpod
사용자가 평소 쓰는 스택이고, 10/31 시험 환경에서도 Serverpod를 썼다(사용자 기억). `scripts/env_check.sh`가 Flutter, IPv6를 통과하면 Serverpod로 가도 된다. 공식 스킬 29개가 기본 설치되어 있다.
아래 세 가지는 IPv6 없는 root 컨테이너(키트 제작 환경)에서 Serverpod 4.1.0으로 직접 겪은 실패다. 시험 환경이 다르면 해당하지 않을 수 있다.

1. **Flutter 필요**: `serverpod` CLI는 서버 전용 프로젝트여도 PATH에 flutter가 없으면 실행을 거부한다.
2. **root 계정**: 기본 설정의 임베디드 PostgreSQL(`database.dataPath`)은 root에서 `initdb: cannot be run as root`로 실패한다. DB가 필요 없으면 `--no-database`로 만든다.
3. **IPv6**: Serverpod 4.1.0은 API 서버와 웹 서버를 `InternetAddress.anyIPv6`로 바인딩한다 (설정 불가). IPv6가 없는 컨테이너에서는 `Address family not supported`로 시작 실패. 이 경우 플랜 A로 간다.

생성 명령 (서버 전용, DB 없음, Codex 스킬 설치):
```
serverpod create ops -t server --no-database --no-redis --no-auth --website --ide codex --no-interactive
```
`ops_core` 연동: `ops_server/pubspec.yaml`에 `ops_core: {path: ../../core}` 추가 후 엔드포인트 작성.
```dart
class EvaluateEndpoint extends Endpoint {
  Future<String> run(Session session, Map<String, double> overrides) async {
    final clamped = <String, num>{
      for (final p in demoParamSpecs)
        if (overrides[p.key] case final v?) p.key: p.clamp(v),
    };
    return jsonEncode(runDemo(overrides: clamped).toJson());
  }
}
```
그 뒤 `serverpod generate`. 이 프로젝트가 만든 `AGENTS.md`와 `.agents/skills/serverpod-*`는 Serverpod 공식 가이드이므로 따로 스킬을 내려받을 필요 없다.
