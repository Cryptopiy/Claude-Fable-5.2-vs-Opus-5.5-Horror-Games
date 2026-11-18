#!/bin/bash
# Бережём видеокарту: ждать, пока её загрузка опустится ниже порога (по умолчанию 70%), не дольше 90 с.
# Использование: source tools/dev/gpu_guard.sh; gpu_wait [порог]
gpu_util() {
  nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '
}
gpu_wait() {
  local lim="${1:-70}" t=0 u
  while :; do
    u="$(gpu_util)"
    [ -z "$u" ] && return 0
    [ "$u" -lt "$lim" ] && return 0
    [ $t -ge 90 ] && { echo "[gpu] загрузка ${u}% дольше 90 с — запускаю всё равно (одно окно, 30 fps)"; return 0; }
    sleep 3; t=$((t+3))
  done
}
