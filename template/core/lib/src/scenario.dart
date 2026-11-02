/// 이해관계자 관점 하나 = 시나리오 하나.
/// 예: "접근성 우선(HR)", "비용 우선(재무)", "균형".
/// params에 가중치나 임계값을 넣고, 웹 화면에서 조절 가능하게 노출한다.
class Scenario {
  const Scenario({
    required this.id,
    required this.label,
    this.description = '',
    this.params = const {},
  });

  final String id;
  final String label;
  final String description;
  final Map<String, num> params;

  num param(String key, num fallback) => params[key] ?? fallback;

  Scenario withParams(Map<String, num> overrides) => Scenario(
    id: id,
    label: label,
    description: description,
    params: {...params, ...overrides},
  );

  Map<String, Object> toJson() => {
    'id': id,
    'label': label,
    'description': description,
    'params': params,
  };
}

/// 화면에서 조절할 파라미터 정의 (슬라이더/숫자 입력 생성용).
class ParamSpec {
  const ParamSpec(
    this.key,
    this.label, {
    required this.min,
    required this.max,
    required this.step,
    required this.defaultValue,
    this.unit = '',
    this.help = '',
  });

  final String key;
  final String label;
  final num min;
  final num max;
  final num step;
  final num defaultValue;
  final String unit;
  final String help;

  num clamp(num v) => v < min ? min : (v > max ? max : v);
}
