#!/usr/bin/env bash
# Roda todos os testes automáticos. Uso: GODOT=/caminho/do/godot ./tests/run_all.sh
# Sem GODOT, usa o Godot da Steam desta máquina. Falha (código 2) se o executável não existir,
# para nunca "passar" sem ter rodado nada.
GODOT="${GODOT:-/var/mnt/HD/SteamLibrary/steamapps/common/Godot Engine/godot.x11.opt.tools.64}"
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "ERRO: Godot não encontrado em '$GODOT'. Defina GODOT=/caminho/do/godot." >&2
	exit 2
fi
status=0
for t in tests/test_*.tscn; do
	echo "== $t"
	out="$("$GODOT" --headless --path . "res://$t" 2>&1)"
	code=$?
	echo "$out" | grep -E "ok  |FAIL|FALHAS|SCRIPT ERROR|Parse Error" || true
	# Falha se o teste saiu com erro, se não chegou ao fim (sem "FALHAS:") ou se teve erro de script.
	if [ $code -ne 0 ] || ! echo "$out" | grep -q "FALHAS: 0\|^OK$" || echo "$out" | grep -q "SCRIPT ERROR"; then
		echo "   >> FALHOU: $t"
		status=1
	fi
done
[ $status -eq 0 ] && echo "TODOS OS TESTES PASSARAM" || echo "HÁ TESTES FALHANDO"
exit $status
