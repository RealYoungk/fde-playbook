import 'package:ops_core/ops_core.dart';
import 'package:test/test.dart';
import 'package:web_app/main.server.dart';

void main() {
  test('쿼리 파라미터 파싱과 범위 클램프', () {
    final o = parseOverrides({'maxSites': '999', 'walkLimit': '12', 'junk': '1', 'targetCoverage': 'x'});
    expect(o['maxSites'], demoParamSpecs.firstWhere((p) => p.key == 'maxSites').max);
    expect(o['walkLimit'], 12);
    expect(o.containsKey('junk'), isFalse);
    expect(o.containsKey('targetCoverage'), isFalse);
  });
}
