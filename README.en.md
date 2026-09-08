# PubMed Analyzer

![Bash](https://img.shields.io/badge/bash-3.2%2B-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Docker](https://img.shields.io/badge/Docker-Supported-2496ED?logo=docker)

<details>
  <summary><b>👀 Interactive Mode</b></summary>
  
  <br>
  
  ![Interactive Mode](https://vhs.charm.sh/vhs-yzarfgynyikL615iZvq1I.gif)

</details>

<details>
  <summary><b>👀 CLI Mode (Automated Export)</b></summary>

  <br>
  
  ![CLI Mode](https://vhs.charm.sh/vhs-1QTZOdlqvQAGP8hY7ZGONF.gif)

</details>

<br>

Interactive Bash script to search PubMed via
[NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/), browse the
results, view statistics and export the data.

> 🇧🇷 [Versão em português](README.md)

## Dependencies

- **bash** 3.2+ (macOS and Linux compatible)
- **curl** — HTTP requests
- **jq** — JSON parsing and URL encoding

## Usage

### Interactive mode (default)

```bash
./analyze.sh "cancer AND immunotherapy"
./analyze.sh "diabetes type 2" "metformin AND adherence"
```

Date and sort order are prompted interactively. The maximum number of results
accepts an integer or `all` (fetch everything, limited to 100,000 articles).

On the results screen, **`r`** refines the search (term, years, sort order and
max) without leaving the script, and **`b`** exports the results as BibTeX
(`.bib`). Each search/refinement writes a new timestamped log, preserving the
history.

### CLI mode (non-interactive)

When `--query` is provided, the script runs the search, exports and saves the
log without asking anything (ideal for cron, automation and integrations).

```bash
./analyze.sh --query "cancer" --max 50 --output results.csv
./analyze.sh -q "diabetes" -y 2020-2024 -s pub_date -t review -o data.json
./analyze.sh --query "alzheimer" --max 20        # CSV to stdout
./analyze.sh --help
```

| Option              | Description                                                              | Default      |
|---------------------|--------------------------------------------------------------------------|--------------|
| `-q, --query`       | Search term (quote it if it contains spaces)                             | — (required) |
| `-m, --max`         | Maximum number of results (positive integer or `all`)                    | `200`        |
| `-y, --years`       | Year range (`AAAA-AAAA` or `AAAA`)                                       | no limit     |
| `-s, --sort`        | `relevance`, `pub_date`, `first_author`, `journal`                       | `relevance`  |
| `-t, --type`        | Publication type (`any`, `review`, `clinical_trial`, `meta_analysis`, `randomized_controlled_trial`, ...) | `any` |
| `-o, --output`      | Output file; extension defines the format (`.csv`, `.json`, `.txt`, `.bib`) | CSV to stdout |
| `-l, --lang`        | Interface language (`pt` or `en`)                                        | `pt`         |
| `--no-log`          | Do not write the log file                                                | writes       |
| `-h, --help`        | Show help and exit                                                       | —            |

`--type` is appended to the query as `(term) AND type[pt]`.

### Language (`--lang`)

The interface language can be chosen with `-l, --lang`:

```bash
./analyze.sh --lang en --query "cancer" --max 20
./analyze.sh --lang pt --help
```

- In **CLI mode**, without `--lang`, the default is `pt`.
- In **interactive mode**, without `--lang`, the language is detected from the
  `LANG` environment variable (if it starts with `pt`, Portuguese is used;
  otherwise English).

Messages live in `lib/i18n_pt.sh` and `lib/i18n_en.sh`.

### API key (optional, recommended)

A key raises the request limit (10 req/s with a key vs 3 req/s without).
Set the `NCBI_API_KEY` variable or save the key in `~/.pubmed_api_key`.
Get one at <https://www.ncbi.nlm.nih.gov/account/>.

## Installation

To install globally (creates the `pubmed-analyzer` executable):

```bash
./install.sh
```

The script:

- Checks for `curl` and `jq`.
- Copies `analyze.sh` and `lib/` to `/usr/local/lib/pubmed-analyzer`.
- Creates the `/usr/local/bin/pubmed-analyzer` symlink.
- Creates `~/.pubmed_analyzer.conf` (if it doesn't exist).

Then use:

```bash
pubmed-analyzer --query "cancer" --max 20
pubmed-analyzer "term"   # interactive mode
```

`analyze.sh` resolves its real path through symlinks, so the installed
command correctly locates `lib/` even when invoked via the symlink.

## Configuration (`~/.pubmed_analyzer.conf`)

Optional file to override defaults without editing the code:

```bash
#DEFAULT_MAX_RESULTS=200                # default max results
#RESULTS_PER_PAGE=10                    # results per page
#LANG_UI="pt"                            # language (pt or en)
#API_KEY_FILE="$HOME/.pubmed_api_key"   # API key file
```

Uncomment and adjust. Variables are loaded after the defaults, so only the
uncommented lines are overridden.

## Structure

```
analyze.sh            # main entry point and interactive loop
install.sh            # installer (creates the pubmed-analyzer executable)
lib/config.sh         # configuration and global variables
lib/functions.sh      # processing: search, parsing, export, logging
lib/ui.sh             # interface functions
lib/i18n_pt.sh        # Portuguese messages
lib/i18n_en.sh        # English messages
tests/test.sh         # processing function tests
Dockerfile           # reproducible test environment
```

## Generated outputs

| File                          | Contents                                                              |
| ----------------------------- | --------------------------------------------------------------------- |
| `search_logs/search_*.txt`    | Immutable (UTC) search log, with script hash, esearch URL and totals (overall and loaded) |
| `pubmed_results_*.csv`        | Results in CSV                                                        |
| `pubmed_raw_*.json`           | Raw `esummary` JSON + PMIDs + metadata                                |
| `pubmed_pmids_*.txt`          | PMID list (one per line)                                              |
| `pubmed_results_*.bib`        | Results in BibTeX (`@article` with author, title, journal, year, volume, number, pages, doi, pmid, url) |

## Tests

```bash
bash tests/test.sh            # processing functions
bash tests/test_install.sh    # installation (uses temporary directories)
```

## Docker

Build the image:

```bash
docker build -t pubmed-analyzer .
```

Run the test suite inside the container:

```bash
docker run --rm pubmed-analyzer bash tests/test.sh
```

Run a non-interactive search (CSV to stdout):

```bash
docker run --rm pubmed-analyzer ./analyze.sh --query "cancer" --max 5 --no-log
```

Open an interactive shell (then run `./analyze.sh "term"`):

```bash
docker run -it --rm pubmed-analyzer
```

Pass an API key and mount a directory to collect exported files:

```bash
docker run --rm \
  -e NCBI_API_KEY="your-key-here" \
  -v "$PWD/out:/app/out" \
  pubmed-analyzer ./analyze.sh --query "cancer" --max 20 -o /app/out/results.csv
```

You can also test the full installation inside the container (as root):

```bash
docker run --rm pubmed-analyzer bash -c './install.sh && pubmed-analyzer --help'
```

## Limitations

- The NCBI API limits request volume; without a key the limit is lower and very
  large searches can take a while.
- Searches over 100,000 articles are truncated for safety.
- Fields with line breaks/tabs may not be perfectly preserved in CSV/TSV.
