#!/bin/bash
# «Золотой набор» кадров: tools/dev/shots.sh <папка> [фильтр-регулярка] [параллельно=1, не больше 2]
# LIST=<файл> — другой список (по умолчанию tools/dev/golden.txt); EXTRA="<аргументы>" — добавить ко всем кадрам (например --snow=2).
# Список кадров — tools/dev/golden.txt: имя|секунды|аргументы игры. Окна без фокуса, за краем экрана.
# Бережём видеокарту: кадр ограничен 30 fps, окна по одному, перед запуском ждём, пока загрузка карты < 70%. Без звука.
cd "$(dirname "$0")/../.."
GD="${GODOT:-$USERPROFILE/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
[ -x "$GD" ] || GD="W:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
out="$1"; filt="${2:-.}"; par="${3:-1}"
[ "$par" -gt 2 ] && par=2
source "$(dirname "$0")/gpu_guard.sh"
mkdir -p "$out"
abs="$(cd "$out" && pwd -W 2>/dev/null || pwd)"
printf '[display]\n\nwindow/size/no_focus=true\n' > override.cfg
n=0
while IFS='|' read -r name wait args; do
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  echo "$name" | grep -qE "$filt" || continue
  gpu_wait 70
  ( timeout 120 "$GD" --path . --windowed --max-fps 30 --audio-driver Dummy --resolution ${RES:-1280x720} --position 1850,1150 -- --shot="$abs/$name.png" --wait="$wait" $args $EXTRA 2>&1 \
      | grep -E "SCRIPT ERROR|ERROR|Parse|SHOT" | grep -v "^\s*at:" | sed "s/^/[$name] /" | head -8 ) &
  n=$((n+1))
  if [ $((n % par)) -eq 0 ]; then wait; fi
done < "${LIST:-tools/dev/golden.txt}"
wait
rm -f override.cfg
