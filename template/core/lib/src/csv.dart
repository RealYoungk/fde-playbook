import 'dart:convert';
import 'dart:io';

/// 헤더가 있는 CSV를 행 단위 Map 리스트로 읽는다.
/// 따옴표로 감싼 필드, 필드 안의 쉼표와 줄바꿈, 이스케이프된 따옴표("")를 지원한다.
List<Map<String, String>> readCsvFile(String path, {String delimiter = ','}) {
  var text = File(path).readAsStringSync(encoding: utf8);
  if (text.startsWith('﻿')) text = text.substring(1); // BOM 제거
  return parseCsv(text, delimiter: delimiter);
}

List<Map<String, String>> parseCsv(String text, {String delimiter = ','}) {
  final rows = parseCsvRows(text, delimiter: delimiter);
  if (rows.isEmpty) return [];
  final header = rows.first.map((h) => h.trim()).toList();
  return [
    for (final r in rows.skip(1))
      if (!(r.length == 1 && r.first.trim().isEmpty))
        {
          for (var i = 0; i < header.length; i++)
            header[i]: i < r.length ? r[i] : '',
        },
  ];
}

List<List<String>> parseCsvRows(String text, {String delimiter = ','}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// JSON 파일(배열 또는 {key: 배열})을 Map 리스트로 읽는다.
List<Map<String, dynamic>> readJsonRecords(String path, {String? key}) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  final list = key == null ? decoded : (decoded as Map)[key];
  return (list as List).cast<Map<String, dynamic>>();
}

double? toDoubleOrNull(String? v) =>
    v == null ? null : double.tryParse(v.trim().replaceAll(',', ''));
