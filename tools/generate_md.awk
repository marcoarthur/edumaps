#!/usr/bin/awk -f

BEGIN {
    # Mapeamento de extensões para linguagens do highlight
    lang["js"]     = "javascript"
    lang["mjs"]    = "javascript"
    lang["svelte"] = "svelte"
    lang["html"]   = "html"
    lang["css"]    = "css"
    lang["json"]   = "json"
    lang["md"]     = "markdown"
    lang["sh"]     = "bash"
    lang["txt"]    = "text"
    lang["conf"]   = "text"
    lang["lock"]   = "json"   # package-lock.json
    lang["config"] = "javascript"
    lang["gitignore"] = "text"

    # Imprime cabeçalho do documento
    print "# Conteúdo dos arquivos do frontend (map_app)\n"
    print "Gerado a partir da estrutura atual.\n"

    current_dir = ""
}

# Para cada linha (caminho de arquivo) vinda do stdin
{
    file = $0
    # Remove o "./" inicial se existir
    if (substr(file, 1, 2) == "./") file = substr(file, 3)

    # Extrai o diretório pai
    if (match(file, /^.*\//)) {
        dir = substr(file, 1, RLENGTH-1)
    } else {
        dir = "."
    }

    # Extrai a extensão (último ponto)
    ext = ""
    if (match(file, /\.[^.]*$/)) {
        ext = substr(file, RSTART+1)
    }

    # Determina a linguagem para o bloco de código
    lang_tag = (ext in lang) ? lang[ext] : "text"

    # Quando o diretório muda, imprime cabeçalho de seção
    if (dir != current_dir) {
        if (current_dir != "") print "\n---\n"
        if (dir == ".") {
            print "## 📂 Raiz\n"
        } else {
            print "## 📁 " dir "\n"
        }
        current_dir = dir
    }

    # Imprime o nome do arquivo como subtítulo
    print "### `" file "`\n"

    # Imprime o bloco de código com o conteúdo do arquivo
    print "```" lang_tag
    # Lê o arquivo linha a linha e imprime
    while ((getline line < file) > 0) {
        print line
    }
    close(file)
    print "```\n"
}
