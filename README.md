# PubMed Analyzer

Script interativo em Bash para buscar artigos no PubMed via
[NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/), navegar pelos
resultados, ver estatísticas e exportar os dados.

> 🇬🇧 [English version](README.en.md)

## Dependências

- **bash** 3.2+ (compatível com macOS e Linux)
- **curl** — requisições HTTP
- **jq** — parse de JSON e encoding de URL

## Uso

### Modo interativo (padrão)

```bash
./analyze.sh "cancer AND immunotherapy"
./analyze.sh "diabetes type 2" "metformin AND adherence"
```

Data e ordenação são solicitadas interativamente. Como número máximo de
resultados, aceita um inteiro ou `all` (busca tudo, limitado a 100.000 artigos).

Na tela de resultados, a tecla **`r`** refina a busca (termo, anos, ordenação e
máximo) sem sair do script, e a tecla **`b`** exporta os resultados em BibTeX
(`.bib`). Cada busca/refinamento gera um novo log com timestamp e preserva o
histórico.

### Modo CLI (não interativo)

Quando `--query` é passado, o script executa a busca, exporta e salva o log sem
perguntar nada (ideal para cron, automações e integrações).

```bash
./analyze.sh --query "cancer" --max 50 --output resultados.csv
./analyze.sh -q "diabetes" -y 2020-2024 -s pub_date -t review -o dados.json
./analyze.sh --query "alzheimer" --max 20        # CSV no stdout
./analyze.sh --help
```

| Opção               | Descrição                                                                 | Padrão      |
|---------------------|---------------------------------------------------------------------------|-------------|
| `-q, --query`       | Termo de busca (entre aspas se houver espaços)                            | — (obrig.)  |
| `-m, --max`         | Máximo de resultados (inteiro positivo ou `all`)                          | `200`       |
| `-y, --years`       | Intervalo de anos (`AAAA-AAAA` ou `AAAA`)                                 | sem limite  |
| `-s, --sort`        | `relevance`, `pub_date`, `first_author`, `journal`                        | `relevance` |
| `-t, --type`        | Tipo de publicação (`any`, `review`, `clinical_trial`, `meta_analysis`, `randomized_controlled_trial`, ...) | `any` |
| `-o, --output`      | Arquivo de saída; extensão define o formato (`.csv`, `.json`, `.txt`, `.bib`) | CSV no stdout |
| `-l, --lang`        | Idioma da interface (`pt` ou `en`)                                         | `pt`         |
| `--no-log`          | Não salvar o log                                                          | salva       |
| `-h, --help`        | Exibe a ajuda e sai                                                       | —           |

O `--type` é adicionado à query como `(termo) AND tipo[pt]`.

### Idioma (`--lang`)

O idioma da interface pode ser escolhido com `-l, --lang`:

```bash
./analyze.sh --lang en --query "cancer" --max 20
./analyze.sh --lang pt --help
```

- No **modo CLI**, sem `--lang`, o padrão é `pt`.
- No **modo interativo**, sem `--lang`, o idioma é detectado a partir da
  variável de ambiente `LANG` (se começar com `pt`, usa português; caso
  contrário, inglês).

As mensagens estão em `lib/i18n_pt.sh` e `lib/i18n_en.sh`.

### Chave de API (opcional, recomendada)

Uma chave aumenta o limite de requisições (10 req/s com chave vs 3 req/s sem).
Defina a variável `NCBI_API_KEY` ou salve a chave em `~/.pubmed_api_key`.
Obtenha uma em <https://www.ncbi.nlm.nih.gov/account/>.

## Instalação

Para instalar globalmente (cria o executável `pubmed-analyzer`):

```bash
./install.sh
```

O script:

- Verifica `curl` e `jq`.
- Copia `analyze.sh` e `lib/` para `/usr/local/lib/pubmed-analyzer`.
- Cria o link simbólico `/usr/local/bin/pubmed-analyzer`.
- Cria `~/.pubmed_analyzer.conf` (se não existir).

Depois, use:

```bash
pubmed-analyzer --query "cancer" --max 20
pubmed-analyzer "termo"   # modo interativo
```

O `analyze.sh` resolve o caminho real via links simbólicos, então o executável
instalado localiza corretamente `lib/` mesmo sendo chamado pelo link.

## Configuração (`~/.pubmed_analyzer.conf`)

Arquivo opcional para sobrescrever padrões sem editar o código:

```bash
#DEFAULT_MAX_RESULTS=200                # máximo de resultados padrão
#RESULTS_PER_PAGE=10                    # resultados por página
#LANG_UI="pt"                            # idioma (pt ou en)
#API_KEY_FILE="$HOME/.pubmed_api_key"   # arquivo da chave de API
```

Descomente e ajuste o valor. As variáveis são carregadas após os padrões, então
somente as linhas descomentadas são sobrescritas.

## Estrutura

```
analyze.sh            # entrada principal e loop interativo
install.sh            # instalador (cria o executável pubmed-analyzer)
lib/config.sh         # configurações e variáveis globais
lib/functions.sh      # processamento: busca, parsing, exportação, logging
lib/ui.sh             # funções de interface
lib/i18n_pt.sh        # mensagens em português
lib/i18n_en.sh        # mensagens em inglês
tests/test.sh         # testes das funções de processamento
Dockerfile           # ambiente de teste reproduzível
```

## Saídas geradas

| Arquivo                       | Conteúdo                                                              |
| ----------------------------- | --------------------------------------------------------------------- |
| `search_logs/search_*.txt`    | Registro imutável (UTC) da busca, com hash do script, URL do esearch e totais (geral e carregado) |
| `pubmed_results_*.csv`        | Resultados em CSV                                                     |
| `pubmed_raw_*.json`           | JSON bruto do `esummary` + PMIDs + metadados                          |
| `pubmed_pmids_*.txt`          | Lista de PMIDs (um por linha)                                         |
| `pubmed_results_*.bib`        | Resultados em BibTeX (`@article` com author, title, journal, year, volume, number, pages, doi, pmid, url) |

## Testes

```bash
bash tests/test.sh            # funções de processamento
bash tests/test_install.sh    # instalação (usa diretórios temporários)
```

## Limitações

- A API do NCBI limita o volume de requisições; sem chave o limite é menor e
  buscas muito grandes podem demorar.
- Buscas com mais de 100.000 artigos são truncadas por segurança.
- Campos com quebras de linha/tabulação podem não ser preservados perfeitamente
  no CSV/TSV.

## Teste em ambiente isolado (Docker)

Construir a imagem:

```bash
docker build -t pubmed-analyzer .
```

Rodar os testes dentro do contêiner:

```bash
docker run --rm pubmed-analyzer bash tests/test.sh
```

Busca não interativa (CSV no stdout):

```bash
docker run --rm pubmed-analyzer ./analyze.sh --query "cancer" --max 5 --no-log
```

Abrir um shell interativo (depois rode `./analyze.sh "termo"`):

```bash
docker run -it --rm pubmed-analyzer
```

Passar uma chave de API e montar um diretório para coletar os arquivos exportados:

```bash
docker run --rm \
  -e NCBI_API_KEY="sua-chave-aqui" \
  -v "$PWD/out:/app/out" \
  pubmed-analyzer ./analyze.sh --query "cancer" --max 20 -o /app/out/resultados.csv
```

Também é possível testar a instalação completa dentro do contêiner (como root):

```bash
docker run --rm pubmed-analyzer bash -c './install.sh && pubmed-analyzer --help'
```
