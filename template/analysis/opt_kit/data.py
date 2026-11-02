"""데이터 로딩과 프로파일."""
from __future__ import annotations

import pandas as pd


def read_csv(path: str, **kw) -> pd.DataFrame:
    """UTF-8(BOM 포함)과 CP949를 순서대로 시도."""
    for enc in ("utf-8-sig", "cp949"):
        try:
            return pd.read_csv(path, encoding=enc, **kw)
        except UnicodeDecodeError:
            continue
    raise ValueError(f"인코딩을 판별할 수 없음: {path}")


def profile(df: pd.DataFrame, name: str = "data") -> str:
    """행 수, 결측, 고유값, 범위를 마크다운 표로. DECISIONS.md '데이터 점검'에 붙인다."""
    lines = [
        f"### 데이터 프로파일: {name}",
        f"- 행 수: {len(df)}, 완전 중복 행: {int(df.duplicated().sum())}",
        "",
        "| 컬럼 | 타입 | 결측률 | 고유값 | 범위/최빈값 |",
        "|---|---|---|---|---|",
    ]
    for c in df.columns:
        s = df[c]
        blank = s.isna().mean() * 100
        if pd.api.types.is_numeric_dtype(s):
            rng = f"{s.min():.4g} ~ {s.max():.4g}" if s.notna().any() else "-"
        else:
            top = s.astype(str).value_counts().head(3)
            rng = ", ".join(f"{k}({v})" for k, v in top.items())
        lines.append(f"| {c} | {s.dtype} | {blank:.1f}% | {s.nunique()} | {rng} |")
    return "\n".join(lines)
