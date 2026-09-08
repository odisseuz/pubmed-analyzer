#!/usr/bin/env bash
# ============================================================
# i18n_pt.sh — Mensagens em português (Bash 3.2+).
# ============================================================

read -r -d '' MSG_USAGE <<'EOF' || true
Uso:
  ./analyze.sh [opções]
  ./analyze.sh "termo" ["termo2" ...]

Modo interativo (padrão):
  Sem --query, os argumentos posicionais são os termos de busca. O script
  pergunta parâmetros e entra no loop de navegação.

Modo CLI (requer --query):
  -q, --query TERMO        Termo de busca (entre aspas se houver espaços)
  -m, --max N              Máximo de resultados (inteiro positivo ou 'all'; padrão 200)
  -y, --years AAAA[-AAAA]  Intervalo de anos (ex.: 2015-2023 ou 2020)
  -s, --sort TIPO          relevance (padrão), pub_date, first_author, journal
  -t, --type TIPO          Tipo de publicação (any, review, clinical_trial,
                           meta_analysis, randomized_controlled_trial, ...)
  -o, --output ARQUIVO     Saída; extensão define o formato (.csv, .json, .txt, .bib).
                           Padrão: CSV no stdout.
  -l, --lang IDIOMA        Idioma da interface: pt ou en
  --no-log                 Não salvar o arquivo de log
  -h, --help               Exibe esta ajuda e sai

Exemplos:
  ./analyze.sh --query "cancer" --max 50 --output resultados.csv
  ./analyze.sh -q "diabetes" -y 2020-2024 -s pub_date -t review -o dados.json
  ./analyze.sh --query "alzheimer" --max 20
EOF

MSG_ERR_OPTION_REQUIRES_VALUE="Erro: %s requer um valor."
MSG_ERR_UNKNOWN_OPTION="Erro: opção desconhecida: %s"
MSG_ERR_CLI_REQUIRES_QUERY="Erro: opções CLI requerem --query."
MSG_ERR_INVALID_LANG="Erro: --lang inválido: '%s' (use pt ou en)."
MSG_ERR_INVALID_MAX="Erro: --max inválido: '%s' (use inteiro positivo ou 'all')."
MSG_ERR_INVALID_SORT="Erro: --sort inválido: '%s' (use relevance, pub_date, first_author ou journal)."
MSG_ERR_INVALID_YEARS="Erro: --years inválido: '%s' (use AAAA ou AAAA-AAAA)."
MSG_ERR_UNKNOWN_OUTPUT_EXT="Erro: extensão de --output não reconhecida: '%s' (use .csv, .json, .txt ou .bib)."
MSG_WARN_UNKNOWN_TYPE="Aviso: --type desconhecido: '%s'; ignorando filtro."

MSG_ERR_CURL_NOT_FOUND="Erro: curl não encontrado. Instale o curl."
MSG_ERR_JQ_NOT_FOUND="Erro: jq não encontrado. Instale o jq."

MSG_SEARCHING="Buscando... %d IDs obtidos..."
MSG_ERR_NETWORK="Erro de rede: não foi possível conectar ao NCBI E-utilities."
MSG_CHECK_INTERNET="Verifique sua conexão com a internet e tente novamente."
MSG_ERR_RATE_LIMIT_429="Limite de requisições excedido (HTTP 429)."
MSG_WAIT_OR_API_KEY="Aguarde alguns instantes ou configure uma chave de API do NCBI."
MSG_ERR_SERVER="Erro no servidor do NCBI (HTTP %s)."
MSG_ERR_REQUEST="Erro de requisição (HTTP %s)."
MSG_ERR_INVALID_JSON="Resposta inválida: a API não retornou JSON (HTTP %s)."
MSG_RESPONSE_RECEIVED="Resposta recebida (primeiros 200 caracteres):"
MSG_ERR_API="Erro retornado pela API: %s"
MSG_RATE_LIMIT_HINT="Limite de requisições atingido. Aguarde ou use uma chave de API."
MSG_NO_IDS_FOUND="Nenhum ID encontrado para esta busca."
MSG_SAFETY_LIMIT="Atingido o limite de segurança de 100.000 artigos. Parando a busca."

MSG_FETCHING_DETAILS="Obtendo detalhes... bloco %d de %d (IDs %d-%d)..."
MSG_ERR_NETWORK_SUMMARIES="Erro de rede ao obter sumários (bloco %s-%s)."
MSG_ERR_SUMMARIES_HTTP="Erro ao obter sumários (HTTP %s)."
MSG_ERR_SUMMARIES_NOT_JSON="Erro ao obter sumários (bloco %s-%s): resposta não-JSON."
MSG_ERR_SUMMARIES_API="Erro da API ao obter sumários: %s"

MSG_LOG_TITLE="=== Registro Imutável da Busca ==="
MSG_LOG_TIMESTAMP="Timestamp (UTC): %s"
MSG_LOG_VERSION="Versão do script: %s"
MSG_LOG_SHA="SHA-256 do script: %s"
MSG_LOG_CONFIG_TITLE="=== Configuração da Busca ==="
MSG_LOG_TERM="Termo: %s"
MSG_LOG_MAX="Máximo de resultados: %s"
MSG_LOG_SORT="Ordenação: %s"
MSG_LOG_YEARS_RANGE="Intervalo de anos: %s-%s"
MSG_LOG_YEARS_NONE="Intervalo de anos: sem limite"
MSG_LOG_API_KEY_USED="Chave de API usada: %s"
MSG_YES="sim"
MSG_NO="não"
MSG_LOG_URL_TITLE="=== URL enviada à API (esearch, api_key mascarado) ==="
MSG_LOG_RESULT_TITLE="=== Resultado ==="
MSG_LOG_TOTAL_PUBMED="Total geral no PubMed (count): %s"
MSG_LOG_COUNT_ZERO_WARN="Atenção: count=0 apesar de %s carregados (termo possivelmente malformado)."
MSG_LOG_TOTAL_LOADED="Total carregado: %s"
MSG_LOG_SAVED="Registro salvo em: %s"

MSG_EXPORT_CSV="Arquivo exportado: %s"
MSG_EXPORT_PMIDS="Arquivo de PMIDs exportado: %s"
MSG_EXPORT_JSON="Arquivo JSON bruto exportado: %s"
MSG_EXPORT_BIB="Arquivo BibTeX exportado: %s"

MSG_SEARCH_TERM="Termo de busca:"
MSG_SEARCHING_RESULTS="Buscando resultados..."
MSG_GETTING_DETAILS="Obtendo detalhes dos artigos..."
MSG_SEARCH_NOT_COMPLETED="Busca não concluída (consulte a mensagem acima)."
MSG_NO_RESULTS_FOR='Nenhum resultado encontrado para "%s".'
MSG_FETCH_FAILED="Falha ao obter detalhes dos artigos (código %s)."
MSG_FETCH_DETAILS_FAILED="Falha ao obter detalhes dos artigos (consulte a mensagem acima)."

MSG_LAST_PAGE="Você já está na última página."
MSG_FIRST_PAGE="Você já está na primeira página."
MSG_ENTER_ARTICLE_NUMBER="Digite o número do artigo (%s-%s):"
MSG_INVALID_NUMBER="Número inválido."
MSG_OPENING="Abrindo: %s"
MSG_OPENING_PUBMED="Abrindo busca no PubMed: %s"
MSG_STATS_FOR="Estatísticas para: %s"
MSG_PRESS_ENTER_BACK="Pressione Enter para voltar..."
MSG_PRESS_ENTER_CONTINUE="Pressione Enter para continuar..."
MSG_REFINE="Refinar busca atual"
MSG_CURRENT_TERM="Termo atual: %s"
MSG_NEW_TERM='Novo termo (Enter para manter "%s"):'
MSG_REFINED="Busca refinada: %s carregados de %s no PubMed."
MSG_REFINE_FAILED="Refinamento não concluído."
MSG_EXITING="Saindo..."
MSG_INVALID_OPTION="Opção inválida."
MSG_INTERRUPTED="Interrompido pelo usuário. Saindo..."

MSG_HEADER_TITLE="         PubMed Analyzer Interativo"

MSG_API_KEY_LOADED="Chave de API carregada do arquivo %s"
MSG_NO_API_KEY="Nenhuma chave de API do NCBI encontrada."
MSG_GET_API_KEY="Você pode obter uma chave gratuita em %s"
MSG_API_KEY_BENEFIT="Com uma chave, o limite de requisições é maior e a busca é mais rápida."
MSG_API_KEY_PROMPT_CONTINUE="Se não quiser usar uma chave, pressione Enter (o script funcionará, mas com limites menores)."
MSG_API_KEY_PROMPT="Digite sua chave de API (ou Enter para continuar sem):"
MSG_API_KEY_SAVED="Chave de API salva em %s"
MSG_API_KEY_CONTINUE_WITHOUT="Continuando sem chave de API (pode haver limites de requisições)."

MSG_MAX_PROMPT="Número máximo (padrão %s, 'all' para todos):"
MSG_ALL_WARNING="Aviso: buscar todos os resultados pode levar vários minutos e consumir muitos recursos."
MSG_CONFIRM="Confirma? (s/N):"
MSG_USING_DEFAULT="Usando padrão %s."
MSG_INVALID_VALUE_DEFAULT="Valor inválido. Usando padrão %s."

MSG_YEARS_PROMPT="Intervalo de anos (ex: 2010-2020, Enter para sem limite):"
MSG_INVALID_YEAR_RANGE="Formato de intervalo inválido. Usando sem limite."
MSG_SORT_PROMPT="Ordenação dos resultados:"
MSG_SORT_OPTION_1="  1) Relevância (padrão)"
MSG_SORT_OPTION_2="  2) Data de publicação"
MSG_SORT_OPTION_3="  3) Primeiro autor"
MSG_SORT_OPTION_4="  4) Revista"
MSG_SORT_CHOICE="Escolha (1-4, Enter para 1):"

MSG_STAT_JOURNALS="Top 5 Periódicos:"
MSG_NO_DATA="Nenhum dado disponível."
MSG_STAT_AUTHORS="Top 5 Autores:"
MSG_STAT_YEARS="Anos com mais publicações (Top 5):"
MSG_STAT_TOTAL_YEARS="  (Total de anos distintos: %s)"
MSG_ARTICLES="artigos"

MSG_RESULTS_FOR="Resultados para: %s"
MSG_TOTAL_LINE="Total no PubMed: %s | Carregados: %s | Página %s de %s"
MSG_OPTIONS="Opções:"
MSG_MENU_LINE1="  [n] próxima página   [p] página anterior   [1-10] ver detalhes"
MSG_MENU_LINE2="  [a] abrir artigo no navegador   [o] abrir busca no PubMed"
MSG_MENU_LINE3="  [s] estatísticas   [c] CSV   [j] JSON bruto   [x] PMIDs   [b] BibTeX   [r] refinar   [q] sair"
MSG_PROMPT_CHOICE="Escolha:"

MSG_TITLE="Título:"
MSG_JOURNAL="Revista:"
MSG_DATE="Data:"
MSG_AUTHORS="Autores:"
MSG_PMID="PMID:"
MSG_URL="URL:"
MSG_ABSTRACT="Abstract:"
MSG_ABSTRACT_UNAVAILABLE="  Abstract não disponível."

MSG_WARN_SUSPICIOUS="Aviso: o termo parece malformado (aspas desbalanceadas ou operador AND/OR/NOT no início)."
MSG_WARN_REVIEW_TERM="Recomendo revisar a busca para evitar resultados inesperados."

MSG_CANNOT_OPEN_BROWSER="Não foi possível abrir o navegador automaticamente."
MSG_ACCESS_MANUALLY="Acesse manualmente: %s"
