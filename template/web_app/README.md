# web_app

ops_core 평가 결과를 보여주는 서버 렌더링 웹 (Jaspr mode: server + shelf).

- 실행: `dart pub get && jaspr serve` 후 http://localhost:8080
- API: `/api/health`, `/api/evaluate?<파라미터>=<값>`, `/api/report.md`
- 화면: `lib/app.dart` / 라우트와 API: `lib/main.server.dart`
- `main.*.options.dart`는 jaspr가 자동 생성하는 파일이다.
