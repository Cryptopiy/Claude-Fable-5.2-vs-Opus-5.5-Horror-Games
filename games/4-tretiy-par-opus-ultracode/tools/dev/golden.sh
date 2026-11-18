#!/usr/bin/env bash
# «Золотой набор» кадров: tools/dev/golden.sh <папка-результат> [--golden=фильтр] [--quality=N]
# Снимает в shots/golden (окно без фокуса у панели задач), потом копирует в <папка-результат>.
cd "$(dirname "$0")/../.."
dst="${1:-shots/golden_copy}"; shift
rm -rf shots/golden
timeout 900 tools/dev.sh shot --golden "$@" > "$TEMP/golden.log" 2>&1
grep -E "SCRIPT ERROR|ERROR:" "$TEMP/golden.log" | grep -v "resources still in use" | head -10
grep -c "^golden " "$TEMP/golden.log"
mkdir -p "$dst"
cp shots/golden/*.png shots/golden/stats.txt "$dst"/ 2>/dev/null
echo "-> $dst"
