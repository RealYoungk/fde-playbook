import 'dart:convert';

import 'package:ops_core/ops_core.dart';
import 'package:test/test.dart';

void main() {
  group('csv', () {
    test('따옴표, 쉼표, 줄바꿈, BOM 없는 헤더', () {
      final rows = parseCsv('id,name,memo\n1,"Kim, Y","a ""b""\nc"\n2,Lee,\n');
      expect(rows.length, 2);
      expect(rows[0]['name'], 'Kim, Y');
      expect(rows[0]['memo'], 'a "b"\nc');
      expect(rows[1]['memo'], '');
    });
  });

  group('profile', () {
    test('결측, 중복, 혼재 경고', () {
      final p = profileRows('t', [
        {'a': '1', 'b': 'x'},
        {'a': '1', 'b': 'x'},
        {'a': 'abc', 'b': ''},
      ]);
      final w = p.warnings();
      expect(w.any((x) => x.contains('중복')), isTrue);
      expect(w.any((x) => x.startsWith('b: 결측')), isTrue);
      expect(w.any((x) => x.contains('혼재')), isTrue);
    });
  });

  group('validate', () {
    test('필수, 숫자 범위, 허용값, 시각, 키 중복', () {
      final rows = parseCsv(
        'id,lat,shift,start\n'
        '1,37.5,주간,08:30\n'
        '2,,야간,8:00\n'
        '3,99,주간,25:00\n'
        '1,37.6,교대,09:00\n'
        '4,37.4,오전,09:00\n',
      );
      final r = validateRows(rows, [
        RowRule.required('id'),
        RowRule.number('lat', min: 33, max: 39),
        RowRule.oneOf('shift', {'주간', '야간', '교대'}),
        RowRule.time('start'),
      ], keyColumn: 'id');
      expect(r.total, 5);
      expect(r.validRows.map((e) => e['id']), ['1']);
      expect(r.duplicateKeys, {'1': 2});
      expect(r.issues.where((i) => i.rowNumber == 3).single.message, '비어 있음');
      expect(
        r.issues.any((i) => i.rowNumber == 4 && i.column == 'start'),
        isTrue,
      );
      expect(
        r.issues.any((i) => i.rowNumber == 6 && i.column == 'shift'),
        isTrue,
      );
      expect(r.toMarkdown(), contains('제외 4행'));
    });
  });

  group('geo', () {
    test('위도 0.01도는 약 1.11km', () {
      final km = haversineKm(const LatLng(37.5, 127), const LatLng(37.51, 127));
      expect(km, closeTo(1.11, 0.01));
    });
  });

  group('coverage', () {
    test('탐욕 선택이 큰 덩어리부터 고른다', () {
      final res = greedyMaxCoverage<int, int>(
        candidates: [0, 1, 2],
        demands: [10, 11, 12, 20, 30],
        covers: (c, d) =>
            (c == 0 && d < 20) || (c == 1 && d == 20) || (c == 2 && d == 30),
        maxPicks: 2,
      );
      expect(res.picked.first, 0);
      expect(res.picked.length, 2);
      expect(res.coverageRate, closeTo(0.8, 1e-9));
    });
  });

  group('demo harness', () {
    test('베이스라인 대비 비교와 제약 검사가 돈다', () {
      final report = runDemo();
      expect(report.baseline, isNotNull);
      expect(report.results.length, demoScenarios.length);
      final access = report.results.firstWhere(
        (r) => r.scenario.id == 'access',
      );
      // 수요에 맞춰 재배치하면 기존안보다 10분 커버율이 좋아져야 한다
      expect(
        access.metrics['cov10']!,
        greaterThan(report.baseline!.metrics['cov10']!),
      );
      expect(access.feasible, isTrue);
      expect(report.toMarkdown(), contains('기존안'));
    });

    test('JSON 왕복: toJson -> fromJson 후 표와 수치가 같다', () {
      final report = runDemo();
      final back = EvaluationReport.fromJson(
        jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>,
      );
      expect(back.toMarkdown(), report.toMarkdown());
      expect(
        (back.results.first.extras['sites'] as List).length,
        report.results.first.solution.sites.length,
      );
      expect((back.context['demands'] as List).length, 300);
    });

    test('사용자 조정 시나리오 추가', () {
      final report = runDemo(overrides: {'maxSites': 3});
      final custom = report.results.last;
      expect(custom.scenario.id, 'custom');
      expect(custom.metrics['sites'], lessThanOrEqualTo(3));
    });
  });
}
