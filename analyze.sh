#!/usr/bin/env bash

# ============================================
# PubMed Analyzer - Interface Interativa
# Compatível com Bash 3.2+ (macOS/Linux)
# Suporta busca de todos os resultados (com paginação)
# ============================================
set -euo pipefail

# Cores (opcional)
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

# Configurações
BASE_URL="https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
RESULTS_PER_PAGE=10
DEFAULT_MAX_RESULTS=200
API_KEY_FILE="$HOME/.pubmed_api_key"
API_KEY=""

# Arrays globais (preenchidos para cada busca)
TITLES=()
SOURCES=()
IDS=()
AUTHORS=()
DATES=()

# Trap para Ctrl+C
trap 'echo -e "\n${YELLOW}Interrompido pelo usuário. Saindo...${NC}"; exit 130' INT

# Funções auxiliares
print_header() {
  echo -e "${CYAN}============================================${NC}"
  echo -e "${CYAN}         PubMed Analyzer Interativo${NC}"
  echo -e "${CYAN}============================================${NC}"
}

open_url() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url"
  elif command -v open >/dev/null 2>&1; then
    open "$url"
  else
    echo -e "${YELLOW}Não foi possível abrir o navegador automaticamente.${NC}"
    echo -e "Acesse manualmente: ${BLUE}$url${NC}"
  fi
}

url_encode() {
  jq -s -R -r @uri <<< "$1"
}

is_json() {
  echo "$1" | jq empty >/dev/null 2>&1
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
      echo -e "${GREEN}Chave de API carregada do arquivo $API_KEY_FILE${NC}"
      return
    fi
  fi

  echo -e "${YELLOW}Nenhuma chave de API do NCBI encontrada.${NC}"
  echo -e "Você pode obter uma chave gratuita em ${BLUE}https://www.ncbi.nlm.nih.gov/account/ ${NC}"
  echo -e "Com uma chave, o limite de requisições é maior e a busca é mais rápida."
  echo -e "Se não quiser usar uma chave, pressione Enter (o script funcionará, mas com limites menores)."
  read -p "Digite sua chave de API (ou Enter para continuar sem): " USER_KEY

  USER_KEY=$(echo "$USER_KEY" | tr -d '[:space:]')
  if [ -n "$USER_KEY" ]; then
    API_KEY="$USER_KEY"
    umask 077
    echo "$API_KEY" > "$API_KEY_FILE"
    echo -e "${GREEN}Chave de API salva em $API_KEY_FILE${NC}"
    export NCBI_API_KEY="$API_KEY"
  else
    echo -e "${YELLOW}Continuando sem chave de API (pode haver limites de requisições).${NC}"
  fi
}

# Busca todos os PMIDs (ou um número específico) usando paginação do esearch
# Saída: apenas a string de IDs separados por vírgula, ou retorna 1 se não houver resultados
search_pubmed() {
  local query="$1"
  local max_results="$2"
  local encoded_query
  encoded_query=$(url_encode "$query")

  local retstart=0
  local retmax=10000
  local all_ids=""
  local total_fetched=0
  local fetch_all=false

  if [ "$max_results" = "all" ]; then
    fetch_all=true
  fi

  while true; do
    local search_url="${BASE_URL}/esearch.fcgi?db=pubmed&term=${encoded_query}&retstart=${retstart}&retmax=${retmax}&retmode=json&sort=relevance"
    [ -n "$API_KEY" ] && search_url="${search_url}&api_key=${API_KEY}"

    local response
    response=$(curl -s "$search_url")
    if ! is_json "$response"; then
      echo -e "${RED}Erro: a API do PubMed não retornou JSON válido.${NC}" >&2
      echo -e "${YELLOW}Resposta recebida (primeiros 200 caracteres):${NC}" >&2
      echo "${response:0:200}" >&2
      return 1
    fi

    local batch_ids
    batch_ids=$(echo "$response" | jq -r '.esearchresult.idlist | join(",")')
    local count
    count=$(echo "$response" | jq -r '.esearchresult.idlist | length')

    # Se houver IDs neste lote, adiciona à lista
    if [ -n "$batch_ids" ] && [ "$batch_ids" != "null" ]; then
      if [ -z "$all_ids" ]; then
        all_ids="$batch_ids"
      else
        all_ids="${all_ids},${batch_ids}"
      fi
      total_fetched=$((total_fetched + count))
      # Feedback de progresso (vai para stderr para não poluir a saída)
      printf "\r${CYAN}Buscando... %d IDs obtidos...${NC}" "$total_fetched" >&2
    fi

    # Condições de parada
    if [ "$fetch_all" = false ]; then
      if [ $total_fetched -ge "$max_results" ]; then
        all_ids=$(echo "$all_ids" | cut -d',' -f1-"$max_results")
        break
      fi
      if [ $count -lt $retmax ]; then
        break
      fi
    else
      if [ $count -lt $retmax ]; then
        break
      fi
    fi

    retstart=$((retstart + retmax))

    # Limite de segurança
    if [ $total_fetched -ge 100000 ]; then
      echo -e "${YELLOW}Atingido o limite de segurança de 100.000 artigos. Parando a busca.${NC}" >&2
      break
    fi
  done

  # Remove espaços em branco e verifica se há algo
  all_ids=$(echo "$all_ids" | tr -d '[:space:]')
  if [ -z "$all_ids" ]; then
    echo -e "${YELLOW}Nenhum ID encontrado.${NC}" >&2
    return 1
  fi

  # Imprime apenas a string de IDs no stdout (sem linhas extras)
  echo "$all_ids"
}

# Busca os sumários em blocos de 200 IDs e preenche os arrays globais
fetch_and_populate_arrays() {
  local pmids="$1"
  local chunk_size=200
  local IFS=','
  local -a id_array
  read -ra id_array <<< "$pmids"

  local total=${#id_array[@]}
  local start=0
  local end=0
  local chunk_number=0
  local total_chunks=$(( (total + chunk_size - 1) / chunk_size ))

  TITLES=(); SOURCES=(); IDS=(); AUTHORS=(); DATES=()

  while [ $start -lt $total ]; do
    chunk_number=$((chunk_number + 1))
    end=$((start + chunk_size - 1))
    [ $end -ge $total ] && end=$((total - 1))

    # Feedback do bloco atual (stderr)
    printf "\r${CYAN}Obtendo detalhes... bloco %d de %d (IDs %d-%d)...${NC}" "$chunk_number" "$total_chunks" "$start" "$end" >&2

    local chunk_ids=""
    for ((i=start; i<=end; i++)); do
      if [ -z "$chunk_ids" ]; then
        chunk_ids="${id_array[$i]}"
      else
        chunk_ids="${chunk_ids},${id_array[$i]}"
      fi
    done

    local summary_url="${BASE_URL}/esummary.fcgi?db=pubmed&id=${chunk_ids}&retmode=json"
    [ -n "$API_KEY" ] && summary_url="${summary_url}&api_key=${API_KEY}"

    local response
    response=$(curl -s "$summary_url")
    if ! is_json "$response"; then
      echo -e "${RED}Erro ao obter sumários (bloco $start-$end): resposta não‑JSON.${NC}" >&2
      return 1
    fi

    while IFS= read -r line; do TITLES+=("$line"); done < <(echo "$response" | jq -r '.result | to_entries[] | select(.key != "uids") | .value.title')
    while IFS= read -r line; do SOURCES+=("$line"); done < <(echo "$response" | jq -r '.result | to_entries[] | select(.key != "uids") | .value.source')
    while IFS= read -r line; do IDS+=("$line"); done < <(echo "$response" | jq -r '.result | to_entries[] | select(.key != "uids") | .key')
    while IFS= read -r line; do AUTHORS+=("$line"); done < <(echo "$response" | jq -r '.result | to_entries[] | select(.key != "uids") | .value.authors | map(.name) | join(", ")')
    while IFS= read -r line; do DATES+=("$line"); done < <(echo "$response" | jq -r '.result | to_entries[] | select(.key != "uids") | .value.pubdate')

    start=$((end + 1))
  done

  echo "" >&2  # nova linha após o progresso
  return 0
}

get_abstract() {
  local pmid="$1"
  local fetch_url="${BASE_URL}/efetch.fcgi?db=pubmed&id=${pmid}&rettype=abstract&retmode=text"
  [ -n "$API_KEY" ] && fetch_url="${fetch_url}&api_key=${API_KEY}"
  curl -s "$fetch_url"
}

print_stats() {
  local journals="$1"
  local authors="$2"
  local years_top="$3"
  local total_years="$4"

  echo -e "${YELLOW}Top 5 Periódicos:${NC}"
  if [ -n "$journals" ]; then
    echo "$journals" | awk '{printf "  %2d  %s\n", $1, substr($0, index($0,$2))}'
  else
    echo "  Nenhum dado disponível."
  fi

  echo -e "\n${YELLOW}Top 5 Autores:${NC}"
  if [ -n "$authors" ]; then
    echo "$authors" | awk '{printf "  %2d  %s\n", $1, substr($0, index($0,$2))}'
  else
    echo "  Nenhum dado disponível."
  fi

  echo -e "\n${YELLOW}Anos com mais publicações (Top 5):${NC}"
  if [ -n "$years_top" ]; then
    echo "$years_top" | awk '{printf "  %s: %d artigos\n", $2, $1}'
    echo -e "${CYAN}  (Total de anos distintos: $total_years)${NC}"
  else
    echo "  Nenhum dado disponível."
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
  echo -e "\n${GREEN}Resultados para: ${QUERY}${NC}"
  echo -e "${CYAN}Total: $total artigos | Página $page de $(( (total + per_page - 1) / per_page ))${NC}"
  echo -e "${CYAN}--------------------------------------------${NC}"

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
  echo -e "${GREEN}Opções:${NC}"
  echo "  [n] próxima página   [p] página anterior   [1-10] ver detalhes"
  echo "  [a] abrir artigo no navegador   [o] abrir busca no PubMed"
  echo "  [s] estatísticas   [c] exportar CSV   [q] sair"
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
  echo -e "${YELLOW}Título:${NC} $title"
  echo -e "${YELLOW}Revista:${NC} $source"
  echo -e "${YELLOW}Data:${NC} $pubdate"
  echo -e "${YELLOW}Autores:${NC} $authors"
  echo -e "${YELLOW}PMID:${NC} $pmid"
  echo -e "${YELLOW}URL:${NC} https://pubmed.ncbi.nlm.nih.gov/$pmid/"

  echo -e "\n${YELLOW}Abstract:${NC}"
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
    echo "  Abstract não disponível."
  fi

  echo -e "\nPressione Enter para voltar..."
  read -r
}

export_csv() {
  local filename="pubmed_results_$(date +%Y%m%d_%H%M%S).csv"

  {
    echo "Title,Journal,Authors,Date,PMID,URL"
    for i in "${!IDS[@]}"; do
      local title="${TITLES[$i]}"
      local source="${SOURCES[$i]}"
      local pmid="${IDS[$i]}"
      local authors="${AUTHORS[$i]}"
      local date="${DATES[$i]}"
      title=$(echo "$title" | sed 's/"/""/g')
      source=$(echo "$source" | sed 's/"/""/g')
      authors=$(echo "$authors" | sed 's/"/""/g')
      echo "\"$title\",\"$source\",\"$authors\",\"$date\",\"$pmid\",\"https://pubmed.ncbi.nlm.nih.gov/$pmid/\""
    done
  } > "$filename"
  echo -e "${GREEN}Arquivo exportado: $filename${NC}"
}

# ============================================
# Inicialização
# ============================================
command -v curl >/dev/null 2>&1 || { echo -e "${RED}Erro: curl não encontrado.${NC}"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo -e "${RED}Erro: jq não encontrado.${NC}"; exit 1; }

if [ "$#" -eq 0 ]; then
  echo "Uso: ./analyze.sh \"termo 1\" [\"termo 2\" ...]"
  exit 1
fi

setup_api_key

# Loop principal sobre cada query
for QUERY in "$@"; do
  echo -e "${CYAN}Termo de busca:${NC} $QUERY"
  echo -e "Digite o número máximo de resultados, ou 'all' para buscar tudo (pode ser demorado)."
  read -p "Número máximo (padrão $DEFAULT_MAX_RESULTS, 'all' para todos): " MAX_RESULTS_INPUT

  FETCH_ALL=false
  if [ -z "$MAX_RESULTS_INPUT" ]; then
    MAX_RESULTS=$DEFAULT_MAX_RESULTS
  elif [ "$(echo "$MAX_RESULTS_INPUT" | tr '[:upper:]' '[:lower:]')" = "all" ] || [ "$MAX_RESULTS_INPUT" = "0" ]; then
    FETCH_ALL=true
    MAX_RESULTS="all"
    echo -e "${YELLOW}Aviso: buscar todos os resultados pode levar vários minutos e consumir muitos recursos.${NC}"
    read -p "Confirma? (s/N): " CONFIRM
    if [ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" != "s" ]; then
      echo -e "${YELLOW}Usando padrão $DEFAULT_MAX_RESULTS.${NC}"
      MAX_RESULTS=$DEFAULT_MAX_RESULTS
      FETCH_ALL=false
    fi
  elif [[ "$MAX_RESULTS_INPUT" =~ ^[0-9]+$ ]] && [ "$MAX_RESULTS_INPUT" -gt 0 ]; then
    MAX_RESULTS=$MAX_RESULTS_INPUT
  else
    echo -e "${RED}Valor inválido. Usando padrão $DEFAULT_MAX_RESULTS.${NC}"
    MAX_RESULTS=$DEFAULT_MAX_RESULTS
  fi

  echo -e "${CYAN}Buscando resultados...${NC}"

  PMIDS=$(search_pubmed "$QUERY" "$MAX_RESULTS") || {
    echo -e "${RED}Falha na busca ou nenhum resultado encontrado.${NC}"
    continue
  }

  if [ -z "$PMIDS" ] || [ "$PMIDS" == "null" ]; then
    echo -e "${RED}Nenhum resultado encontrado para \"$QUERY\".${NC}"
    continue
  fi

  echo -e "${CYAN}Obtendo detalhes dos artigos...${NC}"
  fetch_and_populate_arrays "$PMIDS" || {
    echo -e "${RED}Falha ao obter detalhes dos artigos.${NC}"
    continue
  }

  TOTAL=${#IDS[@]}
  PAGE=1
  TOTAL_PAGES=$(( (TOTAL + RESULTS_PER_PAGE - 1) / RESULTS_PER_PAGE ))

  # Loop de navegação
  while true; do
    display_articles_page "$PAGE" "$TOTAL" "$RESULTS_PER_PAGE"

    read -p "Escolha: " CHOICE
    case "$CHOICE" in
      n|N)
        if [ $PAGE -lt $TOTAL_PAGES ]; then
          PAGE=$((PAGE+1))
        else
          echo -e "${YELLOW}Você já está na última página.${NC}"
          sleep 1
        fi
        ;;
      p|P)
        if [ $PAGE -gt 1 ]; then
          PAGE=$((PAGE-1))
        else
          echo -e "${YELLOW}Você já está na primeira página.${NC}"
          sleep 1
        fi
        ;;
      a|A)
        START_NUM=$(( (PAGE-1)*RESULTS_PER_PAGE + 1 ))
        END_NUM=$(( (PAGE-1)*RESULTS_PER_PAGE + (TOTAL - (PAGE-1)*RESULTS_PER_PAGE < RESULTS_PER_PAGE ? TOTAL - (PAGE-1)*RESULTS_PER_PAGE : RESULTS_PER_PAGE) ))
        read -p "Digite o número do artigo ($START_NUM-$END_NUM): " ART_NUM
        if [[ "$ART_NUM" =~ ^[0-9]+$ ]] && [ "$ART_NUM" -ge $START_NUM ] && [ "$ART_NUM" -le $END_NUM ]; then
          INDEX=$(( ART_NUM - 1 ))
          URL="https://pubmed.ncbi.nlm.nih.gov/${IDS[$INDEX]}/"
          echo "Abrindo: $URL"
          open_url "$URL"
        else
          echo -e "${RED}Número inválido.${NC}"
        fi
        ;;
      o|O)
        ENCODED_QUERY=$(url_encode "$QUERY")
        SEARCH_URL="https://pubmed.ncbi.nlm.nih.gov/?term=${ENCODED_QUERY}&sort=relevance"
        echo "Abrindo busca no PubMed: $SEARCH_URL"
        open_url "$SEARCH_URL"
        ;;
      s|S)
        clear
        print_header
        echo -e "${CYAN}Estatísticas para: $QUERY${NC}\n"
        TOP_JOURNALS=$(printf '%s\n' "${SOURCES[@]}" | sort | uniq -c | sort -nr | head -n 5)
        TOP_AUTHORS=$(printf '%s\n' "${AUTHORS[@]}" | tr ',' '\n' | sed 's/^ //; s/ $//' | sort | uniq -c | sort -nr | head -n 5)
        YEARS=$(printf '%s\n' "${DATES[@]}" | grep -oE '^[0-9]{4}' | sort -n | uniq -c)
        TOTAL_YEARS=$(echo "$YEARS" | wc -l | tr -d ' ')
        YEARS_TOP=$(echo "$YEARS" | sort -nr | head -n 5)
        print_stats "$TOP_JOURNALS" "$TOP_AUTHORS" "$YEARS_TOP" "$TOTAL_YEARS"
        echo -e "\nPressione Enter para voltar..."
        read -r
        ;;
      c|C)
        export_csv
        echo -e "\nPressione Enter para continuar..."
        read -r
        ;;
      q|Q)
        echo -e "${GREEN}Saindo...${NC}"
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
          echo -e "${RED}Opção inválida.${NC}"
          sleep 1
        fi
        ;;
    esac
  done
done
