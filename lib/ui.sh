#!/usr/bin/env bash
# ============================================================
# ui.sh — Funções de interface com o usuário.
#
# Requer config.sh e functions.sh carregados antes.
# ============================================================

print_header() {
  echo -e "${CYAN}============================================${NC}"
  echo -e "${CYAN}${MSG_HEADER_TITLE}${NC}"
  echo -e "${CYAN}============================================${NC}"
}

open_url() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url"
  elif command -v open >/dev/null 2>&1; then
    open "$url"
  else
    echo -e "${YELLOW}${MSG_CANNOT_OPEN_BROWSER}${NC}"
    printf "${BLUE}${MSG_ACCESS_MANUALLY}${NC}\n" "$url"
  fi
}

# Avisa (sem bloquear) quando o termo parece malformado.
warn_if_suspicious_term() {
  local term="$1"
  if is_suspicious_term "$term"; then
    echo -e "${YELLOW}${MSG_WARN_SUSPICIOUS}${NC}"
    echo -e "${YELLOW}${MSG_WARN_REVIEW_TERM}${NC}"
  fi
}

setup_api_key() {
  if [ -n "${NCBI_API_KEY:-}" ]; then
    API_KEY="$NCBI_API_KEY"
    return
  fi

  if [ -f "$API_KEY_FILE" ]; then
    local key
    key=$(tr -d '[:space:]' < "$API_KEY_FILE")
    if [ -n "$key" ]; then
      API_KEY="$key"
      export NCBI_API_KEY="$API_KEY"
      printf "${GREEN}${MSG_API_KEY_LOADED}${NC}\n" "$API_KEY_FILE"
      return
    fi
  fi

  echo -e "${YELLOW}${MSG_NO_API_KEY}${NC}"
  printf "${BLUE}${MSG_GET_API_KEY}${NC}\n" "https://www.ncbi.nlm.nih.gov/account/"
  echo -e "${MSG_API_KEY_BENEFIT}"
  echo -e "${MSG_API_KEY_PROMPT_CONTINUE}"
  read -p "$MSG_API_KEY_PROMPT " USER_KEY

  USER_KEY=$(echo "$USER_KEY" | tr -d '[:space:]')
  if [ -n "$USER_KEY" ]; then
    API_KEY="$USER_KEY"
    umask 077
    echo "$API_KEY" > "$API_KEY_FILE"
    printf "${GREEN}${MSG_API_KEY_SAVED}${NC}\n" "$API_KEY_FILE"
    export NCBI_API_KEY="$API_KEY"
  else
    echo -e "${YELLOW}${MSG_API_KEY_CONTINUE_WITHOUT}${NC}"
  fi
}

# Carrega a chave de API sem interação (env ou arquivo). Usada no modo CLI.
load_api_key_noninteractive() {
  if [ -n "${NCBI_API_KEY:-}" ]; then
    API_KEY="$NCBI_API_KEY"
    return
  fi
  if [ -f "$API_KEY_FILE" ]; then
    local key
    key=$(tr -d '[:space:]' < "$API_KEY_FILE")
    if [ -n "$key" ]; then
      API_KEY="$key"
      export NCBI_API_KEY="$API_KEY"
    fi
  fi
}

# Pergunta o número máximo de resultados e define a global MAX_RESULTS.
read_max_results() {
  local input
  read -p "$(printf "${MSG_MAX_PROMPT}" "$DEFAULT_MAX_RESULTS") " input

  if [ -z "$input" ]; then
    MAX_RESULTS=$DEFAULT_MAX_RESULTS
  elif [ "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')" = "all" ] || [ "$input" = "0" ]; then
    echo -e "${YELLOW}${MSG_ALL_WARNING}${NC}"
    read -p "$MSG_CONFIRM " CONFIRM
    local confirm_lower
    confirm_lower=$(printf '%s' "$CONFIRM" | tr '[:upper:]' '[:lower:]')
    case "$confirm_lower" in
      s|y|sim|yes) MAX_RESULTS="all" ;;
      *)
        printf "${YELLOW}${MSG_USING_DEFAULT}${NC}\n" "$DEFAULT_MAX_RESULTS"
        MAX_RESULTS=$DEFAULT_MAX_RESULTS
        ;;
    esac
  elif [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -gt 0 ]; then
    MAX_RESULTS=$input
  else
    printf "${RED}${MSG_INVALID_VALUE_DEFAULT}${NC}\n" "$DEFAULT_MAX_RESULTS"
    MAX_RESULTS=$DEFAULT_MAX_RESULTS
  fi
}

# Pergunta parâmetros adicionais da busca.
# Retorna via variáveis globais: MINDATE, MAXDATE, SORT_ORDER
ask_search_parameters() {
  # Intervalo de anos
  read -p "$MSG_YEARS_PROMPT " YEAR_RANGE
  MINDATE=""
  MAXDATE=""
  if [ -n "$YEAR_RANGE" ]; then
    # Aceita formatos: 2010-2020, 2010:2020, 2010
    if [[ "$YEAR_RANGE" =~ ^([0-9]{4})([-:])([0-9]{4})$ ]]; then
      MINDATE="${BASH_REMATCH[1]}"
      MAXDATE="${BASH_REMATCH[3]}"
    elif [[ "$YEAR_RANGE" =~ ^[0-9]{4}$ ]]; then
      MINDATE="$YEAR_RANGE"
      MAXDATE="$YEAR_RANGE"
    else
      echo -e "${YELLOW}${MSG_INVALID_YEAR_RANGE}${NC}"
      YEAR_RANGE=""
    fi
  fi

  # Ordenação
  echo -e "${CYAN}${MSG_SORT_PROMPT}${NC}"
  echo "${MSG_SORT_OPTION_1}"
  echo "${MSG_SORT_OPTION_2}"
  echo "${MSG_SORT_OPTION_3}"
  echo "${MSG_SORT_OPTION_4}"
  read -p "$MSG_SORT_CHOICE " SORT_CHOICE
  case "$SORT_CHOICE" in
    2) SORT_ORDER="pub_date" ;;
    3) SORT_ORDER="first_author" ;;
    4) SORT_ORDER="journal" ;;
    *) SORT_ORDER="relevance" ;;
  esac
}

print_stats() {
  local journals="$1"
  local authors="$2"
  local years_top="$3"
  local total_years="$4"

  echo -e "${YELLOW}${MSG_STAT_JOURNALS}${NC}"
  if [ -n "$journals" ]; then
    echo "$journals" | awk '{printf "  %2d  %s\n", $1, substr($0, index($0,$2))}'
  else
    echo "  ${MSG_NO_DATA}"
  fi

  echo -e "\n${YELLOW}${MSG_STAT_AUTHORS}${NC}"
  if [ -n "$authors" ]; then
    echo "$authors" | awk '{printf "  %2d  %s\n", $1, substr($0, index($0,$2))}'
  else
    echo "  ${MSG_NO_DATA}"
  fi

  echo -e "\n${YELLOW}${MSG_STAT_YEARS}${NC}"
  if [ -n "$years_top" ]; then
    echo "$years_top" | awk -v word="${MSG_ARTICLES}" '{printf "  %s: %d %s\n", $2, $1, word}'
    printf "${CYAN}${MSG_STAT_TOTAL_YEARS}${NC}\n" "$total_years"
  else
    echo "  ${MSG_NO_DATA}"
  fi
}

display_articles_page() {
  local page=$1
  local total=$2
  local per_page=$3

  local start=$(( (page-1) * per_page ))
  local end=$(( start + per_page - 1 ))
  [ $end -ge $total ] && end=$((total-1))

  clear
  print_header
  printf "\n${GREEN}${MSG_RESULTS_FOR}${NC}\n" "$QUERY"
  printf "${CYAN}${MSG_TOTAL_LINE}${NC}\n" "$(pubmed_count_label "$total")" "$total" "$page" "$(( (total + per_page - 1) / per_page ))"
  echo -e "${CYAN}--------------------------------------------${NC}"

  local i
  for ((i=start; i<=end; i++)); do
    local num=$((i+1))
    local title="${TITLES[$i]}"
    local source="${SOURCES[$i]}"
    local pmid="${IDS[$i]}"
    if [ ${#title} -gt 90 ]; then
      title="${title:0:87}..."
    fi
    echo -e "${MAGENTA}[$num]${NC} ${title}"
    echo -e "     ${BLUE}${source}${NC} | PMID: ${pmid}"
  done

  echo -e "\n${CYAN}--------------------------------------------${NC}"
  echo -e "${GREEN}${MSG_OPTIONS}${NC}"
  echo "${MSG_MENU_LINE1}"
  echo "${MSG_MENU_LINE2}"
  echo "${MSG_MENU_LINE3}"
}

show_article_details() {
  local index=$1
  local pmid="${IDS[$index]}"
  local title="${TITLES[$index]}"
  local source="${SOURCES[$index]}"
  local authors="${AUTHORS[$index]}"
  local pubdate="${DATES[$index]}"

  clear
  print_header
  printf "${YELLOW}${MSG_TITLE}${NC} %s\n" "$title"
  printf "${YELLOW}${MSG_JOURNAL}${NC} %s\n" "$source"
  printf "${YELLOW}${MSG_DATE}${NC} %s\n" "$pubdate"
  printf "${YELLOW}${MSG_AUTHORS}${NC} %s\n" "$authors"
  printf "${YELLOW}${MSG_PMID}${NC} %s\n" "$pmid"
  printf "${YELLOW}${MSG_URL}${NC} %s\n" "https://pubmed.ncbi.nlm.nih.gov/$pmid/"

  echo -e "\n${YELLOW}${MSG_ABSTRACT}${NC}"
  local abstract
  abstract=$(get_abstract "$pmid" 2>/dev/null || true)
  if [ -n "$abstract" ]; then
    local abs_section
    abs_section=$(echo "$abstract" | sed -n '/^Abstract/,/^$/p')
    if [ -z "$abs_section" ]; then
      abs_section=$(echo "$abstract" | head -n 40)
    fi
    echo "$abs_section"
  else
    echo "${MSG_ABSTRACT_UNAVAILABLE}"
  fi

  echo -e "\n${MSG_PRESS_ENTER_BACK}"
  read -r
}
