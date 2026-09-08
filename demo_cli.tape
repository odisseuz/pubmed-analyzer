# PubMed Analyzer — demo CLI (modo declarativo/automático)
# Gera demo_cli.gif mostrando o fluxo automático:
# busca declarativa -> BibTeX -> log imutável (com SHA).
#
# Requer: vhs (com ttyd/ffmpeg), curl, jq, bat e rede.

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
Set TypingSpeed 15ms

# 1. Busca declarativa (mesma pesquisa, em uma linha)
Type "./analyze.sh --lang en -q 'autism' -y 2020-2024 -s pub_date --max 8 -o refs.bib"
Enter
Sleep 5s

# 2. BibTeX com syntax highlight (bat)
Type "bat refs.bib"
Enter
Sleep 4s

# 3. Log imutável, com SHA e URL mascarada (bat no log mais recente)
Type `bat "$(ls -t search_logs/search_*.txt | head -n 1)"`
Enter
Sleep 5s

# Limpa
Type "clear"
Enter
