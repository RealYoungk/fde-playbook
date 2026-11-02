#!/usr/bin/env bash
# 시험 환경 점검. 결과를 보고 플랜 A(Jaspr) / 플랜 B(Serverpod)를 고른다.
# 사용: bash scripts/env_check.sh

ok()   { printf "  [OK]   %s\n" "$1"; }
warn() { printf "  [주의] %s\n" "$1"; }
bad()  { printf "  [불가] %s\n" "$1"; }

echo "== 도구 =="
if command -v dart >/dev/null 2>&1; then ok "dart: $(dart --version 2>&1 | head -1)"; else bad "dart 없음 → 과제가 허용하는 다른 언어로 전환 검토"; fi
if command -v flutter >/dev/null 2>&1; then ok "flutter 있음"; else warn "flutter 없음 → serverpod CLI 실행 불가, 플랜 A 사용"; fi
if command -v jaspr >/dev/null 2>&1; then ok "jaspr CLI 있음"; else warn "jaspr CLI 없음 → dart pub global activate jaspr_cli"; fi
if command -v serverpod >/dev/null 2>&1; then ok "serverpod CLI 있음"; else warn "serverpod CLI 없음"; fi
for t in node python3 git docker; do command -v $t >/dev/null 2>&1 && ok "$t 있음" || warn "$t 없음"; done

echo "== Python 패키지 =="
if command -v python3 >/dev/null 2>&1; then
  for m in ortools numpy pandas sklearn scipy networkx; do
    if python3 -c "import $m" 2>/dev/null; then ok "python $m"; else warn "python $m 없음 → pip install --user -r app/analysis/requirements.txt"; fi
  done
fi

echo "== 계정 =="
if [ "$(id -u)" = "0" ]; then warn "root 실행 중 → Serverpod 임베디드 PostgreSQL 사용 불가 (--no-database 권장)"; else ok "일반 사용자 $(id -un)"; fi

echo "== 네트워크 =="
if [ -e /proc/net/if_inet6 ] && [ -s /proc/net/if_inet6 ]; then ok "IPv6 사용 가능"; else bad "IPv6 없음 → Serverpod 4.x 서버 시작 실패 (anyIPv6 바인딩). 플랜 A 사용"; fi
if command -v curl >/dev/null 2>&1; then
  code=$(curl -s -o /dev/null -m 8 -w "%{http_code}" https://pub.dev/api/packages/jaspr || true)
  [ "$code" = "200" ] && ok "pub.dev 접근 가능" || bad "pub.dev 접근 불가($code) → 패키지 설치 불가, 의존성 없는 코드로 진행"
fi

echo "== 포트 =="
for p in 8080 8081 8082; do
  if (exec 3<>/dev/tcp/127.0.0.1/$p) 2>/dev/null; then warn "$p 사용 중"; else ok "$p 비어 있음"; fi
done
