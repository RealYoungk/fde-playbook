#!/usr/bin/env bash
# 과제 작업 폴더에 규칙, 스킬, 기록 템플릿, (선택) 앱 템플릿을 설치한다.
# 기존 파일은 덮어쓰지 않는다.
#
# 사용: bash fde-playbook/scripts/install.sh <과제폴더> [옵션...]
#   --app        app/core, web_app, analysis, data 템플릿도 복사
#   --minimal    우리 스킬 + Jaspr + frontend-design만 (Serverpod, Impeccable 제외)
#   --all        --app과 같음 (예전 옵션 호환)
# 기본 설치: 우리 스킬 11 + Jaspr 5 + Serverpod 29 + frontend-design + impeccable = 47개
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="${1:-.}"
shift || true
WITH_APP=0; WITH_SP=all; WITH_IMP=1
for a in "$@"; do
  case "$a" in
    --app) WITH_APP=1 ;;
    --serverpod|--serverpod-all) WITH_SP=all ;;
    --impeccable) WITH_IMP=1 ;;
    --minimal) WITH_SP=none; WITH_IMP=0 ;;
    --all) WITH_APP=1; WITH_SP=all; WITH_IMP=1 ;;
    *) echo "알 수 없는 옵션: $a" >&2; exit 1 ;;
  esac
done
mkdir -p "$DST"
DST="$(cd "$DST" && pwd)"

# 1) AGENTS.md: 과제 쪽에 이미 있으면 덮지 않고 뒤에 붙인다
if [ -f "$DST/AGENTS.md" ]; then
  if ! grep -q "# 작업 규칙 (FDE 과제용)" "$DST/AGENTS.md"; then
    printf "\n\n" >> "$DST/AGENTS.md"
    cat "$SRC/AGENTS.md" >> "$DST/AGENTS.md"
    echo "AGENTS.md: 기존 파일 뒤에 규칙 추가"
  else
    echo "AGENTS.md: 이미 설치됨"
  fi
else
  cp "$SRC/AGENTS.md" "$DST/AGENTS.md"
  echo "AGENTS.md: 생성"
fi

# 2) 스킬
mkdir -p "$DST/.agents/skills"
install_skills() { # $1: 스킬 폴더들이 있는 디렉터리, $2: 표시 이름
  local n=0
  for d in "$1"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    local name; name="$(basename "$d")"
    if [ ! -e "$DST/.agents/skills/$name" ]; then
      cp -r "$d" "$DST/.agents/skills/$name"
      n=$((n+1))
    fi
  done
  echo "skills ($2): ${n}개 설치"
}
install_skills "$SRC/.agents/skills" "fde-playbook"
install_skills "$SRC/vendor-skills/jaspr" "jaspr"
[ -e "$DST/.agents/skills/frontend-design" ] || cp -r "$SRC/vendor-skills/design/frontend-design" "$DST/.agents/skills/frontend-design"
echo "skills (anthropic frontend-design): 설치"
[ "$WITH_SP" = all ] && install_skills "$SRC/vendor-skills/serverpod" "serverpod"
if [ "$WITH_IMP" = 1 ] && [ ! -e "$DST/.agents/skills/impeccable" ]; then
  cp -r "$SRC/vendor-skills/design/impeccable" "$DST/.agents/skills/impeccable"
  echo "skills (impeccable): 설치"
fi

# 3) 작업 기록 템플릿
mkdir -p "$DST/docs/work"
for f in "$SRC"/docs/templates/*.md; do
  name="$(basename "$f")"
  [ -e "$DST/docs/work/$name" ] || cp "$f" "$DST/docs/work/$name"
done
echo "docs/work: 기록 템플릿 준비"

# 4) 앱 템플릿 (선택)
if [ "$WITH_APP" = 1 ]; then
  if [ -e "$DST/app" ]; then
    echo "app/: 이미 있음, 건너뜀"
  else
    mkdir -p "$DST/app"
    for p in core web_app analysis data; do
      cp -r "$SRC/template/$p" "$DST/app/$p"
      rm -rf "$DST/app/$p/.dart_tool" "$DST/app/$p/build"
    done
    find "$DST/app/analysis" -name __pycache__ -type d -prune -exec rm -rf {} +
    echo "app/: core, web_app, analysis, data 복사 (cd app/web_app && dart pub get && jaspr serve)"
  fi
fi

# 5) .gitignore 보강
if [ -d "$DST/.git" ] || [ -f "$DST/.gitignore" ]; then
  for pat in ".dart_tool/" "__pycache__/"; do
    grep -qx "$pat" "$DST/.gitignore" 2>/dev/null || echo "$pat" >> "$DST/.gitignore"
  done
fi

echo "설치된 스킬 수: $(ls -d "$DST"/.agents/skills/*/ | wc -l)"
echo "완료. 다음: bash $SRC/scripts/env_check.sh"
