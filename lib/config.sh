#!/usr/bin/env bash
# ============================================================
# config.sh — Configurações e variáveis globais do PubMed Analyzer
#
# Este arquivo deve ser carregado com `source` APÓS a definição
# das variáveis SCRIPT_DIR e LIB_DIR no script principal.
# ============================================================

VERSION="2.0.0"

# Idioma da interface (pt ou en). Pode ser sobrescrito por -l/--lang.
LANG_UI="pt"

# Cores (opcional; desativadas quando a saída não é um terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''
fi

# Endereço base da API NCBI E-utilities
BASE_URL="https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

# Interface / paginação (podem ser sobrescritas em ~/.pubmed_analyzer.conf)
RESULTS_PER_PAGE=10
DEFAULT_MAX_RESULTS=200

# Chave de API (o caminho pode ser sobrescrito em ~/.pubmed_analyzer.conf)
API_KEY_FILE="$HOME/.pubmed_api_key"
API_KEY=""

# Diretório de logs (criado sob demanda)
LOG_DIR="$SCRIPT_DIR/search_logs"

# Arrays globais de resultados (preenchidos por fetch_and_populate_arrays)
TITLES=()
SOURCES=()
IDS=()
AUTHORS=()
DATES=()
VOLUMES=()
ISSUES=()
PAGES=()
DOIS=()

# Metadados da busca corrente (usados por logging e exportação)
QUERY=""
MINDATE=""
MAXDATE=""
SORT_ORDER="relevance"
MAX_RESULTS=""
PMIDS=""
TOTAL_RESULTS=0
TOTAL_PUBMED=""
ESEARCH_URL=""
SUMMARY_JSONS=()
SEARCH_UTC_TS=""
