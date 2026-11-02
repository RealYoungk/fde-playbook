"""시간표 유틸. 도착 목표 시각에서 역산해 지점별 출발 시각을 만든다."""
from __future__ import annotations


def to_min(hhmm: str) -> int:
    h, m = hhmm.strip().split(":")
    return int(h) * 60 + int(m)


def to_hhmm(minutes: float) -> str:
    m = int(round(minutes)) % (24 * 60)
    return f"{m // 60:02d}:{m % 60:02d}"


def backward_schedule(arrive_by: str, leg_minutes: list[float], dwell_minutes: float = 1.0,
                      buffer_minutes: float = 5.0) -> list[str]:
    """지점 순서대로의 구간 소요시간 leg_minutes (지점0→1, 1→2, ..., 마지막→도착지)로
    도착지에 arrive_by - buffer 이전 도착하도록 각 지점 출발 시각을 역산."""
    t = to_min(arrive_by) - buffer_minutes
    times = []
    for leg in reversed(leg_minutes):
        t -= leg
        times.append(t)
        t -= dwell_minutes
    return [to_hhmm(x) for x in reversed(times)]


def shift_waves(shift_starts: list[str], min_gap: int = 20) -> list[str]:
    """근무 시작 시각들을 min_gap분 이내끼리 묶어 운행 회차(가장 이른 시각 기준)를 만든다."""
    ts = sorted({to_min(s) for s in shift_starts})
    waves, cur = [], None
    for t in ts:
        if cur is None or t - cur > min_gap:
            waves.append(t)
            cur = t
    return [to_hhmm(t) for t in waves]
