#!/usr/bin/env bash
# ============================================================
# i18n_en.sh — English messages (Bash 3.2+).
# ============================================================

read -r -d '' MSG_USAGE <<'EOF' || true
Usage:
  ./analyze.sh [options]
  ./analyze.sh "term" ["term2" ...]

Interactive mode (default):
  Without --query, positional arguments are the search terms. The script
  prompts for parameters and enters the navigation loop.

CLI mode (requires --query):
  -q, --query TERM        Search term (quote it if it contains spaces)
  -m, --max N             Maximum number of results (positive integer or 'all'; default 200)
  -y, --years AAAA[-AAAA] Year range (e.g. 2015-2023 or 2020)
  -s, --sort TYPE         relevance (default), pub_date, first_author, journal
  -t, --type TYPE         Publication type (any, review, clinical_trial,
                          meta_analysis, randomized_controlled_trial, ...)
  -o, --output FILE       Output; extension defines format (.csv, .json, .txt, .bib).
                          Default: CSV to stdout.
  -l, --lang LANG         Interface language: pt or en
  --no-log                Do not write the log file
  -h, --help              Show this help and exit

Examples:
  ./analyze.sh --query "cancer" --max 50 --output results.csv
  ./analyze.sh -q "diabetes" -y 2020-2024 -s pub_date -t review -o data.json
  ./analyze.sh --query "alzheimer" --max 20
EOF

MSG_ERR_OPTION_REQUIRES_VALUE="Error: %s requires a value."
MSG_ERR_UNKNOWN_OPTION="Error: unknown option: %s"
MSG_ERR_CLI_REQUIRES_QUERY="Error: CLI options require --query."
MSG_ERR_INVALID_LANG="Error: invalid --lang: '%s' (use pt or en)."
MSG_ERR_INVALID_MAX="Error: invalid --max: '%s' (use a positive integer or 'all')."
MSG_ERR_INVALID_SORT="Error: invalid --sort: '%s' (use relevance, pub_date, first_author or journal)."
MSG_ERR_INVALID_YEARS="Error: invalid --years: '%s' (use AAAA or AAAA-AAAA)."
MSG_ERR_UNKNOWN_OUTPUT_EXT="Error: unrecognized --output extension: '%s' (use .csv, .json, .txt or .bib)."
MSG_WARN_UNKNOWN_TYPE="Warning: unknown --type: '%s'; ignoring filter."

MSG_ERR_CURL_NOT_FOUND="Error: curl not found. Install curl."
MSG_ERR_JQ_NOT_FOUND="Error: jq not found. Install jq."

MSG_SEARCHING="Searching... %d IDs obtained..."
MSG_ERR_NETWORK="Network error: could not connect to NCBI E-utilities."
MSG_CHECK_INTERNET="Check your internet connection and try again."
MSG_ERR_RATE_LIMIT_429="Rate limit exceeded (HTTP 429)."
MSG_WAIT_OR_API_KEY="Wait a moment or configure an NCBI API key."
MSG_ERR_SERVER="NCBI server error (HTTP %s)."
MSG_ERR_REQUEST="Request error (HTTP %s)."
MSG_ERR_INVALID_JSON="Invalid response: the API did not return JSON (HTTP %s)."
MSG_RESPONSE_RECEIVED="Response received (first 200 characters):"
MSG_ERR_API="API returned an error: %s"
MSG_RATE_LIMIT_HINT="Rate limit reached. Wait or use an API key."
MSG_NO_IDS_FOUND="No IDs found for this search."
MSG_SAFETY_LIMIT="Reached the safety limit of 100,000 articles. Stopping search."

MSG_FETCHING_DETAILS="Fetching details... chunk %d of %d (IDs %d-%d)..."
MSG_ERR_NETWORK_SUMMARIES="Network error fetching summaries (chunk %s-%s)."
MSG_ERR_SUMMARIES_HTTP="Error fetching summaries (HTTP %s)."
MSG_ERR_SUMMARIES_NOT_JSON="Error fetching summaries (chunk %s-%s): non-JSON response."
MSG_ERR_SUMMARIES_API="API error fetching summaries: %s"

MSG_LOG_TITLE="=== Immutable Search Log ==="
MSG_LOG_TIMESTAMP="Timestamp (UTC): %s"
MSG_LOG_VERSION="Script version: %s"
MSG_LOG_SHA="Script SHA-256: %s"
MSG_LOG_CONFIG_TITLE="=== Search Configuration ==="
MSG_LOG_TERM="Term: %s"
MSG_LOG_MAX="Max results: %s"
MSG_LOG_SORT="Sort order: %s"
MSG_LOG_YEARS_RANGE="Year range: %s-%s"
MSG_LOG_YEARS_NONE="Year range: no limit"
MSG_LOG_API_KEY_USED="API key used: %s"
MSG_YES="yes"
MSG_NO="no"
MSG_LOG_URL_TITLE="=== URL sent to the API (esearch, api_key masked) ==="
MSG_LOG_RESULT_TITLE="=== Result ==="
MSG_LOG_TOTAL_PUBMED="Total in PubMed (count): %s"
MSG_LOG_COUNT_ZERO_WARN="Note: count=0 despite %s loaded (possibly malformed term)."
MSG_LOG_TOTAL_LOADED="Loaded total: %s"
MSG_LOG_SAVED="Log saved to: %s"

MSG_EXPORT_CSV="Exported file: %s"
MSG_EXPORT_PMIDS="Exported PMIDs file: %s"
MSG_EXPORT_JSON="Exported raw JSON file: %s"
MSG_EXPORT_BIB="Exported BibTeX file: %s"

MSG_SEARCH_TERM="Search term:"
MSG_SEARCHING_RESULTS="Searching..."
MSG_GETTING_DETAILS="Fetching article details..."
MSG_SEARCH_NOT_COMPLETED="Search not completed (see message above)."
MSG_NO_RESULTS_FOR='No results found for "%s".'
MSG_FETCH_FAILED="Failed to fetch article details (code %s)."
MSG_FETCH_DETAILS_FAILED="Failed to fetch article details (see message above)."

MSG_LAST_PAGE="You are already on the last page."
MSG_FIRST_PAGE="You are already on the first page."
MSG_ENTER_ARTICLE_NUMBER="Enter the article number (%s-%s):"
MSG_INVALID_NUMBER="Invalid number."
MSG_OPENING="Opening: %s"
MSG_OPENING_PUBMED="Opening PubMed search: %s"
MSG_STATS_FOR="Statistics for: %s"
MSG_PRESS_ENTER_BACK="Press Enter to go back..."
MSG_PRESS_ENTER_CONTINUE="Press Enter to continue..."
MSG_REFINE="Refine current search"
MSG_CURRENT_TERM="Current term: %s"
MSG_NEW_TERM='New term (Enter to keep "%s"):'
MSG_REFINED="Refined search: %s loaded of %s in PubMed."
MSG_REFINE_FAILED="Refinement not completed."
MSG_EXITING="Exiting..."
MSG_INVALID_OPTION="Invalid option."
MSG_INTERRUPTED="Interrupted by user. Exiting..."

MSG_HEADER_TITLE="        Interactive PubMed Analyzer"

MSG_API_KEY_LOADED="API key loaded from file %s"
MSG_NO_API_KEY="No NCBI API key found."
MSG_GET_API_KEY="You can get a free key at %s"
MSG_API_KEY_BENEFIT="With a key, the request limit is higher and search is faster."
MSG_API_KEY_PROMPT_CONTINUE="If you don't want a key, press Enter (the script will work with lower limits)."
MSG_API_KEY_PROMPT="Enter your API key (or Enter to continue without):"
MSG_API_KEY_SAVED="API key saved to %s"
MSG_API_KEY_CONTINUE_WITHOUT="Continuing without an API key (request limits may apply)."

MSG_MAX_PROMPT="Maximum number (default %s, 'all' for all):"
MSG_ALL_WARNING="Warning: fetching all results may take several minutes and consume many resources."
MSG_CONFIRM="Confirm? (y/N):"
MSG_USING_DEFAULT="Using default %s."
MSG_INVALID_VALUE_DEFAULT="Invalid value. Using default %s."

MSG_YEARS_PROMPT="Year range (e.g. 2010-2020, Enter for no limit):"
MSG_INVALID_YEAR_RANGE="Invalid range format. Using no limit."
MSG_SORT_PROMPT="Sort results:"
MSG_SORT_OPTION_1="  1) Relevance (default)"
MSG_SORT_OPTION_2="  2) Publication date"
MSG_SORT_OPTION_3="  3) First author"
MSG_SORT_OPTION_4="  4) Journal"
MSG_SORT_CHOICE="Choice (1-4, Enter for 1):"

MSG_STAT_JOURNALS="Top 5 Journals:"
MSG_NO_DATA="No data available."
MSG_STAT_AUTHORS="Top 5 Authors:"
MSG_STAT_YEARS="Years with most publications (Top 5):"
MSG_STAT_TOTAL_YEARS="  (Total distinct years: %s)"
MSG_ARTICLES="articles"

MSG_RESULTS_FOR="Results for: %s"
MSG_TOTAL_LINE="PubMed total: %s | Loaded: %s | Page %s of %s"
MSG_OPTIONS="Options:"
MSG_MENU_LINE1="  [n] next page   [p] previous page   [1-10] details"
MSG_MENU_LINE2="  [a] open article in browser   [o] open PubMed search"
MSG_MENU_LINE3="  [s] statistics   [c] CSV   [j] raw JSON   [x] PMIDs   [b] BibTeX   [r] refine   [q] quit"
MSG_PROMPT_CHOICE="Choice:"

MSG_TITLE="Title:"
MSG_JOURNAL="Journal:"
MSG_DATE="Date:"
MSG_AUTHORS="Authors:"
MSG_PMID="PMID:"
MSG_URL="URL:"
MSG_ABSTRACT="Abstract:"
MSG_ABSTRACT_UNAVAILABLE="  Abstract not available."

MSG_WARN_SUSPICIOUS="Warning: the term looks malformed (unbalanced quotes or leading AND/OR/NOT)."
MSG_WARN_REVIEW_TERM="Consider reviewing the search to avoid unexpected results."

MSG_CANNOT_OPEN_BROWSER="Could not open the browser automatically."
MSG_ACCESS_MANUALLY="Access manually: %s"
