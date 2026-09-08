#!/usr/bin/env bash
# ============================================================
# install.sh — Instalador do PubMed Analyzer
#
# Copia o script e seus módulos para INSTALL_DIR (padrão
# /usr/local/lib/pubmed-analyzer), cria o link em BIN_DIR
# (padrão /usr/local/bin) e gera ~/.pubmed_analyzer.conf.
#
# INSTALL_DIR e BIN_DIR podem ser sobrescritos via ambiente (útil
# para testes sem root). Usa sudo apenas quando necessário.
# ============================================================
set -euo pipefail

# Resolve o diretório real deste script (segue links simbólicos).
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
PROJECT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

INSTALL_DIR="${INSTALL_DIR:-/usr/local/lib/pubmed-analyzer}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
SCRIPT_NAME="analyze.sh"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}Instalando PubMed Analyzer...${NC}"

# 1. Verifica dependências
command -v curl >/dev/null 2>&1 || { echo -e "${RED}Erro: curl não encontrado. Instale o curl.${NC}"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo -e "${RED}Erro: jq não encontrado. Instale o jq.${NC}"; exit 1; }

# 2. Cria o diretório de instalação (usa sudo apenas se necessário)
if mkdir -p "$INSTALL_DIR" 2>/dev/null; then
    :
else
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown -R "$(id -un)" "$INSTALL_DIR"
fi

# 3. Copia os arquivos necessários
cp "$PROJECT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/"
cp -R "$PROJECT_DIR/lib" "$INSTALL_DIR/"

# 4. Ajusta permissões (script executável, módulos legíveis)
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
chmod -R a+rX "$INSTALL_DIR"

# 5. Cria/atualiza o link simbólico (usa sudo apenas se necessário)
if ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$BIN_DIR/pubmed-analyzer" 2>/dev/null; then
    :
else
    sudo ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$BIN_DIR/pubmed-analyzer"
fi

# 6. Cria o arquivo de configuração modelo, se não existir
CONF_FILE="$HOME/.pubmed_analyzer.conf"
if [ ! -f "$CONF_FILE" ]; then
    cat > "$CONF_FILE" << 'EOF'
# Configurações do PubMed Analyzer
# Descomente e ajuste conforme necessário.

# Número máximo de resultados padrão (inteiro ou 'all')
#DEFAULT_MAX_RESULTS=200

# Resultados por página na interface interativa
#RESULTS_PER_PAGE=10

# Idioma da interface: pt ou en
#LANG_UI="pt"

# Arquivo que contém a chave de API
#API_KEY_FILE="$HOME/.pubmed_api_key"
EOF
    echo -e "${GREEN}Arquivo de configuração criado em $CONF_FILE${NC}"
else
    echo -e "${YELLOW}Arquivo de configuração já existe: $CONF_FILE (mantido)${NC}"
fi

echo -e "${GREEN}Instalação concluída. Use 'pubmed-analyzer' para executar.${NC}"
