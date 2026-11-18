#!/bin/bash
# Замер нагрузки кадра: tools/dev/fps.sh [аргументы игры…]
# Видеокарту не гоняем на пределе: vsync включён, кадр ограничен 30 fps; движок сам меряет время отрисовки
# кадра на GPU и на CPU (main.gd, --fps). Печатает средние gpu_ms, cpu_ms, треугольники и вызовы отрисовки.
cd "$(dirname "$0")/../.."
GD="${GODOT:-$USERPROFILE/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
[ -x "$GD" ] || GD="W:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
source tools/dev/gpu_guard.sh
gpu_wait 70
printf '[display]\n\nwindow/size/no_focus=true\n' > override.cfg
tmp="$(mktemp -d)"
timeout 60 "$GD" --path . --windowed --max-fps 30 --audio-driver Dummy --resolution 1280x720 --position 1850,1150 -- --fps --shot="$tmp/f.png" --wait=9 "$@" 2>&1 \
  | grep "LOG fps=" | tail -3 | awk '{for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]=="gpu_ms")g+=a[2]; if(a[1]=="cpu_ms")c+=a[2]; if(a[1]=="tris")t+=a[2]; if(a[1]=="draws")d+=a[2]} n++} END{if(n) printf "gpu_ms=%.2f cpu_ms=%.2f tris=%.0f draws=%.0f\n", g/n, c/n, t/n, d/n}'
rm -rf "$tmp" override.cfg
