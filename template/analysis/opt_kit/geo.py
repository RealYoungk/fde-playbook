"""거리와 시간. 도로 데이터가 없을 때의 근사이므로 계수는 가정으로 기록할 것."""
from __future__ import annotations

import numpy as np

EARTH_KM = 6371.0


def haversine_matrix(lat1, lng1, lat2, lng2) -> np.ndarray:
    """점 집합 A(n)와 B(m) 사이 직선거리(km) 행렬 n x m."""
    lat1 = np.radians(np.asarray(lat1, dtype=float))[:, None]
    lng1 = np.radians(np.asarray(lng1, dtype=float))[:, None]
    lat2 = np.radians(np.asarray(lat2, dtype=float))[None, :]
    lng2 = np.radians(np.asarray(lng2, dtype=float))[None, :]
    h = np.sin((lat2 - lat1) / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin((lng2 - lng1) / 2) ** 2
    return 2 * EARTH_KM * np.arcsin(np.sqrt(np.clip(h, 0, 1)))


def walk_minutes(km, speed_kmh: float = 4.5, detour: float = 1.3):
    """직선거리를 도보 분으로. Dart ops_core.walkMinutes와 같은 식."""
    return np.asarray(km) * detour / speed_kmh * 60


def drive_minutes(km, speed_kmh: float = 30.0, detour: float = 1.4):
    return np.asarray(km) * detour / speed_kmh * 60
