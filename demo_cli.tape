# PubMed Analyzer — demo CLI (modo declarativo)
# Gera demo_cli.gif. Foco no "money shot": uma linha de comando
# gera citações BibTeX com DOI + um log reprodutível.
#
# Requer: vhs (ttyd/ffmpeg), curl, jq, bat e rede.

Output demo_cli.gif

Require curl
Require jq
Require bat

Set Shell bash
Set Theme "Catppuccin Frappe"
Set FontSize 20
Set Width 980
Set Height 640
Set Padding 24
Set Margin 46
Set MarginFill "#303446"
Set WindowBar Colorful
Set BorderRadius 14
Set CursorBlink false
Set TypingSpeed 30ms

# 1. Busca declarativa com filtros (tipo, anos, ordenação)
Type "./analyze.sh --lang en -q 'cancer immunotherapy' -t review -y 2020-2024 -s pub_date --max 8 -o refs.bib"
Enter
Sleep 6s

# 2. BibTeX com DOI, volume e páginas (syntax highlight)
Type "bat --paging=never refs.bib"
Enter
Sleep 8s

# 3. Log imutável: SHA-256, count geral e URL mascarada
Type `bat --paging=never "$(ls -t search_logs/search_*.txt | head -n 1)"`
Enter
Sleep 8s

Type "clear"
Enter
