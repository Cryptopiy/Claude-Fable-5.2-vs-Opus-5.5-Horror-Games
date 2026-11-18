#!/usr/bin/env bash
# Запуск для разработки. Окно без фокуса и спрятано у панели задач, чтобы не мешать работе за ПК.
#   tools/dev.sh tour                — скриншоты точек обзора в shots/
#   tools/dev.sh run [args…]         — обычный запуск с окном (без фокуса)
#   tools/dev.sh bot [args…]         — бот проходит игру без окна (--headless)
#   tools/dev.sh shot <args…>        — произвольные аргументы игры, окно спрятано
#   tools/dev.sh import              — импорт ресурсов
# Тестовые окна — без звука (--audio-driver Dummy), чтобы не мешать пользователю.
# Разрешение окна: RES=1920x1080 tools/dev.sh shot … (по умолчанию 1280x720). Godot: $GODOT или W:\Godot…
cd "$(dirname "$0")/.."
GD="${GODOT:-}"
if [ -z "$GD" ] || [ ! -x "$GD" ]; then
	for c in "/w/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" "$USERPROFILE/tools/godot/Godot_v4.7.2-stable_win64_console.exe"; do
		[ -x "$c" ] && GD="$c" && break
	done
fi
mode="$1"; shift
# Бережём видеокарту: окно рендерит не чаще MAXFPS (по умолчанию 30), и перед запуском ждём, пока GPU не остынет и не
# освободится (другие окна Godot/игры). Загрузка, температура — nvidia-smi; без него проверка пропускается.
SMI="/c/WINDOWS/system32/nvidia-smi.exe"
gpu_guard() {
	[ -x "$SMI" ] || return 0
	for i in $(seq 1 60); do
		read -r util temp <<<"$("$SMI" --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits | head -1 | tr -d ',')"
		if [ "${util:-0}" -lt 70 ] && [ "${temp:-0}" -lt 80 ]; then return 0; fi
		echo "GPU занят (загрузка ${util}%, ${temp}°C) — жду" >&2
		sleep 5
	done
	echo "GPU так и не освободился — запускаю всё равно" >&2
}
park() {
	gpu_guard
	printf '[display]\nwindow/size/no_focus=true\n' > override.cfg
	trap 'rm -f override.cfg' EXIT
}
case "$mode" in
	import) "$GD" --headless --path . --import ;;
	tour) park; "$GD" --path . --position 1850,1150 --resolution ${RES:-1280x720} --max-fps ${MAXFPS:-30} --audio-driver Dummy -- --tour --windowed "$@" ;;
	shot) park; "$GD" --path . --position 1850,1150 --resolution ${RES:-1280x720} --max-fps ${MAXFPS:-30} --audio-driver Dummy -- --windowed "$@" ;;
	run) park; "$GD" --path . --position 1850,1150 --resolution ${RES:-1280x720} --max-fps ${MAXFPS:-30} --audio-driver Dummy -- --windowed "$@" ;;
	bot) "$GD" --headless --path . -- --bot "$@" ;;
	*) echo "режимы: import tour run bot shot" ;;
esac
