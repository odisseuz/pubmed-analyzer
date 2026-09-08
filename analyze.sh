#!/usr/bin/env bash
# ============================================================
# PubMed Analyzer
# ============================================================
#
# Busca artigos no PubMed via NCBI E-utilities. Dois modos de uso:
#   - Interativo (padrão): navegação, estatísticas e exportação em menu.
#   - CLI (não interativo): para automações, cron e integrações.
#
# DEPENDÊNCIAS
#   - bash 3.2+ (compatível com macOS e Linux)
#   - curl  (requisições HTTP)
#   - jq    (parse de JSON e encoding de URL)
#
# USO (interativo)
#   ./analyze.sh "termo de busca"
#   ./analyze.sh "cancer AND immunotherapy" "diabetes type 2"
#
# USO (CLI, requer --query)
#   ./analyze.sh --query "cancer" --max 50 --output resultados.csv
#   ./analyze.sh -q "diabetes" -y 2020-2024 -s pub_date -t review -o dados.json
#   ./analyze.sh --query "alzheimer" --max 20        # CSV no stdout
#   ./analyze.sh --help
#
# IDIOMA
#   -l, --lang pt|en seleciona o idioma. Sem a flag, o modo interativo
#   detecta a partir da variável de ambiente LANG.
#
# CHAVE DE API (OPCIONAL, RECOMENDADA)
#   Aumenta o limite de requisições (10 req/s com chave vs 3 req/s sem).
#   Defina NCBI_API_KEY ou salve a chave em ~/.pubmed_api_key.
#   Obtenha uma em: https://www.ncbi.nlm.nih.gov/account/
#
# SAÍDAS GERADAS
#   - search_logs/search_*.txt : registro imutável (UTC) de cada busca
#   - pubmed_results_*.csv     : resultados em CSV
#   - pubmed_raw_*.json        : JSON bruto do esummary + PMIDs
#   - pubmed_pmids_*.txt       : lista de PMIDs (um por linha)
#
# LIMITAÇÕES
#   - A API do NCBI limita o volume de requisições; sem chave o limite
#     é menor (3 req/s) e buscas muito grandes podem demorar.
#   - Buscas com mais de 100.000 artigos são truncadas por segurança.
#   - Campos com quebras de linha/tabulação podem não ser preservados
#     perfeitamente no CSV/TSV.
# ============================================================
set -euo pipefail

# Resolve o caminho real do script, seguindo links simbólicos (para o
# executável instalado via symlink continuar localizando lib/).
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/config.sh"

# Carrega configurações do usuário (se existirem), permitindo sobrescrever os padrões.
USER_CONF="$HOME/.pubmed_analyzer.conf"
if [ -f "$USER_CONF" ]; then
    source "$USER_CONF"
fi

source "$LIB_DIR/functions.sh"
source "$LIB_DIR/ui.sh"

# Carrega (ou recarrega) o arquivo de mensagens do idioma escolhido.
load_i18n() {
  source "$LIB_DIR/i18n_${LANG_UI}.sh"
}
load_i18n

# Trap para Ctrl+C
trap 'echo -e "\n${YELLOW}${MSG_INTERRUPTED}${NC}"; exit 130' INT

print_usage() {
  printf '%s\n' "$MSG_USAGE"
}

# Variáveis de estado do modo CLI
CLI_MODE=0
CLI_QUERY=""
CLI_MAX=""
CLI_YEARS=""
CLI_SORT=""
CLI_TYPE=""
CLI_OUTPUT=""
CLI_NO_LOG=0
CLI_HAS_FLAGS=0
CLI_LANG_SET=0
CLI_HELP=0
POSITIONAL=()

parse_cli_args() {
  CLI_MODE=0
  CLI_QUERY=""
  CLI_MAX=""
  CLI_YEARS=""
  CLI_SORT=""
  CLI_TYPE=""
  CLI_OUTPUT=""
  CLI_NO_LOG=0
  CLI_HAS_FLAGS=0
  CLI_LANG_SET=0
  CLI_HELP=0
  POSITIONAL=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -q|--query)
        [ $# -ge 2 ] || { printf "${RED}${MSG_ERR_OPTION_REQUIRES_VALUE}${NC}\n" "$1" >&2; exit 1; }
        CLI_QUERY="$2"; CLI_MODE=1; shift 2
        ;;
      -m|--max)
        [ $# -ge 2 ] || { printf "${RED}${MSG_ERR_OPTION_REQUIRES_VALUE}${NC}\n" "$1" >&2; exit 1; }
        CLI_MAX="$2"; CLI_HAS_FLAGS=1; shift 2
        ;;
      -y|--years)
        [ $# -ge 2 ] || { printf "${RED}${MSG_ERR_OPTION_REQUIRES_VALUE}${NC}\n" "$1" >&2; exit 1; }
        CLI_YEARS="$2"; CLI_HAS_FLAGS=1; shift 2
        ;;
      -s|--sort)
        [ $# -ge 2 ] || { printf "${RED}${MSG_ERR_OPTION_REQUIRES_VALUE}${NC}\n" "$1" >&2; exit 1; }
        CLI_SORT="$2"; CLI_HAS_FLAGS=1; shift 2
        ;;
      -t|--type)
        [ $# -ge 2 ] || { printf "${RED}${MSG_ERR_OPTION_REQUIRES_VALUE}${NC}\n" "$1" >&2; exit 1; }
        CLI_TYPE="$2"; CLI_HAS_FLAGS=1; shift 2
        ;;
      -o|--output)
        [ $# -ge 2 ] || { printf "${RED}${MSG_ERR_OPTION_REQUIRES_VALUE}${NC}\n" "$1" >&2; exit 1; }
        CLI_OUTPUT="$2"; CLI_HAS_FLAGS=1; shift 2
        ;;
      -l|--lang)
        [ $# -ge 2 ] || { printf "${RED}${MSG_ERR_OPTION_REQUIRES_VALUE}${NC}\n" "$1" >&2; exit 1; }
        case "$2" in
          pt|en) LANG_UI="$2"; load_i18n; CLI_LANG_SET=1 ;;
          *) printf "${RED}${MSG_ERR_INVALID_LANG}${NC}\n" "$2" >&2; exit 1 ;;
        esac
        shift 2
        ;;
      --no-log)
        CLI_NO_LOG=1; CLI_HAS_FLAGS=1; shift 1
        ;;
      -h|--help)
        CLI_HELP=1; shift 1
        ;;
      --)
        shift
        while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done
        break
        ;;
      -*)
        printf "${RED}${MSG_ERR_UNKNOWN_OPTION}${NC}\n" "$1" >&2
        print_usage >&2
        exit 1
        ;;
      *)
        POSITIONAL+=("$1"); shift 1
        ;;
    esac
  done
}

# Executa o modo não interativo (busca + exportação + log).
run_cli_mode() {
  local query="$CLI_QUERY"
  local max="$CLI_MAX"
  local years="$CLI_YEARS"
  local sort="${CLI_SORT:-relevance}"
  local type="$CLI_TYPE"
  local output="$CLI_OUTPUT"
  local no_log="$CLI_NO_LOG"

  load_api_key_noninteractive

  # --max
  local normalized_max
  normalized_max=$(validate_max "$max") || {
    printf "${RED}${MSG_ERR_INVALID_MAX}${NC}\n" "$max" >&2
    return 1
  }
  max="$normalized_max"

  # --sort
  sort=$(printf '%s' "$sort" | tr '[:upper:]' '[:lower:]')
  if ! is_valid_sort "$sort"; then
    printf "${RED}${MSG_ERR_INVALID_SORT}${NC}\n" "$sort" >&2
    return 1
  fi

  # --years
  local y
  y=$(parse_years "$years") || {
    printf "${RED}${MSG_ERR_INVALID_YEARS}${NC}\n" "$years" >&2
    return 1
  }
  local mindate="${y%%:*}"
  local maxdate="${y#*:}"

  # --type
  if [ -n "$type" ]; then
    type=$(printf '%s' "$type" | tr '[:upper:]' '[:lower:]')
  fi
  if [ -n "$type" ] && [ "$type" != "any" ] && ! is_valid_publication_type "$type"; then
    printf "${YELLOW}${MSG_WARN_UNKNOWN_TYPE}${NC}\n" "$type" >&2
    type=""
  fi

  # query final (com filtro de tipo)
  local final_query
  final_query=$(build_final_query "$query" "$type")
  QUERY="$final_query"

  # busca
  local rc=0
  search_pubmed "$final_query" "$max" "$sort" "$mindate" "$maxdate" || rc=$?

  if [ $rc -eq 6 ]; then
    if [ "$no_log" = "0" ]; then
      save_search_config "$final_query" "$max" "$sort" "$mindate" "$maxdate" "0"
    fi
    printf "${YELLOW}${MSG_NO_RESULTS_FOR}${NC}\n" "$query" >&2
    return 6
  fi

  if [ $rc -ne 0 ]; then
    printf "${RED}${MSG_SEARCH_NOT_COMPLETED}${NC}\n" >&2
    return $rc
  fi

  local pmids="$PMIDS"
  local total_loaded
  total_loaded=$(printf '%s\n' "$pmids" | tr ',' '\n' | wc -l | tr -d ' ')

  if [ "$no_log" = "0" ]; then
    save_search_config "$final_query" "$max" "$sort" "$mindate" "$maxdate" "$total_loaded"
  fi

  rc=0
  fetch_and_populate_arrays "$pmids" || rc=$?
  if [ $rc -ne 0 ]; then
    printf "${RED}${MSG_FETCH_FAILED}${NC}\n" "$rc" >&2
    return $rc
  fi

  if [ -z "$output" ]; then
    export_csv "-"
  else
    case "$output" in
      *.csv)  export_csv "$output" ;;
      *.json) export_json "$output" ;;
      *.txt)  export_pmids "$output" ;;
      *.bib)  export_bib "$output" ;;
      *)
        printf "${RED}${MSG_ERR_UNKNOWN_OUTPUT_EXT}${NC}\n" "$output" >&2
        return 1
        ;;
    esac
  fi

  return 0
}

# Realiza um ciclo completo de busca (interativo).
run_search() {
  local term="$1"

  warn_if_suspicious_term "$term"

  read_max_results
  ask_search_parameters

  echo -e "${CYAN}${MSG_SEARCHING_RESULTS}${NC}"

  if ! search_pubmed "$term" "$MAX_RESULTS" "$SORT_ORDER" "$MINDATE" "$MAXDATE"; then
    echo -e "${RED}${MSG_SEARCH_NOT_COMPLETED}${NC}"
    return 1
  fi

  local pmids="$PMIDS"
  if [ -z "$pmids" ] || [ "$pmids" = "null" ]; then
    printf "${RED}${MSG_NO_RESULTS_FOR}${NC}\n" "$term"
    return 1
  fi

  local total_loaded
  total_loaded=$(printf '%s\n' "$pmids" | tr ',' '\n' | wc -l | tr -d ' ')

  save_search_config "$term" "$MAX_RESULTS" "$SORT_ORDER" "$MINDATE" "$MAXDATE" "$total_loaded"

  echo -e "${CYAN}${MSG_GETTING_DETAILS}${NC}"
  if ! fetch_and_populate_arrays "$pmids"; then
    echo -e "${RED}${MSG_FETCH_DETAILS_FAILED}${NC}"
    return 1
  fi

  PMIDS="$pmids"
  TOTAL_RESULTS="$total_loaded"
  TOTAL=${#IDS[@]}
  PAGE=1
  TOTAL_PAGES=$(( (TOTAL + RESULTS_PER_PAGE - 1) / RESULTS_PER_PAGE ))
  return 0
}

# ============================================================
# Início da execução
# ============================================================

parse_cli_args "$@"

# No modo interativo (sem --lang), detecta o idioma a partir de LANG.
if [ "$CLI_LANG_SET" = "0" ] && [ "$CLI_MODE" = "0" ]; then
  case "${LANG:-}" in
    pt*) LANG_UI="pt" ;;
    *)   LANG_UI="en" ;;
  esac
  load_i18n
fi

if [ "$CLI_HELP" = "1" ]; then
  print_usage
  exit 0
fi

# Verifica dependências (necessárias para busca)
command -v curl >/dev/null 2>&1 || { printf "${RED}${MSG_ERR_CURL_NOT_FOUND}${NC}\n"; exit 1; }
command -v jq   >/dev/null 2>&1 || { printf "${RED}${MSG_ERR_JQ_NOT_FOUND}${NC}\n"; exit 1; }

if [ "$CLI_MODE" = "1" ]; then
  run_cli_mode || exit $?
  exit 0
fi

# Modo interativo
if [ "$CLI_HAS_FLAGS" = "1" ]; then
  printf "${RED}${MSG_ERR_CLI_REQUIRES_QUERY}${NC}\n" >&2
  print_usage >&2
  exit 1
fi

if [ "${#POSITIONAL[@]}" -eq 0 ]; then
  print_usage
  exit 1
fi

setup_api_key

# Loop principal sobre cada termo (modo interativo)
for QUERY in "${POSITIONAL[@]}"; do
  printf "${CYAN}${MSG_SEARCH_TERM}${NC} %s\n" "$QUERY"
  run_search "$QUERY" || continue

  while true; do
    display_articles_page "$PAGE" "$TOTAL" "$RESULTS_PER_PAGE"

    read -p "$MSG_PROMPT_CHOICE " CHOICE
    case "$CHOICE" in
      n|N)
        if [ $PAGE -lt $TOTAL_PAGES ]; then
          PAGE=$((PAGE+1))
        else
          echo -e "${YELLOW}${MSG_LAST_PAGE}${NC}"
          sleep 1
        fi
        ;;
      p|P)
        if [ $PAGE -gt 1 ]; then
          PAGE=$((PAGE-1))
        else
          echo -e "${YELLOW}${MSG_FIRST_PAGE}${NC}"
          sleep 1
        fi
        ;;
      a|A)
        START_NUM=$(( (PAGE-1)*RESULTS_PER_PAGE + 1 ))
        END_NUM=$(( (PAGE-1)*RESULTS_PER_PAGE + (TOTAL - (PAGE-1)*RESULTS_PER_PAGE < RESULTS_PER_PAGE ? TOTAL - (PAGE-1)*RESULTS_PER_PAGE : RESULTS_PER_PAGE) ))
        read -p "$(printf "${MSG_ENTER_ARTICLE_NUMBER}" "$START_NUM" "$END_NUM") " ART_NUM
        if [[ "$ART_NUM" =~ ^[0-9]+$ ]] && [ "$ART_NUM" -ge $START_NUM ] && [ "$ART_NUM" -le $END_NUM ]; then
          INDEX=$(( ART_NUM - 1 ))
          URL="https://pubmed.ncbi.nlm.nih.gov/${IDS[$INDEX]}/"
          printf "${MSG_OPENING}\n" "$URL"
          open_url "$URL"
        else
          echo -e "${RED}${MSG_INVALID_NUMBER}${NC}"
        fi
        ;;
      o|O)
        ENCODED_QUERY=$(url_encode "$QUERY")
        SEARCH_URL="https://pubmed.ncbi.nlm.nih.gov/?term=${ENCODED_QUERY}&sort=${SORT_ORDER}"
        [ -n "$MINDATE" ] && SEARCH_URL="${SEARCH_URL}&date_range=${MINDATE}-${MAXDATE}"
        printf "${MSG_OPENING_PUBMED}\n" "$SEARCH_URL"
        open_url "$SEARCH_URL"
        ;;
      s|S)
        clear
        print_header
        printf "${CYAN}${MSG_STATS_FOR}${NC}\n\n" "$QUERY"
        TOP_JOURNALS=$(printf '%s\n' "${SOURCES[@]}" | sort | uniq -c | sort -nr | head -n 5 || true)
        TOP_AUTHORS=$(printf '%s\n' "${AUTHORS[@]}" | tr ',' '\n' | sed 's/^ //; s/ $//' | sort | uniq -c | sort -nr | head -n 5 || true)
        YEARS=$(printf '%s\n' "${DATES[@]}" | grep -oE '^[0-9]{4}' | sort -n | uniq -c || true)
        TOTAL_YEARS=$(echo "$YEARS" | wc -l | tr -d ' ')
        YEARS_TOP=$(echo "$YEARS" | sort -nr | head -n 5 || true)
        print_stats "$TOP_JOURNALS" "$TOP_AUTHORS" "$YEARS_TOP" "$TOTAL_YEARS"
        echo -e "\n${MSG_PRESS_ENTER_BACK}"
        read -r
        ;;
      c|C)
        export_csv
        echo -e "\n${MSG_PRESS_ENTER_CONTINUE}"
        read -r
        ;;
      j|J)
        export_json
        echo -e "\n${MSG_PRESS_ENTER_CONTINUE}"
        read -r
        ;;
      x|X)
        export_pmids
        echo -e "\n${MSG_PRESS_ENTER_CONTINUE}"
        read -r
        ;;
      b|B)
        export_bib
        echo -e "\n${MSG_PRESS_ENTER_CONTINUE}"
        read -r
        ;;
      r|R)
        clear
        print_header
        echo -e "\n${CYAN}${MSG_REFINE}${NC}\n"
        printf "${GREEN}${MSG_CURRENT_TERM}${NC}\n" "$QUERY"
        read -p "$(printf "${MSG_NEW_TERM}" "$QUERY") " NEW_QUERY
        if [ -n "$NEW_QUERY" ]; then
          QUERY="$NEW_QUERY"
        fi
        if run_search "$QUERY"; then
          printf "\n${GREEN}${MSG_REFINED}${NC}\n" "$TOTAL" "${TOTAL_PUBMED:-0}"
        else
          echo -e "\n${RED}${MSG_REFINE_FAILED}${NC}"
        fi
        read -p "${MSG_PRESS_ENTER_CONTINUE} " -r
        ;;
      q|Q)
        echo -e "${GREEN}${MSG_EXITING}${NC}"
        exit 0
        ;;
      "" )
        if [ $PAGE -lt $TOTAL_PAGES ]; then
          PAGE=$((PAGE+1))
        fi
        ;;
      *)
        START_NUM=$(( (PAGE-1)*RESULTS_PER_PAGE + 1 ))
        END_NUM=$(( (PAGE-1)*RESULTS_PER_PAGE + (TOTAL - (PAGE-1)*RESULTS_PER_PAGE < RESULTS_PER_PAGE ? TOTAL - (PAGE-1)*RESULTS_PER_PAGE : RESULTS_PER_PAGE) ))
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge $START_NUM ] && [ "$CHOICE" -le $END_NUM ]; then
          INDEX=$(( CHOICE - 1 ))
          show_article_details "$INDEX"
        else
          echo -e "${RED}${MSG_INVALID_OPTION}${NC}"
          sleep 1
        fi
        ;;
    esac
  done
done
