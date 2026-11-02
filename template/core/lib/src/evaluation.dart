import 'scenario.dart';

/// 해(solution)에서 숫자 하나를 뽑는 지표.
/// [higherIsBetter]로 베이스라인 대비 개선/악화 방향을 판단한다.
class Metric<S> {
  const Metric({
    required this.key,
    required this.label,
    required this.compute,
    this.unit = '',
    this.higherIsBetter = true,
    this.stakeholder = '',
    this.decimals = 1,
    bool? absoluteDelta,
  }) : _absoluteDelta = absoluteDelta;

  final String key;
  final String label;
  final String unit;
  final bool higherIsBetter;

  /// 이 지표를 중요하게 보는 이해관계자 (예: HR, 재무, 현장). 서술형 설명용.
  final String stakeholder;
  final int decimals;
  final double Function(S solution) compute;
  final bool? _absoluteDelta;

  /// 베이스라인 대비 차이를 절대값(%p 등)으로 볼지. 기본: 단위가 '%'면 절대값.
  bool get absoluteDelta => _absoluteDelta ?? unit == '%';
}

class Violation {
  const Violation(this.constraintKey, this.message, {this.hard = true});
  final String constraintKey;
  final String message;
  final bool hard;

  Map<String, Object> toJson() => {
    'constraint': constraintKey,
    'message': message,
    'hard': hard,
  };
}

/// 반드시 지켜야 하는(hard) 또는 가급적 지켜야 하는(soft) 조건.
/// 출처(담당자 발언, README 조항 번호)를 [source]에 남겨 두면 서술형에서 근거로 쓴다.
class Constraint<S> {
  const Constraint({
    required this.key,
    required this.label,
    required this.check,
    this.hard = true,
    this.source = '',
  });

  final String key;
  final String label;
  final bool hard;
  final String source;
  final List<String> Function(S solution) check;

  List<Violation> evaluate(S s) => [
    for (final m in check(s)) Violation(key, m, hard: hard),
  ];
}

class ScenarioResult<S> {
  ScenarioResult(
    this.scenario,
    this.solution,
    this.metrics,
    this.violations,
    this.elapsed, {
    this.extras = const {},
  });
  final Scenario scenario;
  final S solution;
  final Map<String, double> metrics;
  final List<Violation> violations;
  final Duration elapsed;

  /// 화면에 그릴 추가 정보 (JSON 직렬화 가능해야 함). 예: {'sites': [{'id','lat','lng'}]}
  final Map<String, Object?> extras;

  int get hardViolations => violations.where((v) => v.hard).length;
  int get softViolations => violations.where((v) => !v.hard).length;
  bool get feasible => hardViolations == 0;
}

class EvaluationReport<S> {
  EvaluationReport({
    required this.metricDefs,
    required this.constraintDefs,
    required this.results,
    this.baseline,
    this.context = const {},
  });

  /// 시나리오 공통 정보 (JSON 직렬화 가능). 예: {'engine': 'dart/greedy', 'demands': [...]}
  final Map<String, Object?> context;

  /// Python opt_kit 등 외부 엔진이 낸 JSON을 같은 화면으로 그리기 위한 로더.
  /// 지표 계산 함수는 없고 값만 있는 보고서가 된다.
  static EvaluationReport<Object?> fromJson(Map<String, dynamic> j) {
    final metrics = [
      for (final m in (j['metrics'] as List).cast<Map<String, dynamic>>())
        Metric<Object?>(
          key: m['key'] as String,
          label: m['label'] as String,
          unit: (m['unit'] ?? '') as String,
          higherIsBetter: (m['higherIsBetter'] ?? true) as bool,
          stakeholder: (m['stakeholder'] ?? '') as String,
          decimals: (m['decimals'] ?? 1) as int,
          compute: (_) => double.nan,
        ),
    ];
    final constraints = [
      for (final c in (j['constraints'] as List).cast<Map<String, dynamic>>())
        Constraint<Object?>(
          key: c['key'] as String,
          label: c['label'] as String,
          hard: (c['hard'] ?? true) as bool,
          source: (c['source'] ?? '') as String,
          check: (_) => const [],
        ),
    ];
    ScenarioResult<Object?> res(Map<String, dynamic> r) {
      final sc = r['scenario'] as Map<String, dynamic>;
      return ScenarioResult<Object?>(
        Scenario(
          id: sc['id'] as String,
          label: sc['label'] as String,
          description: (sc['description'] ?? '') as String,
          params: {
            for (final e in ((sc['params'] ?? {}) as Map).entries)
              e.key as String: e.value as num,
          },
        ),
        null,
        {
          for (final e in (r['metrics'] as Map).entries)
            e.key as String: (e.value as num).toDouble(),
        },
        [
          for (final v
              in ((r['violations'] ?? []) as List).cast<Map<String, dynamic>>())
            Violation(
              v['constraint'] as String,
              v['message'] as String,
              hard: (v['hard'] ?? true) as bool,
            ),
        ],
        Duration(milliseconds: (r['elapsedMs'] ?? 0) as int),
        extras: ((r['extras'] ?? {}) as Map).cast<String, Object?>(),
      );
    }

    final base = j['baseline'];
    return EvaluationReport<Object?>(
      metricDefs: metrics,
      constraintDefs: constraints,
      baseline: base == null ? null : res(base as Map<String, dynamic>),
      results: [
        for (final r in (j['results'] as List).cast<Map<String, dynamic>>())
          res(r),
      ],
      context: ((j['context'] ?? {}) as Map).cast<String, Object?>(),
    );
  }

  final List<Metric<S>> metricDefs;
  final List<Constraint<S>> constraintDefs;
  final List<ScenarioResult<S>> results;
  final ScenarioResult<S>? baseline;

  /// 베이스라인 대비 차이. [Metric.absoluteDelta]면 단순 차이, 아니면 변화율(%).
  double? delta(ScenarioResult<S> r, Metric<S> m) {
    final b = baseline?.metrics[m.key];
    final v = r.metrics[m.key];
    if (b == null || v == null) return null;
    if (m.absoluteDelta) return v - b;
    if (b == 0) return null;
    return (v - b) / b.abs() * 100;
  }

  /// 개선이면 true, 악화면 false, 비교 불가면 null.
  bool? improved(ScenarioResult<S> r, Metric<S> m) {
    final d = delta(r, m);
    if (d == null || d.abs() < 1e-9) return null;
    return m.higherIsBetter ? d > 0 : d < 0;
  }

  String deltaLabel(ScenarioResult<S> r, Metric<S> m) {
    final d = delta(r, m);
    if (d == null) return '';
    final sign = d >= 0 ? '+' : '';
    final suffix = m.absoluteDelta ? (m.unit == '%' ? '%p' : m.unit) : '%';
    return '$sign${d.toStringAsFixed(1)}$suffix';
  }

  String formatValue(Metric<S> m, double? v) =>
      v == null ? '-' : '${v.toStringAsFixed(m.decimals)}${m.unit}';

  /// README나 서술형에 붙일 비교표.
  String toMarkdown() {
    final all = [?baseline, ...results];
    final b = StringBuffer()
      ..writeln('| 지표 | ${all.map((r) => r.scenario.label).join(' | ')} |')
      ..writeln('|---|${List.filled(all.length, '---').join('|')}|');
    for (final m in metricDefs) {
      final cells = [
        for (final r in all)
          r == baseline
              ? formatValue(m, r.metrics[m.key])
              : '${formatValue(m, r.metrics[m.key])}${_deltaText(r, m)}',
      ];
      b.writeln('| ${m.label} | ${cells.join(' | ')} |');
    }
    b.writeln(
      '| 제약 위반 (hard/soft) | ${all.map((r) => '${r.hardViolations}/${r.softViolations}').join(' | ')} |',
    );
    return b.toString();
  }

  String _deltaText(ScenarioResult<S> r, Metric<S> m) {
    final t = deltaLabel(r, m);
    return t.isEmpty ? '' : ' ($t)';
  }

  Map<String, Object?> toJson() {
    Map<String, Object?> res(ScenarioResult<S> r) => {
      'scenario': r.scenario.toJson(),
      'metrics': r.metrics,
      'feasible': r.feasible,
      'violations': r.violations.map((v) => v.toJson()).toList(),
      'elapsedMs': r.elapsed.inMilliseconds,
      'extras': r.extras,
      if (baseline != null && r != baseline)
        'delta': {for (final m in metricDefs) m.key: delta(r, m)},
    };
    return {
      'metrics': [
        for (final m in metricDefs)
          {
            'key': m.key,
            'label': m.label,
            'unit': m.unit,
            'higherIsBetter': m.higherIsBetter,
            'stakeholder': m.stakeholder,
            'decimals': m.decimals,
          },
      ],
      'constraints': [
        for (final c in constraintDefs)
          {'key': c.key, 'label': c.label, 'hard': c.hard, 'source': c.source},
      ],
      'baseline': baseline == null ? null : res(baseline!),
      'results': results.map(res).toList(),
      'context': context,
    };
  }
}

ScenarioResult<S> runScenario<S>(
  Scenario scenario,
  S Function(Scenario) solve,
  List<Metric<S>> metrics,
  List<Constraint<S>> constraints, {
  Map<String, Object?> Function(S)? extras,
}) {
  final sw = Stopwatch()..start();
  final s = solve(scenario);
  sw.stop();
  return scoreSolution(scenario, s, metrics, constraints, sw.elapsed, extras);
}

/// 이미 있는 해(예: 기존 운영안)를 같은 잣대로 채점. 베이스라인 만들 때 사용.
ScenarioResult<S> scoreSolution<S>(
  Scenario scenario,
  S solution,
  List<Metric<S>> metrics,
  List<Constraint<S>> constraints, [
  Duration elapsed = Duration.zero,
  Map<String, Object?> Function(S)? extras,
]) => ScenarioResult(
  scenario,
  solution,
  {for (final m in metrics) m.key: m.compute(solution)},
  [for (final c in constraints) ...c.evaluate(solution)],
  elapsed,
  extras: extras?.call(solution) ?? const {},
);

EvaluationReport<S> evaluateScenarios<S>({
  required List<Scenario> scenarios,
  required S Function(Scenario) solve,
  required List<Metric<S>> metrics,
  List<Constraint<S>> constraints = const [],
  ScenarioResult<S>? baseline,
  Map<String, Object?> Function(S)? extras,
  Map<String, Object?> context = const {},
}) => EvaluationReport(
  metricDefs: metrics,
  constraintDefs: constraints,
  baseline: baseline,
  context: context,
  results: [
    for (final sc in scenarios)
      runScenario(sc, solve, metrics, constraints, extras: extras),
  ],
);
