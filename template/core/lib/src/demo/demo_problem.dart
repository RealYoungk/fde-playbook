// =====================================================================
// DEMO 전용. 시험에서는 이 파일을 실제 과제 도메인으로 교체한다.
// 하네스(지표/제약/시나리오/베이스라인 비교)가 끝까지 도는지 보여주는 예시일 뿐이다.
// 도메인: "가상의 픽업 거점 선정" (합성 데이터)
// =====================================================================
import 'dart:math' as math;

import '../coverage.dart';
import '../evaluation.dart';
import '../geo.dart';
import '../scenario.dart';

class DemoDemand {
  const DemoDemand(this.id, this.pos, this.weight);
  final String id;
  final LatLng pos;
  final double weight;
}

class DemoSite {
  const DemoSite(this.id, this.pos);
  final String id;
  final LatLng pos;
}

class DemoInput {
  DemoInput(this.demands, this.candidates, this.existing);
  final List<DemoDemand> demands;
  final List<DemoSite> candidates;
  final List<DemoSite> existing;

  /// 고정 시드 합성 데이터. 결과가 매번 같아야 비교가 된다.
  factory DemoInput.synthetic({int seed = 42}) {
    final r = math.Random(seed);
    const base = LatLng(37.5, 127.0);
    final clusters = [
      const LatLng(0.00, 0.00),
      const LatLng(0.03, 0.02),
      const LatLng(-0.02, 0.035),
    ];
    final demands = <DemoDemand>[];
    for (var i = 0; i < 300; i++) {
      final c = clusters[i % clusters.length];
      demands.add(
        DemoDemand(
          'd$i',
          LatLng(
            base.lat + c.lat + (r.nextDouble() - 0.5) * 0.02,
            base.lng + c.lng + (r.nextDouble() - 0.5) * 0.02,
          ),
          1 + r.nextInt(3).toDouble(),
        ),
      );
    }
    final cands = <DemoSite>[];
    for (var x = 0; x < 12; x++) {
      for (var y = 0; y < 12; y++) {
        cands.add(
          DemoSite(
            'c${x}_$y',
            LatLng(base.lat - 0.035 + x * 0.006, base.lng - 0.015 + y * 0.006),
          ),
        );
      }
    }
    // "기존 운영안": 오래돼서 수요 분포와 어긋난 거점 4개
    final existing = [cands[0], cands[30], cands[77], cands[140]];
    return DemoInput(demands, cands, existing);
  }
}

class DemoSolution {
  DemoSolution(this.input, this.sites, {this.budget});
  final DemoInput input;
  final List<DemoSite> sites;
  final int? budget;

  late final List<double> nearestWalkMin = [
    for (final d in input.demands)
      sites.isEmpty
          ? double.infinity
          : sites
                .map((s) => walkMinutes(haversineKm(d.pos, s.pos)))
                .reduce(math.min),
  ];

  double weightedShareWithin(double minutes) {
    var cov = 0.0, tot = 0.0;
    for (var i = 0; i < input.demands.length; i++) {
      tot += input.demands[i].weight;
      if (nearestWalkMin[i] <= minutes) cov += input.demands[i].weight;
    }
    return tot == 0 ? 0 : cov / tot * 100;
  }
}

const demoParamSpecs = [
  ParamSpec(
    'walkLimit',
    '도보 허용 한계',
    min: 5,
    max: 20,
    step: 1,
    defaultValue: 10,
    unit: '분',
    help: '담당자 발언 기준으로 설정. 이 시간 안이면 "덮였다"고 본다.',
  ),
  ParamSpec(
    'maxSites',
    '최대 거점 수',
    min: 1,
    max: 20,
    step: 1,
    defaultValue: 8,
    unit: '개',
    help: '비용 제약. 재무 관점에서 상한.',
  ),
  ParamSpec(
    'targetCoverage',
    '목표 커버율',
    min: 50,
    max: 100,
    step: 5,
    defaultValue: 100,
    unit: '%',
    help: '도달하면 더 늘리지 않는다. 100이면 상한까지 채움.',
  ),
];

final demoScenarios = [
  const Scenario(
    id: 'access',
    label: '접근성 우선',
    description: '이용률, 민원 최소화 관점',
    params: {'walkLimit': 10, 'maxSites': 12, 'targetCoverage': 100},
  ),
  const Scenario(
    id: 'cost',
    label: '비용 우선',
    description: '운영 비용 최소화 관점',
    params: {'walkLimit': 15, 'maxSites': 5, 'targetCoverage': 100},
  ),
  const Scenario(
    id: 'balanced',
    label: '균형',
    description: '커버율 70%에서 멈춤',
    params: {'walkLimit': 10, 'maxSites': 10, 'targetCoverage': 70},
  ),
];

final demoMetrics = <Metric<DemoSolution>>[
  Metric(
    key: 'cov10',
    label: '10분 이내 비율',
    unit: '%',
    stakeholder: 'HR',
    compute: (s) => s.weightedShareWithin(10),
  ),
  Metric(
    key: 'cov15',
    label: '15분 이내 비율',
    unit: '%',
    stakeholder: 'HR',
    compute: (s) => s.weightedShareWithin(15),
  ),
  Metric(
    key: 'avgWalk',
    label: '평균 도보시간',
    unit: '분',
    higherIsBetter: false,
    stakeholder: '이용자',
    compute: (s) {
      final f = s.nearestWalkMin.where((v) => v.isFinite);
      return f.isEmpty ? 0 : f.reduce((a, b) => a + b) / f.length;
    },
  ),
  Metric(
    key: 'sites',
    label: '거점 수',
    unit: '개',
    higherIsBetter: false,
    stakeholder: '재무',
    decimals: 0,
    compute: (s) => s.sites.length.toDouble(),
  ),
];

final demoConstraints = <Constraint<DemoSolution>>[
  Constraint(
    key: 'budget',
    label: '거점 수 예산 이내',
    source: 'DEMO: 담당자 "많아야 N개" (가정)',
    check: (s) => s.budget != null && s.sites.length > s.budget!
        ? ['거점 ${s.sites.length}개 > 예산 ${s.budget}개']
        : const [],
  ),
  Constraint(
    key: 'noFar',
    label: '도보 20분 초과 수요 없음',
    hard: false,
    source: 'DEMO: 민원 우려 (가정)',
    check: (s) {
      final n = s.nearestWalkMin.where((m) => m > 20).length;
      return n > 0 ? ['20분 초과 수요 $n건'] : const [];
    },
  ),
];

DemoSolution solveDemo(DemoInput input, Scenario sc) {
  final walk = sc.param('walkLimit', 10).toDouble();
  final maxSites = sc.param('maxSites', 8).toInt();
  final target = sc.param('targetCoverage', 100).toDouble() / 100;
  final res = greedyMaxCoverage<DemoSite, DemoDemand>(
    candidates: input.candidates,
    demands: input.demands,
    covers: (c, d) => walkMinutes(haversineKm(c.pos, d.pos)) <= walk,
    weightOf: (d) => d.weight,
    maxPicks: maxSites,
    targetCoverage: target >= 1 ? null : target,
  );
  return DemoSolution(input, res.picked, budget: maxSites);
}

EvaluationReport<DemoSolution> runDemo({
  Map<String, num> overrides = const {},
  int seed = 42,
}) {
  final input = DemoInput.synthetic(seed: seed);
  Map<String, Object?> extras(DemoSolution s) => {
    'engine': 'dart/greedy',
    'sites': [
      for (final x in s.sites) {'id': x.id, 'lat': x.pos.lat, 'lng': x.pos.lng},
    ],
  };
  final baseline = scoreSolution(
    const Scenario(id: 'baseline', label: '기존안'),
    DemoSolution(input, input.existing),
    demoMetrics,
    demoConstraints,
    Duration.zero,
    extras,
  );
  final scenarios = [
    for (final s in demoScenarios) s,
    if (overrides.isNotEmpty)
      Scenario(
        id: 'custom',
        label: '사용자 조정',
        description: '화면에서 조정한 값',
        params: {
          for (final p in demoParamSpecs) p.key: p.defaultValue,
          ...overrides,
        },
      ),
  ];
  return evaluateScenarios(
    scenarios: scenarios,
    solve: (sc) => solveDemo(input, sc),
    metrics: demoMetrics,
    constraints: demoConstraints,
    baseline: baseline,
    extras: extras,
    context: {
      'engine': 'dart/greedy',
      'demands': [
        for (final d in input.demands)
          {'lat': d.pos.lat, 'lng': d.pos.lng, 'w': d.weight},
      ],
    },
  );
}
