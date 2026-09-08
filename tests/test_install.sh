#!/usr/bin/env bash
# ============================================================
# Testa a instalação (install.sh) em diretórios temporários,
# sem precisar de root.
# Uso: bash tests/test_install.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$SCRIPT_DIR/.install_test.$$"
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

# Isola HOME, INSTALL_DIR e BIN_DIR em diretórios temporários.
export HOME="$TMP_ROOT/home"
mkdir -p "$HOME"
export INSTALL_DIR="$TMP_ROOT/pubmed-analyzer"
export BIN_DIR="$TMP_ROOT/bin"
mkdir -p "$BIN_DIR"

bash "$SCRIPT_DIR/install.sh" >/dev/null

pass=0
fail=0

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass+1)); echo "ok   - $desc"
  else
    fail=$((fail+1)); echo "FAIL - $desc"
  fi
}

assert_ok "analyze.sh copiado"            test -f "$INSTALL_DIR/analyze.sh"
assert_ok "lib/ copiada"                  test -d "$INSTALL_DIR/lib"
assert_ok "link simbólico criado"         test -L "$BIN_DIR/pubmed-analyzer"

if [ "$(readlink "$BIN_DIR/pubmed-analyzer")" = "$INSTALL_DIR/analyze.sh" ]; then
  pass=$((pass+1)); echo "ok   - link aponta para o script real"
else
  fail=$((fail+1)); echo "FAIL - link aponta para o script real"
fi

assert_ok "--help via symlink"            "$BIN_DIR/pubmed-analyzer" --help
assert_ok "conf modelo criado"            test -f "$HOME/.pubmed_analyzer.conf"

echo ""
echo "Resultado: $pass aprovados, $fail falha(s)"
[ "$fail" -eq 0 ]
