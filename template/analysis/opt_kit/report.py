"""Dart ops_core EvaluationReport.toJson()과 같은 스키마로 결과를 만든다.
web_app이 이 JSON을 그대로 화면에 그릴 수 있다 (engine=python)."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable


@dataclass
class Metric:
    key: str
    label: str
    unit: str = ""
    higher_is_better: bool = True
    stakeholder: str = ""
    decimals: int = 1

    @property
    def absolute_delta(self) -> bool:
        return self.unit == "%"


@dataclass
class Constraint:
    key: str
    label: str
    hard: bool = True
    source: str = ""


@dataclass
class Result:
    scenario: dict
    metrics: dict[str, float]
    violations: list[dict] = field(default_factory=list)
    elapsed_ms: int = 0
    extras: dict[str, Any] = field(default_factory=dict)

    @property
    def feasible(self) -> bool:
        return not any(v.get("hard", True) for v in self.violations)


def scenario(id: str, label: str, description: str = "", params: dict | None = None) -> dict:
    return {"id": id, "label": label, "description": description, "params": params or {}}


def violation(key: str, message: str, hard: bool = True) -> dict:
    return {"constraint": key, "message": message, "hard": hard}


def check(constraints: list[Constraint], checks: dict[str, Callable[[], list[str]]]) -> list[dict]:
    """checks[key]()가 위반 메시지 목록을 반환."""
    out = []
    for c in constraints:
        for msg in checks.get(c.key, lambda: [])():
            out.append(violation(c.key, msg, c.hard))
    return out


def _delta(m: Metric, base: dict, r: dict):
    b, v = base.get(m.key), r.get(m.key)
    if b is None or v is None:
        return None
    if m.absolute_delta:
        return v - b
    return None if b == 0 else (v - b) / abs(b) * 100


def build(metrics: list[Metric], constraints: list[Constraint], results: list[Result],
          baseline: Result | None = None, context: dict | None = None) -> dict:
    def res(r: Result, is_base: bool):
        d = {
            "scenario": r.scenario,
            "metrics": r.metrics,
            "feasible": r.feasible,
            "violations": r.violations,
            "elapsedMs": r.elapsed_ms,
            "extras": r.extras,
        }
        if baseline is not None and not is_base:
            d["delta"] = {m.key: _delta(m, baseline.metrics, r.metrics) for m in metrics}
        return d

    return {
        "metrics": [
            {"key": m.key, "label": m.label, "unit": m.unit, "higherIsBetter": m.higher_is_better,
             "stakeholder": m.stakeholder, "decimals": m.decimals}
            for m in metrics
        ],
        "constraints": [{"key": c.key, "label": c.label, "hard": c.hard, "source": c.source} for c in constraints],
        "baseline": None if baseline is None else res(baseline, True),
        "results": [res(r, False) for r in results],
        "context": context or {},
    }


def to_markdown(report: dict) -> str:
    cols = ([report["baseline"]] if report.get("baseline") else []) + report["results"]
    lines = [
        "| 지표 | " + " | ".join(c["scenario"]["label"] for c in cols) + " |",
        "|---|" + "|".join("---" for _ in cols) + "|",
    ]
    for m in report["metrics"]:
        cells = []
        for c in cols:
            v = c["metrics"].get(m["key"])
            txt = "-" if v is None else f"{v:.{m.get('decimals', 1)}f}{m['unit']}"
            d = (c.get("delta") or {}).get(m["key"])
            if d is not None:
                suf = "%p" if m["unit"] == "%" else "%"
                txt += f" ({d:+.1f}{suf})"
            cells.append(txt)
        lines.append(f"| {m['label']} | " + " | ".join(cells) + " |")
    return "\n".join(lines)
