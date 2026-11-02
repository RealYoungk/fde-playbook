/// 입력 행 검증. 잘못된 행을 조용히 버리지 않고 "몇 행이 왜 빠졌는지" 보고하기 위한 도구.
class RowRule {
  RowRule._(this.column, this.label, this._check);
  final String column;
  final String label;
  final String? Function(String value) _check;

  /// 값이 비어 있으면 실패.
  factory RowRule.required(String column) =>
      RowRule._(column, '$column 필수', (v) => v.trim().isEmpty ? '비어 있음' : null);

  /// 숫자여야 하고, 범위가 주어지면 그 안이어야 한다. 빈 값은 [allowBlank]면 통과.
  factory RowRule.number(
    String column, {
    num? min,
    num? max,
    bool allowBlank = false,
  }) => RowRule._(
    column,
    '$column 숫자${min != null || max != null ? ' [${min ?? ''}, ${max ?? ''}]' : ''}',
    (v) {
      final s = v.trim().replaceAll(',', '');
      if (s.isEmpty) return allowBlank ? null : '비어 있음';
      final n = num.tryParse(s);
      if (n == null) return '숫자 아님: "$v"';
      if (min != null && n < min) return '최소값 미만: $n < $min';
      if (max != null && n > max) return '최대값 초과: $n > $max';
      return null;
    },
  );

  /// 허용된 값 중 하나여야 한다.
  factory RowRule.oneOf(
    String column,
    Set<String> allowed, {
    bool allowBlank = false,
  }) => RowRule._(column, '$column ∈ {${allowed.join(', ')}}', (v) {
    final s = v.trim();
    if (s.isEmpty) return allowBlank ? null : '비어 있음';
    return allowed.contains(s) ? null : '허용되지 않은 값: "$v"';
  });

  /// "HH:mm" 시각 형식.
  factory RowRule.time(String column, {bool allowBlank = false}) =>
      RowRule._(column, '$column 시각(HH:mm)', (v) {
        final s = v.trim();
        if (s.isEmpty) return allowBlank ? null : '비어 있음';
        final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
        if (m == null) return '시각 형식 아님: "$v"';
        final h = int.parse(m[1]!), mi = int.parse(m[2]!);
        return h < 24 && mi < 60 ? null : '시각 범위 오류: "$v"';
      });

  /// 임의 규칙. 실패 메시지를 반환하면 실패.
  factory RowRule.custom(
    String column,
    String label,
    String? Function(String value) check,
  ) => RowRule._(column, label, check);

  String? check(Map<String, String> row) {
    if (!row.containsKey(column)) return '컬럼 없음';
    return _check(row[column]!);
  }
}

class RowIssue {
  RowIssue(this.rowNumber, this.column, this.message, {this.key});

  /// 헤더를 1행으로 볼 때의 파일 행 번호 (데이터 첫 행 = 2)
  final int rowNumber;
  final String column;
  final String message;
  final String? key;

  @override
  String toString() =>
      '${rowNumber}행${key == null ? '' : ' ($key)'} $column: $message';
}

class ValidationReport {
  ValidationReport(this.total, this.validRows, this.issues, this.duplicateKeys);
  final int total;
  final List<Map<String, String>> validRows;
  final List<RowIssue> issues;
  final Map<String, int> duplicateKeys;

  int get invalidCount => total - validRows.length;

  String toMarkdown({int maxIssues = 20}) {
    final byColumn = <String, int>{};
    for (final i in issues) {
      byColumn[i.column] = (byColumn[i.column] ?? 0) + 1;
    }
    final b = StringBuffer()
      ..writeln('### 입력 검증')
      ..writeln('- 전체 $total행, 통과 ${validRows.length}행, 제외 $invalidCount행')
      ..writeln(
        '- 키 중복: ${duplicateKeys.isEmpty ? '없음' : duplicateKeys.entries.map((e) => '${e.key}(${e.value}회)').take(10).join(', ')}',
      );
    if (byColumn.isNotEmpty) {
      b.writeln(
        '- 컬럼별 문제: ${byColumn.entries.map((e) => '${e.key} ${e.value}건').join(', ')}',
      );
      b.writeln();
      for (final i in issues.take(maxIssues)) {
        b.writeln('  - $i');
      }
      if (issues.length > maxIssues)
        b.writeln('  - ... 외 ${issues.length - maxIssues}건');
    }
    return b.toString();
  }
}

/// [rules]를 모든 행에 적용한다. [keyColumn]이 주어지면 키 중복도 검사하고,
/// 중복된 키의 두 번째 이후 행은 제외한다.
ValidationReport validateRows(
  List<Map<String, String>> rows,
  List<RowRule> rules, {
  String? keyColumn,
}) {
  final valid = <Map<String, String>>[];
  final issues = <RowIssue>[];
  final seen = <String, int>{};
  final dup = <String, int>{};
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final key = keyColumn == null ? null : row[keyColumn]?.trim();
    var ok = true;
    for (final r in rules) {
      final msg = r.check(row);
      if (msg != null) {
        issues.add(RowIssue(i + 2, r.column, msg, key: key));
        ok = false;
      }
    }
    if (key != null && key.isNotEmpty) {
      seen[key] = (seen[key] ?? 0) + 1;
      if (seen[key]! > 1) {
        dup[key] = seen[key]!;
        issues.add(RowIssue(i + 2, keyColumn!, '키 중복', key: key));
        ok = false;
      }
    }
    if (ok) valid.add(row);
  }
  return ValidationReport(rows.length, valid, issues, dup);
}
