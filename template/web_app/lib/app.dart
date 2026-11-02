import 'dart:math' as math;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:ops_core/ops_core.dart';

/// 서버에서만 렌더링되는 전통적인 웹 페이지. 상태는 전부 쿼리스트링에 있다(링크 공유 가능).
/// 화면 구성: 헤더(엔진 전환) → 선택 시나리오 KPI → 지도 + 파라미터 → 비교표 → 제약과 근거
class App extends StatelessComponent {
  const App({
    required this.report,
    required this.overrides,
    required this.engine,
    required this.query,
    this.view,
    this.error,
    super.key,
  });

  final EvaluationReport<Object?> report;
  final Map<String, num> overrides;
  final String engine;
  final Map<String, String> query;
  final String? view;
  final String? error;

  List<ScenarioResult<Object?>> get _cols => [?report.baseline, ...report.results];

  ScenarioResult<Object?> get _selected {
    for (final r in report.results) {
      if (r.scenario.id == view) return r;
    }
    return report.results.first;
  }

  /// 현재 쿼리를 유지한 채 일부만 바꾼 링크
  String _href(Map<String, String?> change) {
    final q = {...query, ...change}..removeWhere((k, v) => v == null || v.isEmpty);
    return q.isEmpty ? '/' : '/?${Uri(queryParameters: q.cast<String, String>()).query}';
  }

  @override
  Component build(BuildContext context) {
    final sel = _selected;
    return div(classes: 'page', [
      header(classes: 'top', [
        div([
          p(classes: 'eyebrow', [.text('운영안 비교')]),
          h1([.text('시나리오 비교')]),
          p(classes: 'sub', [
            .text('기존안 대비 각 안의 지표 변화. 같은 수치를 '),
            a(href: _href({}).replaceFirst('/', '/api/evaluate'), [.text('JSON')]),
            .text(', '),
            a(href: _href({}).replaceFirst('/', '/api/report.md'), [.text('Markdown')]),
            .text('으로도 볼 수 있습니다.'),
          ]),
        ]),
        nav(
          classes: 'seg',
          attributes: {'aria-label': '계산 엔진'},
          [
            _segLink('Dart 탐욕', 'dart'),
            _segLink('Python 최적해', 'python'),
          ],
        ),
      ]),
      if (error != null) div(classes: 'notice bad', attributes: {'role': 'alert'}, [.text(error!)]),

      // 선택 시나리오 요약
      section(classes: 'card', [
        div(classes: 'card-head', [
          h2([.text(sel.scenario.label)]),
          nav(classes: 'tabs', [
            for (final r in report.results)
              a(
                href: _href({'view': r.scenario.id}),
                classes: r == sel ? 'tab on' : 'tab',
                attributes: r == sel ? {'aria-current': 'page'} : null,
                [.text(r.scenario.label)],
              ),
          ]),
        ]),
        if (sel.scenario.description.isNotEmpty) p(classes: 'muted', [.text(sel.scenario.description)]),
        div(classes: 'kpis', [
          for (final m in report.metricDefs) _kpi(sel, m),
          div(classes: 'kpi ${sel.feasible ? '' : 'kpi-bad'}', [
            span(classes: 'kpi-label', [.text('제약 위반')]),
            span(classes: 'kpi-value', [.text('${sel.hardViolations} / ${sel.softViolations}')]),
            span(classes: 'kpi-delta', [.text('필수 / 권고')]),
          ]),
        ]),
      ]),

      div(classes: 'grid2', [
        section(classes: 'card', [
          h2([.text('배치 지도')]),
          _map(sel),
          p(classes: 'legend', [
            span(classes: 'dot demand', []),
            .text('수요'),
            span(classes: 'dot site', []),
            .text('${sel.scenario.label} 거점'),
            span(classes: 'dot base', []),
            .text('기존 거점'),
          ]),
        ]),
        section(classes: 'card', [
          h2([.text('파라미터 조정')]),
          form(action: '/', method: FormMethod.get, classes: 'params', [
            input(type: InputType.hidden, name: 'engine', value: engine),
            input(type: InputType.hidden, name: 'view', value: 'custom'),
            for (final s in demoParamSpecs)
              label(classes: 'param', [
                span(classes: 'pname', [.text(s.label)]),
                div(classes: 'field', [
                  input(
                    type: InputType.number,
                    name: s.key,
                    value: '${overrides[s.key] ?? s.defaultValue}',
                    attributes: {
                      'min': '${s.min}',
                      'max': '${s.max}',
                      'step': '${s.step}',
                      'inputmode': 'numeric',
                    },
                  ),
                  span(classes: 'unit', [.text(s.unit)]),
                ]),
                span(classes: 'help', [.text(s.help)]),
              ]),
            div(classes: 'actions', [
              button(type: ButtonType.submit, [.text('이 값으로 계산')]),
              a(href: _href({for (final s in demoParamSpecs) s.key: null, 'view': null}), classes: 'ghost', [
                .text('초기화'),
              ]),
            ]),
          ]),
        ]),
      ]),

      section(classes: 'card', [
        h2([.text('지표 비교')]),
        div(classes: 'scroll', [
          table([
            thead([
              tr([
                th(attributes: {'scope': 'col'}, [.text('지표')]),
                for (final r in _cols)
                  th(
                    attributes: {'scope': 'col'},
                    classes: r == sel ? 'hl' : null,
                    [
                      .text(r.scenario.label),
                      if (r.scenario.description.isNotEmpty) span(classes: 'desc', [.text(r.scenario.description)]),
                    ],
                  ),
              ]),
            ]),
            tbody([
              for (final m in report.metricDefs)
                tr([
                  th(
                    attributes: {'scope': 'row'},
                    [
                      .text(m.label),
                      span(classes: 'desc', [
                        .text(
                          '${m.higherIsBetter ? '높을수록' : '낮을수록'} 좋음'
                          '${m.stakeholder.isEmpty ? '' : ' · ${m.stakeholder}'}',
                        ),
                      ]),
                    ],
                  ),
                  for (final r in _cols) _cell(r, m, r == sel),
                ]),
              tr([
                th(attributes: {'scope': 'row'}, [.text('제약 위반 (필수/권고)')]),
                for (final r in _cols)
                  td(classes: [r.feasible ? 'ok' : 'bad', if (r == sel) 'hl'].join(' '), [
                    .text('${r.hardViolations} / ${r.softViolations}'),
                  ]),
              ]),
            ]),
          ]),
        ]),
      ]),

      section(classes: 'card', [
        h2([.text('제약과 근거')]),
        ul(classes: 'list', [
          for (final c in report.constraintDefs)
            li([
              span(classes: c.hard ? 'tag hard' : 'tag soft', [.text(c.hard ? '필수' : '권고')]),
              .text(c.label),
              if (c.source.isNotEmpty) span(classes: 'desc', [.text('출처: ${c.source}')]),
            ]),
        ]),
        h3([.text('위반 상세')]),
        if (_cols.every((r) => r.violations.isEmpty))
          p(classes: 'muted', [.text('위반 없음')])
        else
          ul(classes: 'list', [
            for (final r in _cols)
              for (final v in r.violations) li([.text('${r.scenario.label}: ${v.message}')]),
          ]),
        p(classes: 'muted small', [.text('계산 엔진: ${report.context['engine'] ?? engine}')]),
      ]),
    ]);
  }

  Component _segLink(String label, String id) => a(
    href: _href({'engine': id}),
    classes: engine == id ? 'seg-item on' : 'seg-item',
    attributes: engine == id ? {'aria-current': 'true'} : null,
    [.text(label)],
  );

  Component _kpi(ScenarioResult<Object?> r, Metric<Object?> m) {
    final better = report.improved(r, m);
    return div(classes: 'kpi', [
      span(classes: 'kpi-label', [.text(m.label)]),
      span(classes: 'kpi-value', [.text(report.formatValue(m, r.metrics[m.key]))]),
      span(classes: 'kpi-delta ${better == null ? '' : (better ? 'up' : 'down')}', [
        .text(report.baseline == null ? '' : '기존안 대비 ${report.deltaLabel(r, m)}'),
      ]),
    ]);
  }

  Component _cell(ScenarioResult<Object?> r, Metric<Object?> m, bool hl) {
    final isBase = identical(r, report.baseline);
    final better = isBase ? null : report.improved(r, m);
    final cls = [if (better != null) (better ? 'up' : 'down'), if (hl) 'hl'].join(' ');
    return td(classes: cls.isEmpty ? null : cls, [
      .text(report.formatValue(m, r.metrics[m.key])),
      if (!isBase) span(classes: 'delta', [.text(report.deltaLabel(r, m))]),
    ]);
  }

  /// 위경도를 단순 등장방형 투영으로 SVG에 그린다. 지도 타일(외부 CDN) 없이 동작.
  Component _map(ScenarioResult<Object?> sel) {
    List<Map<String, dynamic>> pts(Object? v) =>
        v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
    final demands = pts(report.context['demands']);
    final sites = pts(sel.extras['sites']);
    final base = pts(report.baseline?.extras['sites']);
    final all = [...demands, ...sites, ...base];
    if (all.isEmpty) return p(classes: 'muted', [.text('표시할 좌표가 없습니다.')]);

    double lat(Map<String, dynamic> m) => (m['lat'] as num).toDouble();
    double lng(Map<String, dynamic> m) => (m['lng'] as num).toDouble();
    final minLat = all.map(lat).reduce(math.min), maxLat = all.map(lat).reduce(math.max);
    final minLng = all.map(lng).reduce(math.min), maxLng = all.map(lng).reduce(math.max);
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    const w = 640.0, pad = 24.0;
    final spanX = math.max((maxLng - minLng) * kx, 1e-9), spanY = math.max(maxLat - minLat, 1e-9);
    final scale = (w - 2 * pad) / math.max(spanX, spanY);
    final h = spanY * scale + 2 * pad;
    String x(Map<String, dynamic> m) => (pad + (lng(m) - minLng) * kx * scale).toStringAsFixed(1);
    String y(Map<String, dynamic> m) => (h - pad - (lat(m) - minLat) * scale).toStringAsFixed(1);

    // 도보 허용 한계를 반경으로 (ops_core.walkMinutes의 역산)
    final walk = (sel.scenario.params['walkLimit'] ?? 10).toDouble();
    final radiusDeg = walk * 4.5 / 60 / 1.3 / 111.0;
    final r = (radiusDeg * scale).toStringAsFixed(1);

    return svg(
      viewBox: '0 0 $w ${h.toStringAsFixed(0)}',
      classes: 'map',
      attributes: {'role': 'img', 'aria-label': '${sel.scenario.label} 거점 배치 지도'},
      [
        for (final s in sites) circle(cx: x(s), cy: y(s), r: r, classes: 'reach', []),
        for (final d in demands)
          circle(cx: x(d), cy: y(d), r: '${1.5 + ((d['w'] as num?) ?? 1).toDouble()}', classes: 'demand', []),
        for (final b in base) circle(cx: x(b), cy: y(b), r: '6', classes: 'base', []),
        for (final s in sites) circle(cx: x(s), cy: y(s), r: '5', classes: 'site', []),
      ],
    );
  }
}
