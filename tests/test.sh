#!/usr/bin/env bash
# ============================================================
# Testes mínimos das funções de processamento.
# Uso: bash tests/test.sh
# ============================================================
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "ERRO: jq é necessário para os testes." >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/config.sh"
source "$LIB_DIR/functions.sh"
source "$LIB_DIR/i18n_pt.sh"

pass=0
fail=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass=$((pass+1)); echo "ok   - $desc"
  else
    fail=$((fail+1))
    echo "FAIL - $desc"
    echo "       esperado: [$expected]"
    echo "       obtido:   [$actual]"
  fi
}

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass+1)); echo "ok   - $desc"
  else
    fail=$((fail+1)); echo "FAIL - $desc (deveria ter sucesso)"
  fi
}

assert_fail() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    fail=$((fail+1)); echo "FAIL - $desc (deveria falhar)"
  else
    pass=$((pass+1)); echo "ok   - $desc"
  fi
}

# --- url_encode -------------------------------------------------
assert_eq "url_encode: espaço"        "hello%20world"   "$(url_encode 'hello world')"
assert_eq "url_encode: acento"        "c%C3%A2ncer"     "$(url_encode 'câncer')"
assert_eq "url_encode: & e +"         "a%26b%2Bc"       "$(url_encode 'a&b+c')"
assert_eq "url_encode: barra"         "a%2Fb"           "$(url_encode 'a/b')"

# --- is_json ----------------------------------------------------
assert_ok   "is_json: objeto válido"  is_json '{"a":1}'
assert_ok   "is_json: array válido"   is_json '[1,2,3]'
assert_fail "is_json: texto inválido" is_json 'não é json'
assert_fail "is_json: vazio"          is_json ''

# --- extração de dados (esummary) ------------------------------
sample='{"result":{"uids":["1","2"],"1":{"title":"Título Um","source":"Revista A","authors":[{"name":"Silva J"},{"name":"Souza M"}],"pubdate":"2020 Jan","volume":"8","issue":"2","pages":"10-20","articleids":[{"idtype":"pubmed","value":"1"},{"idtype":"doi","value":"10.1000/xyz"}]},"2":{"title":"Título Dois","source":"Revista B","authors":[],"pubdate":"2021","volume":"9","issue":"1","pages":"30-40"}}}'

expected=$'Título Um\tRevista A\t1\tSilva J, Souza M\t2020 Jan\t8\t2\t10-20\t10.1000/xyz\nTítulo Dois\tRevista B\t2\t\t2021\t9\t1\t30-40\t'
assert_eq "extract_summary_fields: duas entradas" "$expected" "$(extract_summary_fields "$sample")"

# Sem a chave "uids" — verifica que ela é descartada
assert_eq "extract_summary_fields: descarta uids" "0" "$(extract_summary_fields "$sample" | grep -c '^uids' || true)"

# --- is_suspicious_term -----------------------------------------
assert_ok   "termo suspeito: aspas desbalanceadas" is_suspicious_term '"Autism'
assert_ok   "termo suspeito: começa com AND"       is_suspicious_term 'AND autism'
assert_ok   "termo suspeito: aspa + AND"           is_suspicious_term '"AND "Autism""'
assert_fail "termo válido: frase com aspas"        is_suspicious_term '"autism spectrum" AND intervention'
assert_fail "termo válido: simples"                is_suspicious_term 'autism'

# --- pubmed_count_label -----------------------------------------
TOTAL_PUBMED="12345"
assert_eq "count normal" "12345" "$(pubmed_count_label 200)"
TOTAL_PUBMED="0"
assert_eq "count 0 com carregados" "≥ 200" "$(pubmed_count_label 200)"
TOTAL_PUBMED=""
assert_eq "count vazio com carregados" "≥ 200" "$(pubmed_count_label 200)"
assert_eq "count vazio sem carregados" "0" "$(pubmed_count_label 0)"
TOTAL_PUBMED="12345"

# --- utilidades do modo CLI -------------------------------------
assert_eq "build_final_query: sem tipo"     "cancer"              "$(build_final_query 'cancer' '')"
assert_eq "build_final_query: tipo any"      "cancer"              "$(build_final_query 'cancer' 'any')"
assert_eq "build_final_query: tipo review"   "(cancer) AND review[pt]" "$(build_final_query 'cancer' 'review')"

assert_eq "parse_years: ano único"          "2020:2020"   "$(parse_years '2020')"
assert_eq "parse_years: intervalo"          "2015:2023"   "$(parse_years '2015-2023')"
assert_eq "parse_years: vazio"              ":"           "$(parse_years '')"
assert_fail "parse_years: inválido"          parse_years '2020-2021-2022'

assert_ok   "is_valid_sort: relevance"       is_valid_sort 'relevance'
assert_ok   "is_valid_sort: pub_date"        is_valid_sort 'pub_date'
assert_fail "is_valid_sort: inválido"        is_valid_sort 'foo'

assert_ok   "is_valid_publication_type: review" is_valid_publication_type 'review'
assert_ok   "is_valid_publication_type: any"    is_valid_publication_type 'any'
assert_fail "is_valid_publication_type: inválido" is_valid_publication_type 'foo'

assert_eq "validate_max: vazio"     "200" "$(validate_max '')"
assert_eq "validate_max: número"    "50"  "$(validate_max '50')"
assert_eq "validate_max: all"       "all" "$(validate_max 'all')"
assert_eq "validate_max: ALL"       "all" "$(validate_max 'ALL')"
assert_fail "validate_max: inválido" validate_max 'abc'
assert_fail "validate_max: zero"     validate_max '0'

# --- redact_api_key ---------------------------------------------
assert_eq "redact: chave no meio"  "https://e/x?term=a&api_key=REDACTED&sort=pub_date" "$(redact_api_key 'https://e/x?term=a&api_key=segredo123&sort=pub_date')"
assert_eq "redact: chave no fim"   "https://e/x?term=a&api_key=REDACTED" "$(redact_api_key 'https://e/x?term=a&api_key=segredo123')"
assert_eq "redact: sem chave"      "https://e/x?term=a" "$(redact_api_key 'https://e/x?term=a')"

# --- compute_retmax ---------------------------------------------
assert_eq "retmax: all"            "10000" "$(compute_retmax 'all')"
assert_eq "retmax: 1"              "1"     "$(compute_retmax '1')"
assert_eq "retmax: 200"            "200"   "$(compute_retmax '200')"
assert_eq "retmax: 9999"           "9999"  "$(compute_retmax '9999')"
assert_eq "retmax: 10000"          "10000" "$(compute_retmax '10000')"
assert_eq "retmax: acima do limite" "10000" "$(compute_retmax '50000')"
assert_eq "retmax: zero (fallback)" "200"  "$(compute_retmax '0')"
assert_eq "retmax: inválido (fallback)" "200" "$(compute_retmax 'abc')"

# --- i18n ------------------------------------------------------
source "$LIB_DIR/i18n_pt.sh"
assert_eq "i18n pt: primeira linha de MSG_USAGE" "Uso:" "$(printf '%s\n' "$MSG_USAGE" | sed -n '1p')"
assert_eq "i18n pt: MSG_ERR_INVALID_SORT" "Erro: --sort inválido: '%s' (use relevance, pub_date, first_author ou journal)." "$MSG_ERR_INVALID_SORT"

source "$LIB_DIR/i18n_en.sh"
assert_eq "i18n en: primeira linha de MSG_USAGE" "Usage:" "$(printf '%s\n' "$MSG_USAGE" | sed -n '1p')"
assert_eq "i18n en: MSG_ERR_INVALID_SORT" "Error: invalid --sort: '%s' (use relevance, pub_date, first_author or journal)." "$MSG_ERR_INVALID_SORT"

# --- i18n: paridade de chaves ---------------------------------
# Extrai os nomes das variáveis MSG_* definidas em um arquivo de idioma.
i18n_keys() {
  local file="$1"
  grep -oE '\bMSG_[A-Za-z0-9_]+' "$file" | sort -u | tr '\n' ' '
}

pt_keys=$(i18n_keys "$LIB_DIR/i18n_pt.sh")
en_keys=$(i18n_keys "$LIB_DIR/i18n_en.sh")
assert_eq "i18n: mesmas chaves em pt e en" "$pt_keys" "$en_keys"

# --- BibTeX ----------------------------------------------------
assert_eq "bibtex_escape: caracteres especiais" 'a\&b\%c\$d\#e\_f\{g\}h' "$(bibtex_escape 'a&b%c$d#e_f{g}h')"
assert_eq "bibtex_year: data completa" "2018" "$(bibtex_year '2018 Jun')"
assert_eq "bibtex_authors: lista" "Morrison, AH and Byrne, KT" "$(bibtex_authors 'Morrison AH, Byrne KT')"
assert_eq "bibtex_authors: vazio" "" "$(bibtex_authors '')"
assert_eq "bibtex_key" "Morrison2018_29860986" "$(bibtex_key '29860986' 'Morrison AH, Byrne KT' '2018 Jun')"
assert_eq "bibtex_key: sem autor" "pmid123" "$(bibtex_key '123' '' '2020')"
assert_eq "format_bibtex_entry: primeira linha" "@article{Silva2020_123," "$(format_bibtex_entry 'Título & A' 'Silva J, Souza M' 'Revista & Cia' '2020 Jan' '123' '8' '2' '10-20' '10.1000/x' | sed -n '1p')"

# --- BibTeX: campos opcionais ---------------------------------
# extract: pages = DOI deve virar vazio no campo pages (posição 8)
pages_doi_tsv=$(extract_summary_fields '{"result":{"uids":["1"],"1":{"title":"T","source":"J","authors":[{"name":"A B"}],"pubdate":"2020","volume":"8","pages":"10.1000/xyz","articleids":[{"idtype":"doi","value":"10.1000/xyz"}]}}}')
assert_eq "extract: pages=DOI vira vazio" "" "$(printf '%s\n' "$pages_doi_tsv" | cut -f8)"
assert_eq "extract: doi preservado" "10.1000/xyz" "$(printf '%s\n' "$pages_doi_tsv" | cut -f9)"

# format: sem volume/number/pages -> linhas ausentes, doi presente
entry_sem_pages=$(format_bibtex_entry 'Título' 'Yu B, Shao S' 'Cancer Lett' '2025' '39581219' '' '' '' '10.1016/j.canlet.2024.217350')
assert_eq "bibtex: sem volume" "0" "$(printf '%s\n' "$entry_sem_pages" | grep -c 'volume =' || true)"
assert_eq "bibtex: sem number" "0" "$(printf '%s\n' "$entry_sem_pages" | grep -c 'number =' || true)"
assert_eq "bibtex: sem pages" "0" "$(printf '%s\n' "$entry_sem_pages" | grep -c 'pages =' || true)"
assert_eq "bibtex: com doi" "1" "$(printf '%s\n' "$entry_sem_pages" | grep -c 'doi =' || true)"

# format: pages=DOI (defensivo) -> pages omitida
entry_pages_doi=$(format_bibtex_entry 'Título' 'Yu B' 'Cancer Lett' '2025' '39581219' '' '' '10.1016/j.canlet.2024.217350' '10.1016/j.canlet.2024.217350')
assert_eq "bibtex: pages=DOI omitida" "0" "$(printf '%s\n' "$entry_pages_doi" | grep -c 'pages =' || true)"

echo ""
echo "Resultado: $pass aprovados, $fail falha(s)"
[ $fail -eq 0 ]
