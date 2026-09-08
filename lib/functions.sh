#!/usr/bin/env bash
# ============================================================
# functions.sh — Funções de processamento (busca, parsing,
# exportação e logging).
#
# Requer config.sh carregado antes (define BASE_URL, cores e globais).
# ============================================================

# Codifica uma string para uso em URL (RFC 3986 via jq).
# Usa printf (e não here-string) para não codificar a quebra de linha final.
url_encode() {
  printf '%s' "$1" | jq -s -R -r @uri
}

# Verifica se a string é JSON válido. Retorna 0 (sucesso) ou 1 (falha).
# Entrada vazia é tratada como inválida (jq aceita entrada vazia como "sem valores").
is_json() {
  [ -n "$1" ] && printf '%s' "$1" | jq empty >/dev/null 2>&1
}

# GET HTTP capturando corpo, código HTTP e status do transporte.
# Uso: fetch_url "URL"
# Resultado em globais: FETCH_BODY, FETCH_HTTP_CODE, FETCH_CURL_RC.
# Retorna 0 em sucesso de transporte; 1 em erro de rede (curl).
fetch_url() {
  local url="$1"
  local output=""
  local rc=0

  FETCH_BODY=""
  FETCH_HTTP_CODE=""
  FETCH_CURL_RC=0

  output=$(curl -sS --connect-timeout 15 --max-time 60 \
    -w $'\n__HTTP_CODE__%{http_code}' "$url" 2>/dev/null) || rc=$?

  FETCH_CURL_RC=$rc
  if [ $rc -ne 0 ]; then
    return 1
  fi

  FETCH_HTTP_CODE=$(printf '%s\n' "$output" | tail -n 1 | sed 's/^__HTTP_CODE__//')
  FETCH_BODY=$(printf '%s\n' "$output" | sed '$d')
  return 0
}

# Extrai a mensagem do campo .error (se houver) de um JSON da API.
api_error_message() {
  printf '%s' "$1" | jq -r '.error // empty' 2>/dev/null || true
}

# Substitui o valor de api_key por REDACTED em uma URL (para não gravar a chave).
redact_api_key() {
  printf '%s' "$1" | sed -E 's/api_key=[^&]+/api_key=REDACTED/'
}

# Calcula o SHA-256 dos arquivos-fonte do script (rastreabilidade).
compute_script_hash() {
  local hash_cmd=""
  if command -v shasum >/dev/null 2>&1; then
    hash_cmd="shasum -a 256"
  elif command -v sha256sum >/dev/null 2>&1; then
    hash_cmd="sha256sum"
  else
    printf 'indisponível'
    return 0
  fi

  local files=()
  local f
  for f in "$SCRIPT_DIR/analyze.sh" "$LIB_DIR/config.sh" "$LIB_DIR/functions.sh" "$LIB_DIR/ui.sh"; do
    [ -f "$f" ] && files+=("$f")
  done

  if [ ${#files[@]} -eq 0 ]; then
    printf 'indisponível'
    return 0
  fi

  cat "${files[@]}" | $hash_cmd | awk '{print $1}'
}

# Verifica se o termo parece malformado (aspas duplas desbalanceadas ou
# operador booleano AND/OR/NOT no início). Retorna 0 se suspeito, 1 caso não.
is_suspicious_term() {
  local term="$1"
  local trimmed
  trimmed=$(printf '%s' "$term" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  # aspas duplas desbalanceadas
  local qcount
  qcount=$(printf '%s' "$trimmed" | tr -cd '"' | wc -c | tr -d ' ')
  if [ $((qcount % 2)) -ne 0 ]; then
    return 0
  fi

  # operador booleano no início (ignorando uma eventual aspa inicial)
  local head
  head=$(printf '%s' "$trimmed" | sed 's/^"//' | tr '[:upper:]' '[:lower:]')
  case "$head" in
    and|or|not|and\ *|or\ *|not\ *) return 0 ;;
  esac

  return 1
}

# Rótulo amigável para o total do PubMed. Se count estiver ausente ou for 0
# mas houver resultados carregados, mostra "≥ <carregado>" em vez de "0".
pubmed_count_label() {
  local loaded="$1"
  local n
  n=$(printf '%s' "$TOTAL_PUBMED" | tr -d '[:space:]')
  if [ -z "$n" ] || [ "$n" = "0" ]; then
    if [ "${loaded:-0}" -gt 0 ] 2>/dev/null; then
      printf '≥ %s' "$loaded"
    else
      printf '0'
    fi
    return
  fi
  printf '%s' "$n"
}

# ============================================================
# Utilidades do modo CLI (parse/validação)
# ============================================================

# Retorna 0 se o tipo de publicação é reconhecido (ou "any"/vazio).
is_valid_publication_type() {
  case "$1" in
    any|review|clinical_trial|meta_analysis|randomized_controlled_trial|systematic_review|case_reports|comparative_study|observational_study|multicenter_study|guideline)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Monta a query final aplicando o filtro de tipo de publicação.
# Se type for vazio ou "any", retorna a query original; caso contrário,
# retorna "(query) AND type[pt]".
build_final_query() {
  local query="$1"
  local type="$2"
  if [ -z "$type" ] || [ "$type" = "any" ]; then
    printf '%s' "$query"
  else
    printf '(%s) AND %s[pt]' "$query" "$type"
  fi
}

# Extrai MINDATE:MAXDATE de uma string de anos (AAAA ou AAAA-AAAA).
# Retorna 1 se o formato for inválido.
parse_years() {
  local range="$1"
  if [ -z "$range" ]; then
    printf ':'
    return 0
  fi
  if [[ "$range" =~ ^([0-9]{4})-([0-9]{4})$ ]]; then
    printf '%s:%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  elif [[ "$range" =~ ^[0-9]{4}$ ]]; then
    printf '%s:%s' "$range" "$range"
    return 0
  fi
  return 1
}

# Retorna 0 se a ordenação é válida.
is_valid_sort() {
  case "$1" in
    relevance|pub_date|first_author|journal) return 0 ;;
    *) return 1 ;;
  esac
}

# Normaliza --max (vazio -> 200, 'all' ou inteiro positivo).
# Imprime o valor normalizado; retorna 1 se inválido.
validate_max() {
  local v="$1"
  if [ -z "$v" ]; then
    printf '200'
    return 0
  fi
  local lower
  lower=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
  if [ "$lower" = "all" ]; then
    printf 'all'
    return 0
  fi
  if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -gt 0 ]; then
    printf '%s' "$v"
    return 0
  fi
  return 1
}

# Calcula o retmax adequado para uma busca. A API do NCBI limita retmax a
# 10.000, então valores maiores paginam em blocos de 10.000.
compute_retmax() {
  local max_results="$1"
  if [ "$max_results" = "all" ]; then
    printf '10000'
    return 0
  fi
  if [[ "$max_results" =~ ^[0-9]+$ ]] && [ "$max_results" -gt 0 ]; then
    if [ "$max_results" -lt 10000 ]; then
      printf '%s' "$max_results"
    else
      printf '10000'
    fi
    return 0
  fi
  printf '200'
}

# Busca PMIDs no PubMed via esearch (com paginação).
# Parâmetros: query, max_results, sort_order, mindate, maxdate.
# Define os globais PMIDS, ESEARCH_URL, SEARCH_UTC_TS e TOTAL_PUBMED.
#
# Códigos de saída:
#   0  sucesso
#   2  erro de rede (curl)
#   3  erro HTTP (4xx/5xx, incluindo 429)
#   4  erro reportado pela API no corpo (.error)
#   5  resposta inválida (não-JSON)
#   6  nenhum resultado encontrado
search_pubmed() {
  local query="$1"
  local max_results="$2"
  local sort_order="$3"
  local mindate="$4"
  local maxdate="$5"
  local encoded_query
  encoded_query=$(url_encode "$query")

  SEARCH_UTC_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  ESEARCH_URL=""
  TOTAL_PUBMED=""
  PMIDS=""

  local retstart=0
  local retmax
  retmax=$(compute_retmax "$max_results")
  local all_ids=""
  local total_fetched=0
  local fetch_all=false

  [ "$max_results" = "all" ] && fetch_all=true

  while true; do
    local search_url="${BASE_URL}/esearch.fcgi?db=pubmed&term=${encoded_query}&retstart=${retstart}&retmax=${retmax}&retmode=json&sort=${sort_order}"
    [ -n "$API_KEY" ] && search_url="${search_url}&api_key=${API_KEY}"
    [ -n "$mindate" ] && search_url="${search_url}&mindate=${mindate}"
    [ -n "$maxdate" ] && search_url="${search_url}&maxdate=${maxdate}"

    # Guarda a URL exata da primeira requisição para reprodutibilidade
    [ -z "$ESEARCH_URL" ] && ESEARCH_URL="$search_url"

    local response=""
    if ! fetch_url "$search_url"; then
      printf "\n${RED}${MSG_ERR_NETWORK}${NC}\n" >&2
      echo -e "${YELLOW}${MSG_CHECK_INTERNET}${NC}" >&2
      return 2
    fi
    response="$FETCH_BODY"

    if [ "$FETCH_HTTP_CODE" = "429" ]; then
      printf "\n${RED}${MSG_ERR_RATE_LIMIT_429}${NC}\n" >&2
      echo -e "${YELLOW}${MSG_WAIT_OR_API_KEY}${NC}" >&2
      return 3
    fi

    case "${FETCH_HTTP_CODE:0:1}" in
      5)
        printf "\n${RED}${MSG_ERR_SERVER}${NC}\n" "$FETCH_HTTP_CODE" >&2
        return 3
        ;;
      4)
        printf "\n${RED}${MSG_ERR_REQUEST}${NC}\n" "$FETCH_HTTP_CODE" >&2
        return 3
        ;;
    esac

    if ! is_json "$response"; then
      printf "\n${RED}${MSG_ERR_INVALID_JSON}${NC}\n" "$FETCH_HTTP_CODE" >&2
      echo -e "${YELLOW}${MSG_RESPONSE_RECEIVED}${NC}" >&2
      printf '%.200s\n' "$response" >&2
      return 5
    fi

    local api_err
    api_err=$(api_error_message "$response")
    if [ -n "$api_err" ]; then
      printf "\n${RED}${MSG_ERR_API}${NC}\n" "$api_err" >&2
      case "$api_err" in
        *"rate limit"*)
          echo -e "${YELLOW}${MSG_RATE_LIMIT_HINT}${NC}" >&2
          ;;
      esac
      return 4
    fi

    # Total geral de resultados no PubMed (campo count, idêntico em todas as páginas)
    [ -z "$TOTAL_PUBMED" ] && TOTAL_PUBMED=$(printf '%s' "$response" | jq -r '.esearchresult.count // 0')

    local batch_ids=""
    local count=0
    batch_ids=$(printf '%s' "$response" | jq -r '.esearchresult.idlist | join(",")')
    count=$(printf '%s' "$response" | jq -r '.esearchresult.idlist | length')

    if [ -n "$batch_ids" ] && [ "$batch_ids" != "null" ]; then
      if [ -z "$all_ids" ]; then
        all_ids="$batch_ids"
      else
        all_ids="${all_ids},${batch_ids}"
      fi
      total_fetched=$((total_fetched + count))
      printf "\r${CYAN}${MSG_SEARCHING}${NC}" "$total_fetched" >&2
    fi

    if [ "$fetch_all" = false ]; then
      if [ $total_fetched -ge "$max_results" ]; then
        all_ids=$(printf '%s' "$all_ids" | cut -d',' -f1-"$max_results")
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

    if [ $total_fetched -ge 100000 ]; then
      printf "\n${YELLOW}${MSG_SAFETY_LIMIT}${NC}\n" >&2
      break
    fi
  done

  all_ids=$(printf '%s' "$all_ids" | tr -d '[:space:]')
  if [ -z "$all_ids" ]; then
    printf "\n${YELLOW}${MSG_NO_IDS_FOUND}${NC}\n" >&2
    PMIDS=""
    return 6
  fi

  printf '\n' >&2
  PMIDS="$all_ids"
  return 0
}

# Extrai campos de um chunk de resposta esummary como TSV.
# Cada linha: title<TAB>source<TAB>id<TAB>authors<TAB>pubdate<TAB>volume<TAB>issue<TAB>pages<TAB>doi
extract_summary_fields() {
  local json="$1"
  printf '%s' "$json" | jq -r '
    .result
    | to_entries[]
    | select(.key != "uids")
    | [.value.title, .value.source, .key,
       (.value.authors | map(.name) | join(", ")),
       .value.pubdate,
       .value.volume,
       .value.issue,
       (if ((.value.pages // "") | contains("/")) then "" else (.value.pages // "") end),
       ((.value.articleids // []) | map(select(.idtype == "doi") | .value) | .[0] // "")]
    | @tsv'
}

# Busca os sumários em blocos de 200 IDs e preenche os arrays globais.
# Também acumula as respostas JSON brutas em SUMMARY_JSONS (para exportação).
#
# Códigos de saída:
#   0  sucesso
#   2  erro de rede
#   3  erro HTTP (4xx/5xx, incluindo 429)
#   4  erro reportado pela API (.error)
#   5  resposta inválida (não-JSON)
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

  TITLES=(); SOURCES=(); IDS=(); AUTHORS=(); DATES=(); VOLUMES=(); ISSUES=(); PAGES=(); DOIS=(); SUMMARY_JSONS=()

  while [ $start -lt $total ]; do
    chunk_number=$((chunk_number + 1))
    end=$((start + chunk_size - 1))
    [ $end -ge $total ] && end=$((total - 1))

    printf "\r${CYAN}${MSG_FETCHING_DETAILS}${NC}" "$chunk_number" "$total_chunks" "$start" "$end" >&2

    local chunk_ids=""
    local i
    for ((i=start; i<=end; i++)); do
      if [ -z "$chunk_ids" ]; then
        chunk_ids="${id_array[$i]}"
      else
        chunk_ids="${chunk_ids},${id_array[$i]}"
      fi
    done

    local summary_url="${BASE_URL}/esummary.fcgi?db=pubmed&id=${chunk_ids}&retmode=json"
    [ -n "$API_KEY" ] && summary_url="${summary_url}&api_key=${API_KEY}"

    local response=""
    if ! fetch_url "$summary_url"; then
      printf "\n${RED}${MSG_ERR_NETWORK_SUMMARIES}${NC}\n" "$start" "$end" >&2
      return 2
    fi
    response="$FETCH_BODY"

    if [ "$FETCH_HTTP_CODE" = "429" ] || [ "${FETCH_HTTP_CODE:0:1}" = "5" ] || [ "${FETCH_HTTP_CODE:0:1}" = "4" ]; then
      printf "\n${RED}${MSG_ERR_SUMMARIES_HTTP}${NC}\n" "$FETCH_HTTP_CODE" >&2
      return 3
    fi

    if ! is_json "$response"; then
      printf "\n${RED}${MSG_ERR_SUMMARIES_NOT_JSON}${NC}\n" "$start" "$end" >&2
      return 5
    fi

    local api_err
    api_err=$(api_error_message "$response")
    if [ -n "$api_err" ]; then
      printf "\n${RED}${MSG_ERR_SUMMARIES_API}${NC}\n" "$api_err" >&2
      return 4
    fi

    SUMMARY_JSONS+=("$response")

    while IFS=$'\t' read -r title source id authors pubdate volume issue pages doi; do
      TITLES+=("$title")
      SOURCES+=("$source")
      IDS+=("$id")
      AUTHORS+=("$authors")
      DATES+=("$pubdate")
      VOLUMES+=("$volume")
      ISSUES+=("$issue")
      PAGES+=("$pages")
      DOIS+=("$doi")
    done < <(extract_summary_fields "$response")

    start=$((end + 1))
  done

  echo "" >&2
  return 0
}

get_abstract() {
  local pmid="$1"
  local url="${BASE_URL}/efetch.fcgi?db=pubmed&id=${pmid}&rettype=abstract&retmode=text"
  [ -n "$API_KEY" ] && url="${url}&api_key=${API_KEY}"
  curl -s "$url"
}

# ============================================================
# Exportação
# ============================================================

export_csv() {
  local filename="${1:-}"
  if [ -z "$filename" ]; then
    filename="pubmed_results_$(date -u +%Y%m%d_%H%M%S).csv"
  fi

  if [ "$filename" = "-" ]; then
    _csv_rows
  else
    _csv_rows > "$filename"
    printf "${GREEN}${MSG_EXPORT_CSV}${NC}\n" "$filename" >&2
  fi
}

# Imprime as linhas CSV em stdout.
_csv_rows() {
  echo "Title,Journal,Authors,Date,PMID,URL"
  local i
  for i in "${!IDS[@]}"; do
    local title="${TITLES[$i]}"
    local source="${SOURCES[$i]}"
    local pmid="${IDS[$i]}"
    local authors="${AUTHORS[$i]}"
    local date="${DATES[$i]}"
    title=$(printf '%s' "$title" | sed 's/"/""/g')
    source=$(printf '%s' "$source" | sed 's/"/""/g')
    authors=$(printf '%s' "$authors" | sed 's/"/""/g')
    echo "\"$title\",\"$source\",\"$authors\",\"$date\",\"$pmid\",\"https://pubmed.ncbi.nlm.nih.gov/$pmid/\""
  done
}

export_pmids() {
  local filename="${1:-}"
  if [ -z "$filename" ]; then
    filename="pubmed_pmids_$(date -u +%Y%m%d_%H%M%S).txt"
  fi

  if [ "$filename" = "-" ]; then
    printf '%s\n' "$PMIDS" | tr ',' '\n'
  else
    printf '%s\n' "$PMIDS" | tr ',' '\n' > "$filename"
    printf "${GREEN}${MSG_EXPORT_PMIDS}${NC}\n" "$filename" >&2
  fi
}

export_json() {
  local filename="${1:-}"
  if [ -z "$filename" ]; then
    filename="pubmed_raw_$(date -u +%Y%m%d_%H%M%S).json"
  fi

  local pmids_json
  pmids_json=$(printf '%s' "$PMIDS" | jq -R -s -c 'split(",")')
  local script_hash
  script_hash=$(compute_script_hash)

  if [ "$filename" = "-" ]; then
    _emit_json "$pmids_json" "$script_hash"
  else
    _emit_json "$pmids_json" "$script_hash" > "$filename"
    printf "${GREEN}${MSG_EXPORT_JSON}${NC}\n" "$filename" >&2
  fi
}

# Imprime o JSON bruto (metadados + chunks do esummary) em stdout.
_emit_json() {
  local pmids_json="$1"
  local script_hash="$2"
  local esearch_url_clean
  esearch_url_clean=$(redact_api_key "$ESEARCH_URL")
  jq -n \
    --arg query "$QUERY" \
    --arg searched_at_utc "$SEARCH_UTC_TS" \
    --arg version "$VERSION" \
    --arg script_sha256 "$script_hash" \
    --arg esearch_url "$esearch_url_clean" \
    --argjson pmids "$pmids_json" \
    --slurpfile chunks <(printf '%s\n' "${SUMMARY_JSONS[@]}") \
    '{query: $query, searched_at_utc: $searched_at_utc, version: $version, script_sha256: $script_sha256, esearch_url: $esearch_url, pmids: $pmids, esummary_chunks: $chunks}'
}

# ============================================================
# BibTeX
# ============================================================

# Escapa caracteres especiais para uso em campos BibTeX.
bibtex_escape() {
  printf '%s' "$1" | sed 's/[\\&%$#_{}]/\\&/g'
}

# Extrai o sobrenome do primeiro autor (para a chave da entrada).
bibtex_first_author_surname() {
  local first
  first=$(printf '%s' "$1" | cut -d',' -f1 | awk '{print $1}')
  printf '%s' "$first" | tr -cd '[:alnum:]'
}

# Extrai o ano (4 dígitos) de uma data de publicação.
bibtex_year() {
  printf '%s' "$1" | grep -oE '[0-9]{4}' | head -n 1
}

# Monta a chave única da entrada: sobrenome + ano + pmid.
bibtex_key() {
  local pmid="$1" authors="$2" date="$3"
  local surname year
  surname=$(bibtex_first_author_surname "$authors")
  year=$(bibtex_year "$date")
  if [ -n "$surname" ]; then
    printf '%s%s_%s' "$surname" "$year" "$pmid"
  else
    printf 'pmid%s' "$pmid"
  fi
}

# Converte a lista de autores (separada por vírgula) para o formato BibTeX
# "Sobrenome, Iniciais and Sobrenome, Iniciais".
bibtex_authors() {
  local authors="$1"
  local out=""
  local name name_bib last rest
  local oldIFS="$IFS"
  IFS=','
  for name in $authors; do
    name=$(printf '%s' "$name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$name" ] && continue
    last="${name%% *}"
    rest="${name#* }"
    if [ "$rest" = "$name" ]; then
      name_bib="$name"
    else
      name_bib="${last}, ${rest}"
    fi
    if [ -z "$out" ]; then
      out="$name_bib"
    else
      out="${out} and ${name_bib}"
    fi
  done
  IFS="$oldIFS"
  printf '%s' "$out"
}

# Gera uma entrada BibTeX @article a partir dos campos fornecidos.
format_bibtex_entry() {
  local title="$1" authors="$2" source="$3" date="$4" pmid="$5" volume="$6" issue="$7" pages="$8" doi="$9"

  local key
  key=$(bibtex_key "$pmid" "$authors" "$date")

  local title_e authors_e source_e
  title_e=$(bibtex_escape "$title")
  authors_e=$(bibtex_escape "$(bibtex_authors "$authors")")
  source_e=$(bibtex_escape "$source")

  local year
  year=$(bibtex_year "$date")

  printf '@article{%s,\n' "$key"
  printf '  author = {%s},\n' "$authors_e"
  printf '  title = {%s},\n' "$title_e"
  printf '  journal = {%s},\n' "$source_e"
  printf '  year = {%s},\n' "$year"
  [ -n "$volume" ] && printf '  volume = {%s},\n' "$(bibtex_escape "$volume")"
  [ -n "$issue" ] && printf '  number = {%s},\n' "$(bibtex_escape "$issue")"
  if [ -n "$pages" ] && ! printf '%s' "$pages" | grep -q '/'; then
    printf '  pages = {%s},\n' "$(bibtex_escape "$pages")"
  fi
  [ -n "$doi" ] && printf '  doi = {%s},\n' "$(bibtex_escape "$doi")"
  printf '  pmid = {%s},\n' "$pmid"
  printf '  url = {https://pubmed.ncbi.nlm.nih.gov/%s/}\n' "$pmid"
  printf '}\n'
}

export_bib() {
  local filename="${1:-}"
  if [ -z "$filename" ]; then
    filename="pubmed_results_$(date -u +%Y%m%d_%H%M%S).bib"
  fi

  if [ "$filename" = "-" ]; then
    _bib_rows
  else
    _bib_rows > "$filename"
    printf "${GREEN}${MSG_EXPORT_BIB}${NC}\n" "$filename" >&2
  fi
}

# Imprime todas as entradas BibTeX em stdout.
_bib_rows() {
  local i
  for i in "${!IDS[@]}"; do
    format_bibtex_entry "${TITLES[$i]}" "${AUTHORS[$i]}" "${SOURCES[$i]}" "${DATES[$i]}" "${IDS[$i]}" "${VOLUMES[$i]}" "${ISSUES[$i]}" "${PAGES[$i]}" "${DOIS[$i]}"
    echo ""
  done
}

# ============================================================
# Logging
# ============================================================

# Salva um registro imutável (somente-leitura) da busca, com timestamp UTC,
# versão/hash do script e a URL exata enviada ao esearch.
save_search_config() {
  local query="$1"
  local max_results="$2"
  local sort_order="$3"
  local mindate="$4"
  local maxdate="$5"
  local total_results="$6"
  local timestamp_utc
  timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local log_file="$LOG_DIR/search_$(date -u +%Y%m%d_%H%M%S)_$$.txt"
  local script_hash
  script_hash=$(compute_script_hash)
  local esearch_url_clean
  esearch_url_clean=$(redact_api_key "$ESEARCH_URL")

  mkdir -p "$LOG_DIR"

  {
    printf '%s\n' "$MSG_LOG_TITLE"
    printf "$MSG_LOG_TIMESTAMP\n" "$timestamp_utc"
    printf "$MSG_LOG_VERSION\n" "$VERSION"
    printf "$MSG_LOG_SHA\n" "$script_hash"
    echo ""
    printf '%s\n' "$MSG_LOG_CONFIG_TITLE"
    printf "$MSG_LOG_TERM\n" "$query"
    printf "$MSG_LOG_MAX\n" "$max_results"
    printf "$MSG_LOG_SORT\n" "$sort_order"
    if [ -n "$mindate" ] || [ -n "$maxdate" ]; then
      printf "$MSG_LOG_YEARS_RANGE\n" "${mindate:-*}" "${maxdate:-*}"
    else
      printf '%s\n' "$MSG_LOG_YEARS_NONE"
    fi
    if [ -n "$API_KEY" ]; then
      printf "$MSG_LOG_API_KEY_USED\n" "$MSG_YES"
    else
      printf "$MSG_LOG_API_KEY_USED\n" "$MSG_NO"
    fi
    echo ""
    printf '%s\n' "$MSG_LOG_URL_TITLE"
    printf '%s\n' "$esearch_url_clean"
    echo ""
    printf '%s\n' "$MSG_LOG_RESULT_TITLE"
    printf "$MSG_LOG_TOTAL_PUBMED\n" "${TOTAL_PUBMED:-0}"
    if [ "${TOTAL_PUBMED:-0}" = "0" ] && [ "$total_results" -gt 0 ] 2>/dev/null; then
      printf "$MSG_LOG_COUNT_ZERO_WARN\n" "$total_results"
    fi
    printf "$MSG_LOG_TOTAL_LOADED\n" "$total_results"
  } > "$log_file"

  chmod 444 "$log_file"
  printf "${GREEN}${MSG_LOG_SAVED}${NC}\n" "$log_file" >&2
}
