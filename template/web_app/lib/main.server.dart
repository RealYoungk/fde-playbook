/// 서버 진입점. Jaspr 서버 렌더링 페이지(/)와 JSON API(/api/*)를 한 프로세스에서 제공한다.
///
/// 실행: `jaspr serve` (개발, 핫리로드). 포트 8080, IPv4.
/// 엔진: ?engine=dart (기본, ops_core) | ?engine=python (opt_kit CLI 호출, MIP)
library;

import 'dart:convert';
import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:ops_core/ops_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'app.dart';
import 'main.server.options.dart';

/// 쿼리스트링에서 파라미터 오버라이드를 읽는다. 범위를 벗어나면 잘라낸다.
Map<String, num> parseOverrides(Map<String, String> q) => {
  for (final p in demoParamSpecs)
    if (num.tryParse(q[p.key] ?? '') case final v?) p.key: p.clamp(v),
};

/// Python opt_kit 위치. 환경변수로 바꿀 수 있다.
final analysisDir = Platform.environment['OPT_KIT_DIR'] ?? '../analysis';
final dataDir = Platform.environment['DATA_DIR'] ?? '../data';

class EngineResult {
  EngineResult(this.report, this.engine, [this.error]);
  final EvaluationReport<Object?> report;
  final String engine;
  final String? error;
}

/// Dart 엔진 결과도 JSON을 한 번 거쳐 Python과 같은 경로(fromJson)로 화면에 전달한다.
EvaluationReport<Object?> _dart(Map<String, num> overrides) => EvaluationReport.fromJson(
  jsonDecode(jsonEncode(runDemo(overrides: overrides).toJson())) as Map<String, dynamic>,
);

/// 같은 입력을 Dart 또는 Python 엔진으로 계산한다. Python이 실패하면 Dart로 대체하고 오류를 남긴다.
Future<EngineResult> evaluate(String engine, Map<String, num> overrides) async {
  if (engine == 'python') {
    try {
      final r = await Process.run(
        'python3',
        [
          '-m',
          'opt_kit',
          'demo',
          '--data',
          Directory(dataDir).absolute.path,
          '--params',
          jsonEncode(overrides),
        ],
        workingDirectory: analysisDir,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (r.exitCode != 0) throw StateError((r.stderr as String).trim());
      final json = jsonDecode(r.stdout as String) as Map<String, dynamic>;
      return EngineResult(EvaluationReport.fromJson(json), 'python');
    } catch (e) {
      return EngineResult(_dart(overrides), 'dart', 'Python 엔진 실패, Dart로 대체: $e');
    }
  }
  return EngineResult(_dart(overrides), 'dart');
}

Response _json(Object? body) => Response.ok(
  const JsonEncoder.withIndent('  ').convert(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() async {
  Jaspr.initializeApp(options: defaultServerOptions);

  final router = Router()
    ..get('/api/health', (Request r) => _json({'ok': true}))
    // 화면과 같은 계산을 JSON으로. 평가자나 담당자가 수치를 직접 확인할 수 있게.
    ..get('/api/evaluate', (Request r) async {
      final q = r.url.queryParameters;
      final res = await evaluate(q['engine'] ?? 'dart', parseOverrides(q));
      return _json({...res.report.toJson(), 'engine': res.engine, 'error': res.error});
    })
    // README나 서술형에 그대로 붙일 수 있는 비교표
    ..get('/api/report.md', (Request r) async {
      final q = r.url.queryParameters;
      final res = await evaluate(q['engine'] ?? 'dart', parseOverrides(q));
      return Response.ok(
        res.report.toMarkdown(),
        headers: {'content-type': 'text/markdown; charset=utf-8'},
      );
    })
    ..mount(
      '/',
      serveApp((request, render) async {
        final q = request.url.queryParameters;
        final overrides = parseOverrides(q);
        final res = await evaluate(q['engine'] ?? 'dart', overrides);
        return render(
          Document(
            title: '시나리오 비교',
            lang: 'ko',
            meta: {'theme-color': '#f7f6f3'},
            head: [link(rel: 'stylesheet', href: '/styles.css')],
            body: App(
              report: res.report,
              overrides: overrides,
              engine: res.engine,
              view: q['view'],
              error: res.error,
              query: q,
            ),
          ),
        );
      }),
    );

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final reloadLock = activeReloadLock = Object();
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port, shared: true);

  if (reloadLock != activeReloadLock) {
    server.close();
    return;
  }
  activeServer?.close();
  activeServer = server;
  print('Serving at http://${server.address.host}:${server.port}');
}

HttpServer? activeServer;
Object? activeReloadLock;
