"""입지 선정 모델.

cover[i, j] = 수요 i를 후보 j가 덮는가 (bool, n x m)
cost[i, j]  = 수요 i가 후보 j를 이용할 때의 비용 (예: 도보 분)
w[i]        = 수요 가중치 (인원 등)

| 질문 | 모델 | 함수 |
|---|---|---|
| p개로 최대한 많이 덮기 | MCLP (Maximal Covering) | solve_mclp |
| 목표 커버율을 최소 개수로 | 부분 집합 커버 | solve_min_sites |
| p개로 평균 이동 비용 최소 | p-median | solve_pmedian |
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field

import numpy as np


@dataclass
class LocationResult:
    selected: list[int]
    covered_weight: float
    total_weight: float
    status: str  # OPTIMAL / FEASIBLE / GREEDY / GREEDY_FALLBACK / INFEASIBLE
    objective: float | None = None
    elapsed_ms: int = 0
    assignment: list[int] | None = None  # p-median: 수요별 배정 후보 인덱스
    steps: list[float] = field(default_factory=list)

    @property
    def coverage_rate(self) -> float:
        return 0.0 if self.total_weight == 0 else self.covered_weight / self.total_weight


def coverage_matrix(cost: np.ndarray, limit: float) -> np.ndarray:
    return np.asarray(cost) <= limit


def greedy_mclp(cover, w=None, p: int | None = None, target: float | None = None) -> LocationResult:
    """탐욕 최대 커버리지. Dart ops_core.greedyMaxCoverage와 같은 규칙(동점이면 앞 인덱스)이라 교차검증에 쓴다."""
    t0 = time.perf_counter()
    cover = np.asarray(cover, bool)
    n, m = cover.shape
    w = np.ones(n) if w is None else np.asarray(w, float)
    total = float(w.sum())
    covered = np.zeros(n, bool)
    picked: list[int] = []
    steps: list[float] = []
    limit = m if p is None else p
    while len(picked) < limit:
        if target is not None and total > 0 and w[covered].sum() / total >= target:
            break
        gains = (cover & ~covered[:, None]).T @ w
        gains[picked] = -1
        j = int(np.argmax(gains))
        if gains[j] <= 0:
            break
        picked.append(j)
        covered |= cover[:, j]
        steps.append(float(w[covered].sum() / total) if total else 0.0)
    return LocationResult(picked, float(w[covered].sum()), total, "GREEDY",
                          elapsed_ms=int((time.perf_counter() - t0) * 1000), steps=steps)


def _mip(name: str):
    try:
        from ortools.linear_solver import pywraplp
    except ImportError:
        return None
    for backend in (name, "SCIP", "CBC"):
        s = pywraplp.Solver.CreateSolver(backend)
        if s is not None:
            return s
    return None


def _status(solver, code) -> str:
    from ortools.linear_solver import pywraplp

    return {pywraplp.Solver.OPTIMAL: "OPTIMAL", pywraplp.Solver.FEASIBLE: "FEASIBLE"}.get(code, "INFEASIBLE")


def solve_mclp(cover, w=None, p: int = 5, fixed: list[int] | None = None,
               time_limit_s: float = 20, backend: str = "SCIP") -> LocationResult:
    """최대 커버리지: 후보 p개를 골라 덮인 가중치 합을 최대화.
    fixed: 반드시 포함할 후보 (예: 유지해야 하는 기존 거점)."""
    cover = np.asarray(cover, bool)
    n, m = cover.shape
    w = np.ones(n) if w is None else np.asarray(w, float)
    s = _mip(backend)
    if s is None:
        r = greedy_mclp(cover, w, p)
        r.status = "GREEDY_FALLBACK"
        return r
    t0 = time.perf_counter()
    x = [s.BoolVar(f"x{j}") for j in range(m)]
    y = [s.BoolVar(f"y{i}") for i in range(n)]
    for i in range(n):
        js = np.flatnonzero(cover[i])
        if len(js) == 0:
            s.Add(y[i] == 0)
        else:
            s.Add(y[i] <= sum(x[j] for j in js))
    s.Add(sum(x) <= p)
    for j in fixed or []:
        s.Add(x[j] == 1)
    s.Maximize(sum(float(w[i]) * y[i] for i in range(n)))
    s.SetTimeLimit(int(time_limit_s * 1000))
    code = s.Solve()
    sel = [j for j in range(m) if x[j].solution_value() > 0.5]
    cov = cover[:, sel].any(axis=1) if sel else np.zeros(n, bool)
    return LocationResult(sel, float(w[cov].sum()), float(w.sum()), _status(s, code),
                          objective=s.Objective().Value(),
                          elapsed_ms=int((time.perf_counter() - t0) * 1000))


def solve_min_sites(cover, w=None, target: float = 1.0, max_sites: int | None = None,
                    time_limit_s: float = 20, backend: str = "SCIP") -> LocationResult:
    """목표 커버율(가중) 이상을 만족하는 최소 후보 수. target=1.0이면 덮을 수 있는 수요 전부."""
    cover = np.asarray(cover, bool)
    n, m = cover.shape
    w = np.ones(n) if w is None else np.asarray(w, float)
    coverable = cover.any(axis=1)
    need = target * float(w[coverable].sum()) if target >= 1 else target * float(w.sum())
    s = _mip(backend)
    if s is None:
        r = greedy_mclp(cover, w, max_sites, target)
        r.status = "GREEDY_FALLBACK"
        return r
    t0 = time.perf_counter()
    x = [s.BoolVar(f"x{j}") for j in range(m)]
    y = [s.BoolVar(f"y{i}") for i in range(n)]
    for i in range(n):
        js = np.flatnonzero(cover[i])
        s.Add(y[i] <= (sum(x[j] for j in js) if len(js) else 0))
    s.Add(sum(float(w[i]) * y[i] for i in range(n)) >= need - 1e-6)
    if max_sites is not None:
        s.Add(sum(x) <= max_sites)
    s.Minimize(sum(x))
    s.SetTimeLimit(int(time_limit_s * 1000))
    code = s.Solve()
    st = _status(s, code)
    sel = [j for j in range(m) if x[j].solution_value() > 0.5] if st != "INFEASIBLE" else []
    cov = cover[:, sel].any(axis=1) if sel else np.zeros(n, bool)
    return LocationResult(sel, float(w[cov].sum()), float(w.sum()), st,
                          objective=s.Objective().Value() if sel else None,
                          elapsed_ms=int((time.perf_counter() - t0) * 1000))


def solve_pmedian(cost, w=None, p: int = 5, max_cost: float | None = None,
                  time_limit_s: float = 30, backend: str = "SCIP") -> LocationResult:
    """p-median: 후보 p개를 열고 각 수요를 열린 후보 하나에 배정해 가중 비용 합을 최소화.
    max_cost를 주면 그보다 먼 배정은 금지(모든 수요가 배정 가능해야 feasible)."""
    cost = np.asarray(cost, float)
    n, m = cost.shape
    w = np.ones(n) if w is None else np.asarray(w, float)
    s = _mip(backend)
    if s is None:
        raise RuntimeError("p-median은 OR-Tools가 필요합니다")
    t0 = time.perf_counter()
    x = [s.BoolVar(f"x{j}") for j in range(m)]
    z = {}
    for i in range(n):
        allowed = [j for j in range(m) if max_cost is None or cost[i, j] <= max_cost]
        for j in allowed:
            z[i, j] = s.NumVar(0, 1, f"z{i}_{j}")
            s.Add(z[i, j] <= x[j])
        s.Add(sum(z[i, j] for j in allowed) == 1)
    s.Add(sum(x) == p)
    s.Minimize(sum(float(w[i] * cost[i, j]) * v for (i, j), v in z.items()))
    s.SetTimeLimit(int(time_limit_s * 1000))
    code = s.Solve()
    st = _status(s, code)
    if st == "INFEASIBLE":
        return LocationResult([], 0, float(w.sum()), st)
    sel = [j for j in range(m) if x[j].solution_value() > 0.5]
    assign = [int(sel[int(np.argmin(cost[i, sel]))]) for i in range(n)]
    return LocationResult(sel, float(w.sum()), float(w.sum()), st, objective=s.Objective().Value(),
                          elapsed_ms=int((time.perf_counter() - t0) * 1000), assignment=assign)
