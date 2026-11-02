/// 범용 탐욕적 최대 커버리지(Max Coverage) 선택.
///
/// "후보 중 몇 개를 골라 수요를 최대한 덮는다" 형태의 문제(거점, 사물함, 점검 지점 등)에 공통으로 쓰인다.
/// 근사 비율 (1 - 1/e)이 보장되는 표준 휴리스틱이라 설명하기 쉽다.
///
/// - [covers]: 후보 c가 수요 d를 덮는지
/// - [weightOf]: 수요 가중치 (예: 인원수, 이용 빈도)
/// - [maxPicks]: 최대 선택 개수 (비용 제약)
/// - [targetCoverage]: 가중 커버율이 이 값에 도달하면 조기 종료 (0~1)
/// - [pickCost]: 후보별 비용. 주면 "커버 증가량 / 비용" 기준으로 고른다.
class CoverageResult<C> {
  CoverageResult(this.picked, this.coveredWeight, this.totalWeight, this.steps);
  final List<C> picked;
  final double coveredWeight;
  final double totalWeight;

  /// 선택 순서별 누적 커버율. 한계효용 체감 그래프나 "몇 개가 적당한가" 논의에 쓴다.
  final List<double> steps;
  double get coverageRate => totalWeight == 0 ? 0 : coveredWeight / totalWeight;
}

CoverageResult<C> greedyMaxCoverage<C, D>({
  required List<C> candidates,
  required List<D> demands,
  required bool Function(C c, D d) covers,
  double Function(D d)? weightOf,
  int? maxPicks,
  double? targetCoverage,
  double Function(C c)? pickCost,
}) {
  final w = [for (final d in demands) weightOf?.call(d) ?? 1.0];
  final total = w.fold<double>(0, (a, b) => a + b);
  // 후보별로 덮는 수요 인덱스를 미리 계산 (O(C*D) 한 번)
  final coverSets = [
    for (final c in candidates)
      {
        for (var i = 0; i < demands.length; i++)
          if (covers(c, demands[i])) i,
      },
  ];
  final covered = <int>{};
  final pickedIdx = <int>[];
  final steps = <double>[];
  var coveredW = 0.0;
  final limit = maxPicks ?? candidates.length;

  while (pickedIdx.length < limit) {
    if (targetCoverage != null &&
        total > 0 &&
        coveredW / total >= targetCoverage)
      break;
    var best = -1;
    var bestScore = 0.0;
    for (var ci = 0; ci < candidates.length; ci++) {
      if (pickedIdx.contains(ci)) continue;
      var gain = 0.0;
      for (final di in coverSets[ci]) {
        if (!covered.contains(di)) gain += w[di];
      }
      final cost = pickCost?.call(candidates[ci]) ?? 1.0;
      final score = cost <= 0 ? gain : gain / cost;
      if (score > bestScore) {
        bestScore = score;
        best = ci;
      }
    }
    if (best < 0) break; // 더 덮을 수요 없음
    pickedIdx.add(best);
    for (final di in coverSets[best]) {
      if (covered.add(di)) coveredW += w[di];
    }
    steps.add(total == 0 ? 0 : coveredW / total);
  }
  return CoverageResult(
    [for (final i in pickedIdx) candidates[i]],
    coveredW,
    total,
    steps,
  );
}
