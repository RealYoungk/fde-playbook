"""용량 제약 배정: 사람(또는 수요)을 정원이 있는 대상(시간대, 거점, 회의실)에 배정."""
from __future__ import annotations

import numpy as np


def solve_capacitated_assignment(cost, demand=None, capacity=None, max_cost: float | None = None,
                                 time_limit_s: float = 20, backend: str = "SCIP"):
    """각 수요 i를 대상 j 하나에 배정. 대상 용량 이하, 비용 합 최소.
    반환: (assignment 리스트(배정 불가면 -1), status, objective)."""
    from ortools.linear_solver import pywraplp

    cost = np.asarray(cost, float)
    n, m = cost.shape
    d = np.ones(n) if demand is None else np.asarray(demand, float)
    cap = np.full(m, np.inf) if capacity is None else np.asarray(capacity, float)
    s = pywraplp.Solver.CreateSolver(backend) or pywraplp.Solver.CreateSolver("CBC")
    z = {}
    for i in range(n):
        allowed = [j for j in range(m) if max_cost is None or cost[i, j] <= max_cost]
        for j in allowed:
            z[i, j] = s.BoolVar(f"z{i}_{j}")
        s.Add(sum(z[i, j] for j in allowed) == 1)
    for j in range(m):
        if np.isfinite(cap[j]):
            s.Add(sum(float(d[i]) * v for (i, jj), v in z.items() if jj == j) <= float(cap[j]))
    s.Minimize(sum(float(cost[i, j]) * v for (i, j), v in z.items()))
    s.SetTimeLimit(int(time_limit_s * 1000))
    code = s.Solve()
    status = {pywraplp.Solver.OPTIMAL: "OPTIMAL", pywraplp.Solver.FEASIBLE: "FEASIBLE"}.get(code, "INFEASIBLE")
    if status == "INFEASIBLE":
        return [-1] * n, status, None
    assign = [-1] * n
    for (i, j), v in z.items():
        if v.solution_value() > 0.5:
            assign[i] = j
    return assign, status, s.Objective().Value()
