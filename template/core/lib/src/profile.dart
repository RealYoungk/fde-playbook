/// 데이터 품질 점검. 시험에서 "AI 결과를 그대로 믿지 않고 데이터를 확인했다"는 근거를 남기는 용도.
class ColumnProfile {
  ColumnProfile(this.name);
  final String name;
  int count = 0;
  int blank = 0;
  int numeric = 0;
  double? min;
  double? max;
  final Map<String, int> freq = {};

  int get distinct => freq.length;
  double get blankRate => count == 0 ? 0 : blank / count;
  bool get looksNumeric => count - blank > 0 && numeric == count - blank;

  List<MapEntry<String, int>> top([int n = 3]) {
    final e = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.take(n).toList();
  }
}

class DataProfile {
  DataProfile(this.name, this.rowCount, this.columns, this.duplicateRows);
  final String name;
  final int rowCount;
  final List<ColumnProfile> columns;
  final int duplicateRows;

  /// 결측률이 높거나, 숫자 컬럼인데 범위가 이상한 등 사람이 봐야 할 항목.
  List<String> warnings({double blankThreshold = 0.05}) => [
    if (duplicateRows > 0) '완전 중복 행 $duplicateRows개',
    for (final c in columns)
      if (c.blankRate > blankThreshold)
        '${c.name}: 결측 ${(c.blankRate * 100).toStringAsFixed(1)}%',
    for (final c in columns)
      if (!c.looksNumeric && c.numeric > 0 && c.numeric < c.count - c.blank)
        '${c.name}: 숫자/문자 혼재 (숫자 ${c.numeric} / 값 ${c.count - c.blank})',
  ];

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('### 데이터 프로파일: $name')
      ..writeln('- 행 수: $rowCount, 완전 중복 행: $duplicateRows')
      ..writeln()
      ..writeln('| 컬럼 | 결측률 | 고유값 | 타입 | 범위/최빈값 |')
      ..writeln('|---|---|---|---|---|');
    for (final c in columns) {
      final range = c.looksNumeric
          ? '${_fmt(c.min)} ~ ${_fmt(c.max)}'
          : c.top().map((e) => '${e.key}(${e.value})').join(', ');
      b.writeln(
        '| ${c.name} | ${(c.blankRate * 100).toStringAsFixed(1)}% | ${c.distinct} '
        '| ${c.looksNumeric ? '숫자' : '문자'} | $range |',
      );
    }
    final w = warnings();
    if (w.isNotEmpty) {
      b
        ..writeln()
        ..writeln('**확인 필요**');
      for (final x in w) {
        b.writeln('- $x');
      }
    }
    return b.toString();
  }

  static String _fmt(double? v) => v == null ? '-' : v.toStringAsFixed(3);
}

DataProfile profileRows(String name, List<Map<String, Object?>> rows) {
  final cols = <String, ColumnProfile>{};
  final seen = <String>{};
  var dup = 0;
  for (final r in rows) {
    final key = r.values.join('\u0001');
    if (!seen.add(key)) dup++;
    for (final e in r.entries) {
      final c = cols.putIfAbsent(e.key, () => ColumnProfile(e.key));
      c.count++;
      final s = e.value?.toString().trim() ?? '';
      if (s.isEmpty) {
        c.blank++;
        continue;
      }
      c.freq[s] = (c.freq[s] ?? 0) + 1;
      final d = double.tryParse(s);
      if (d != null) {
        c.numeric++;
        c.min = c.min == null || d < c.min! ? d : c.min;
        c.max = c.max == null || d > c.max! ? d : c.max;
      }
    }
  }
  return DataProfile(name, rows.length, cols.values.toList(), dup);
}
