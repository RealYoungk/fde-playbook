"""차량 경로 문제 (VRP). OR-Tools Routing.

time_matrix: 노드 간 이동 시간(분, 정수로 반올림해 사용). 0번 노드가 기본 차고지(또는 도착지).
경로를 '도착지에 도착'하는 형태로 만들 때는 도착지를 depot으로 두고, 결과 경로를 뒤집어 읽는다.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass
class Route:
    vehicle: int
    nodes: list[int]  # depot 포함 시작과 끝
    load: float
    minutes: float


def solve_vrp(time_matrix, demands=None, vehicle_capacity: float | None = None, num_vehicles: int = 1,
              depot: int = 0, max_route_minutes: float | None = None, service_minutes=None,
              time_windows=None, time_limit_s: int = 10):
    """반환: (routes, status). status: OK / NO_SOLUTION.
    - demands: 노드별 탑승 인원 (depot은 0)
    - service_minutes: 노드별 정차 시간
    - time_windows: 노드별 (earliest, latest) 분, depot 출발 0 기준
    """
    from ortools.constraint_solver import pywrapcp, routing_enums_pb2

    T = np.rint(np.asarray(time_matrix, float)).astype(int)
    n = len(T)
    svc = np.zeros(n, int) if service_minutes is None else np.rint(np.asarray(service_minutes)).astype(int)
    mgr = pywrapcp.RoutingIndexManager(n, num_vehicles, depot)
    rt = pywrapcp.RoutingModel(mgr)

    def transit(i, j):
        a, b = mgr.IndexToNode(i), mgr.IndexToNode(j)
        return int(T[a, b] + svc[a])

    cb = rt.RegisterTransitCallback(transit)
    rt.SetArcCostEvaluatorOfAllVehicles(cb)
    horizon = int(max_route_minutes) if max_route_minutes else int(T.sum() + svc.sum() + 1)
    rt.AddDimension(cb, horizon, horizon, False, "Time")
    tdim = rt.GetDimensionOrDie("Time")
    if time_windows is not None:
        for node, (a, b) in enumerate(time_windows):
            if node == depot:
                continue
            tdim.CumulVar(mgr.NodeToIndex(node)).SetRange(int(a), int(b))
    if demands is not None and vehicle_capacity is not None:
        dem = np.rint(np.asarray(demands, float)).astype(int)
        dcb = rt.RegisterUnaryTransitCallback(lambda i: int(dem[mgr.IndexToNode(i)]))
        rt.AddDimensionWithVehicleCapacity(dcb, 0, [int(vehicle_capacity)] * num_vehicles, True, "Cap")
    params = pywrapcp.DefaultRoutingSearchParameters()
    params.first_solution_strategy = routing_enums_pb2.FirstSolutionStrategy.PATH_CHEAPEST_ARC
    params.local_search_metaheuristic = routing_enums_pb2.LocalSearchMetaheuristic.GUIDED_LOCAL_SEARCH
    params.time_limit.seconds = time_limit_s
    sol = rt.SolveWithParameters(params)
    if sol is None:
        return [], "NO_SOLUTION"
    routes = []
    for v in range(num_vehicles):
        idx = rt.Start(v)
        nodes, load = [], 0.0
        while not rt.IsEnd(idx):
            node = mgr.IndexToNode(idx)
            nodes.append(node)
            if demands is not None:
                load += float(demands[node])
            idx = sol.Value(rt.NextVar(idx))
        nodes.append(mgr.IndexToNode(idx))
        if len(nodes) > 2:
            routes.append(Route(v, nodes, load, float(sol.Value(tdim.CumulVar(idx)))))
    return routes, "OK"
