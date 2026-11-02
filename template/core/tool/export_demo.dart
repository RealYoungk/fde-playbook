// DEMO 합성 데이터를 CSV로 내보낸다. Python opt_kit과 같은 데이터로 교차검증하기 위함.
// 실행: dart run tool/export_demo.dart ../data
import 'dart:convert';
import 'dart:io';

import 'package:ops_core/ops_core.dart';

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? '../data' : args.first)
    ..createSync(recursive: true);
  final input = DemoInput.synthetic();
  void write(String name, List<String> lines) =>
      File('${dir.path}/$name').writeAsStringSync('${lines.join('\n')}\n');

  write('demo_demands.csv', [
    'id,lat,lng,weight',
    for (final d in input.demands)
      '${d.id},${d.pos.lat},${d.pos.lng},${d.weight}',
  ]);
  write('demo_candidates.csv', [
    'id,lat,lng',
    for (final c in input.candidates) '${c.id},${c.pos.lat},${c.pos.lng}',
  ]);
  write('demo_existing.csv', ['id', for (final c in input.existing) c.id]);

  // 교차검증용: Dart 탐욕 결과
  final report = runDemo();
  final picks = {
    for (final r in report.results)
      r.scenario.id: [for (final s in r.solution.sites) s.id],
  };
  File(
    '${dir.path}/demo_dart_greedy.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(picks));
  print('wrote ${dir.path}');
}
