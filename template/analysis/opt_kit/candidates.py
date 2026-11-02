"""후보지 생성. 후보 집합이 해의 품질 상한을 정하므로, 어떤 방식으로 만들었는지 기록할 것."""
from __future__ import annotations

import numpy as np


def kmeans_candidates(lat, lng, k: int, weights=None, seed: int = 0):
    """수요 분포의 군집 중심을 후보로. scikit-learn이 없으면 간단한 Lloyd 반복."""
    X = np.column_stack([np.asarray(lat, float), np.asarray(lng, float)])
    w = None if weights is None else np.asarray(weights, float)
    try:
        from sklearn.cluster import KMeans

        km = KMeans(n_clusters=k, n_init=10, random_state=seed).fit(X, sample_weight=w)
        return km.cluster_centers_[:, 0], km.cluster_centers_[:, 1]
    except ImportError:
        rng = np.random.default_rng(seed)
        C = X[rng.choice(len(X), size=k, replace=False)]
        for _ in range(50):
            lab = np.argmin(((X[:, None, :] - C[None, :, :]) ** 2).sum(-1), axis=1)
            for j in range(k):
                m = lab == j
                if m.any():
                    ww = None if w is None else w[m]
                    C[j] = np.average(X[m], axis=0, weights=ww)
        return C[:, 0], C[:, 1]


def grid_candidates(lat, lng, step_deg: float = 0.005, margin: float = 0.0):
    """수요 범위를 덮는 격자점."""
    lat = np.asarray(lat, float)
    lng = np.asarray(lng, float)
    la = np.arange(lat.min() - margin, lat.max() + margin + 1e-12, step_deg)
    lo = np.arange(lng.min() - margin, lng.max() + margin + 1e-12, step_deg)
    g = np.array([(a, b) for a in la for b in lo])
    return g[:, 0], g[:, 1]
