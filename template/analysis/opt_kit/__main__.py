"""CLI. 예: python3 -m opt_kit demo --data ../data --params '{"maxSites": 6}' [--method mip|greedy] [--md]

DEMO 전용 문제(픽업 거점 선정)를 MIP(정확해) 또는 탐욕(Dart와 같은 규칙)으로 풀어
Dart ops_core와 같은 JSON 스키마로 stdout에 출력한다. 과제에서는 이 파일을 도메인에 맞게 바꾼다.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np

from . import location, report
from .data import read_csv
from .geo import haversine_matrix, walk_minutes

PARAM_DEFAULTS = {"walkLimit": 10, "maxSites": 8, "targetCoverage": 100}
SCENARIOS = [
    report.scenario("access", "접근성 우선", "이용률, 민원 최소화 관점", {"walkLimit": 10, "maxSites": 12, "targetCoverage": 100}),
    report.scenario("cost", "비용 우선", "운영 비용 최소화 관점", {"walkLimit": 15, "maxSites": 5, "targetCoverage": 100}),
    report.scenario("balanced", "균형", "커버율 70%에서 멈춤", {"walkLimit": 10, "maxSites": 10, "targetCoverage": 70}),
]
METRICS = [
    report.Metric("cov10", "10분 이내 비율", "%", True, "HR"),
    report.Metric("cov15", "15분 이내 비율", "%", True, "HR"),
    report.Metric("avgWalk", "평균 도보시간", "분", False, "이용자"),
    report.Metric("sites", "거점 수", "개", False, "재무", 0),
]
CONSTRAINTS = [
    report.Constraint("budget", "거점 수 예산 이내", True, 'DEMO: 담당자 "많아야 N개" (가정)'),
    report.Constraint("noFar", "도보 20분 초과 수요 없음", False, "DEMO: 민원 우려 (가정)"),
]


def _metrics(walk: np.ndarray, w: np.ndarray, sel: list[int]) -> tuple[dict, np.ndarray]:
    nearest = walk[:, sel].min(axis=1) if sel else np.full(len(w), np.inf)
    tot = w.sum()
    m = {
        "cov10": float(w[nearest <= 10].sum() / tot * 100),
        "cov15": float(w[nearest <= 15].sum() / tot * 100),
        "avgWalk": float(nearest[np.isfinite(nearest)].mean()) if np.isfinite(nearest).any() else 0.0,
        "sites": float(len(sel)),
    }
    return m, nearest


def run_demo(data_dir: str, overrides: dict, method: str) -> dict:
    dem = read_csv(os.path.join(data_dir, "demo_demands.csv"))
    cand = read_csv(os.path.join(data_dir, "demo_candidates.csv"))
    existing_ids = set(read_csv(os.path.join(data_dir, "demo_existing.csv"))["id"].astype(str))
    w = dem["weight"].to_numpy(float)
    walk = walk_minutes(haversine_matrix(dem.lat, dem.lng, cand.lat, cand.lng))
    cand_ids = cand["id"].astype(str).tolist()

    def solve(params: dict) -> tuple[list[int], str]:
        p = int(params["maxSites"])
        target = float(params["targetCoverage"]) / 100
        cover = walk <= float(params["walkLimit"])
        if method == "greedy":
            r = location.greedy_mclp(cover, w, p, None if target >= 1 else target)
        elif target >= 1:
            r = location.solve_mclp(cover, w, p)
        else:
            r = location.solve_min_sites(cover, w, target=target, max_sites=p)
        return r.selected, r.status

    def result(sc: dict, sel: list[int], status: str, ms: int, budget: int | None) -> report.Result:
        m, nearest = _metrics(walk, w, sel)
        far = int((nearest > 20).sum())
        viol = report.check(CONSTRAINTS, {
            "budget": lambda: [f"거점 {len(sel)}개 > 예산 {budget}개"] if budget is not None and len(sel) > budget else [],
            "noFar": lambda: [f"20분 초과 수요 {far}건"] if far else [],
        })
        if status == "INFEASIBLE":
            viol.insert(0, report.violation("solver", "제약 안에서 해가 없음 (목표 또는 예산 조정 필요)", True))
        sites = [{"id": cand_ids[j], "lat": float(cand.lat[j]), "lng": float(cand.lng[j])} for j in sel]
        return report.Result(sc, m, viol, ms, {"sites": sites, "solver": status})

    base_sel = [i for i, c in enumerate(cand_ids) if c in existing_ids]
    baseline = result(report.scenario("baseline", "기존안"), base_sel, "EXISTING", 0, None)
    scs = list(SCENARIOS)
    if overrides:
        scs.append(report.scenario("custom", "사용자 조정", "화면에서 조정한 값", {**PARAM_DEFAULTS, **overrides}))
    results = []
    for sc in scs:
        t0 = time.perf_counter()
        sel, status = solve(sc["params"])
        results.append(result(sc, sel, status, int((time.perf_counter() - t0) * 1000), int(sc["params"]["maxSites"])))
    ctx = {
        "engine": f"python/{method}",
        "demands": [{"lat": float(a), "lng": float(b), "w": float(c)} for a, b, c in zip(dem.lat, dem.lng, w)],
    }
    return report.build(METRICS, CONSTRAINTS, results, baseline, ctx)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="opt_kit")
    ap.add_argument("command", choices=["demo"])
    ap.add_argument("--data", default=os.path.join(os.path.dirname(__file__), "..", "..", "data"))
    ap.add_argument("--params", default="{}")
    ap.add_argument("--method", choices=["mip", "greedy"], default="mip")
    ap.add_argument("--md", action="store_true", help="마크다운 비교표 출력")
    a = ap.parse_args(argv)
    rep = run_demo(a.data, json.loads(a.params), a.method)
    print(report.to_markdown(rep) if a.md else json.dumps(rep, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
