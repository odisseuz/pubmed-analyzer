# PubMed Analyzer — demo interativo (modo manual)
# Gera demo_interactive.gif mostrando o fluxo manual:
# busca com prompts -> abstract -> estatísticas.
#
# Requer: vhs (com ttyd/ffmpeg), curl, jq e rede.

Output demo_interactive.gif

Require curl
Require jq

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

# 1. Abre o app em modo interativo (pt)
Type "./analyze.sh --lang pt 'autism'"
Enter
Sleep 500ms

# 2. Responde os prompts: máximo, anos e ordenação
Type "8"
Enter
Sleep 400ms
Type "2020-2024"
Enter
Sleep 400ms
Type "2"
Enter
Sleep 5s

# 3. Abre o abstract do 1º artigo
Type "1"
Enter
Sleep 4s

# 4. Volta para os resultados
Enter
Sleep 600ms

# 5. Estatísticas
Type "s"
Enter
Sleep 2s

# 6. Volta
Enter
Sleep 600ms

# 7. Sai
Type "q"
Enter
Sleep 400ms
