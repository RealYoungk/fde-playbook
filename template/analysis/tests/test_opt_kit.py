"""실행: cd template/analysis && python3 -m unittest -v"""
import itertools
import json
import os
import unittest

import numpy as np

from opt_kit import assign, location, routing, timetable
from opt_kit.__main__ import run_demo

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data")


class LocationTest(unittest.TestCase):
    def setUp(self):
        rng = np.random.default_rng(1)
        self.cover = rng.random((25, 8)) < 0.25
        self.w = rng.integers(1, 5, 25).astype(float)

    def brute(self, p):
        best = 0.0
        for comb in itertools.combinations(range(8), p):
            best = max(best, self.w[self.cover[:, comb].any(axis=1)].sum())
        return best

    def test_mclp_matches_brute_force(self):
        for p in (1, 2, 3):
            r = location.solve_mclp(self.cover, self.w, p)
            self.assertEqual(r.status, "OPTIMAL")
            self.assertAlmostEqual(r.covered_weight, self.brute(p))

    def test_greedy_not_better_than_mip(self):
        for p in (2, 3, 4):
            g = location.greedy_mclp(self.cover, self.w, p)
            m = location.solve_mclp(self.cover, self.w, p)
            self.assertLessEqual(g.covered_weight, m.covered_weight + 1e-9)

    def test_min_sites_reaches_target(self):
        r = location.solve_min_sites(self.cover, self.w, target=0.6)
        self.assertGreaterEqual(r.coverage_rate, 0.6 - 1e-9)
        # 하나 줄이면 목표 미달이어야 최소
        best_smaller = max((self.w[self.cover[:, c].any(axis=1)].sum()
                            for c in itertools.combinations(range(8), len(r.selected) - 1)), default=0)
        self.assertLess(best_smaller / self.w.sum(), 0.6)

    def test_pmedian_assigns_everyone_to_open_site(self):
        rng = np.random.default_rng(2)
        cost = rng.random((15, 6)) * 20
        r = location.solve_pmedian(cost, p=2)
        self.assertEqual(len(r.selected), 2)
        self.assertTrue(all(a in r.selected for a in r.assignment))


class OtherTest(unittest.TestCase):
    def test_capacitated_assignment_respects_capacity(self):
        cost = np.array([[1, 9], [1, 9], [1, 9], [9, 1]], float)
        a, st, _ = assign.solve_capacitated_assignment(cost, capacity=[2, 2])
        self.assertEqual(st, "OPTIMAL")
        self.assertEqual(a.count(0), 2)
        self.assertEqual(a.count(1), 2)

    def test_vrp_capacity(self):
        T = np.array([[0, 5, 5, 5, 5], [5, 0, 2, 9, 9], [5, 2, 0, 9, 9], [5, 9, 9, 0, 2], [5, 9, 9, 2, 0]])
        routes, st = routing.solve_vrp(T, demands=[0, 10, 10, 10, 10], vehicle_capacity=20, num_vehicles=3, time_limit_s=2)
        self.assertEqual(st, "OK")
        served = sorted(n for r in routes for n in r.nodes[1:-1])
        self.assertEqual(served, [1, 2, 3, 4])
        self.assertTrue(all(r.load <= 20 for r in routes))

    def test_timetable(self):
        self.assertEqual(timetable.backward_schedule("09:00", [10, 20], dwell_minutes=1, buffer_minutes=5),
                         ["08:24", "08:35"])
        self.assertEqual(timetable.shift_waves(["08:00", "08:10", "09:00", "07:50"], 15), ["07:50", "08:10", "09:00"])


@unittest.skipUnless(os.path.exists(os.path.join(DATA, "demo_dart_greedy.json")), "데모 CSV 없음")
class CrossCheckTest(unittest.TestCase):
    """다른 경로 재계산: Dart 탐욕 결과와 Python 탐욕 결과가 같아야 한다."""

    def test_python_greedy_equals_dart_greedy(self):
        dart = json.load(open(os.path.join(DATA, "demo_dart_greedy.json")))
        rep = run_demo(DATA, {}, "greedy")
        for r in rep["results"]:
            py_ids = [s["id"] for s in r["extras"]["sites"]]
            self.assertEqual(py_ids, dart[r["scenario"]["id"]], r["scenario"]["id"])

    def test_mip_at_least_greedy(self):
        g = {r["scenario"]["id"]: r for r in run_demo(DATA, {}, "greedy")["results"]}
        m = run_demo(DATA, {}, "mip")
        for r in m["results"]:
            sc = r["scenario"]
            if sc["params"]["targetCoverage"] >= 100:
                key = "cov10" if sc["params"]["walkLimit"] == 10 else "cov15"
                self.assertGreaterEqual(r["metrics"][key] + 1e-9, g[sc["id"]]["metrics"][key])
            else:
                self.assertLessEqual(r["metrics"]["sites"], g[sc["id"]]["metrics"]["sites"])


if __name__ == "__main__":
    unittest.main()
