#!/usr/bin/env bash
# Roda todos os testes automáticos. Uso: GODOT=/caminho/do/godot ./tests/run_all.sh
GODOT="${GODOT:-godot}"
status=0
for t in tests/test_*.tscn; do
	echo "== $t"
	"$GODOT" --headless --path . "res://$t" 2>&1 | grep -E "ok  |FAIL|FALHAS|ERROR" || true
	"$GODOT" --headless --path . "res://$t" >/dev/null 2>&1 || status=1
done
exit $status
