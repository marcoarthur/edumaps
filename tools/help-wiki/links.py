"""Links relativos entre docs/ajuda e docs/funcionalidades.

Compartilhado por export.py (validação) e build_pages.py (site): os dois
precisam da mesma resposta para "este link aponta para onde?".
"""
import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent.parent
DOCS = ROOT / "docs"
# Pastas publicadas no site, na mesma estrutura de docs/
PUBLISHED = ("ajuda", "funcionalidades")
REPO_URL = "https://github.com/marcoarthur/edumaps"

# [texto](alvo) e ![alt](alvo); aceita o alvo entre <>; ignora "título"
MD_LINK = re.compile(r'!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')
CODE = re.compile(r"```.*?```|`[^`\n]*`", re.S)


def is_external(target):
    return bool(re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I)) or target.startswith("#")


def resolve(src, target):
    """Caminho absoluto do alvo de um link relativo (sem a âncora)."""
    path = unquote(target.split("#", 1)[0])
    if not path:
        return None
    return (src.parent / path).resolve()


def is_published(path):
    try:
        rel = path.relative_to(DOCS)
    except ValueError:
        return False
    return bool(rel.parts) and rel.parts[0] in PUBLISHED


def links_in(text):
    """Alvos de link do Markdown, fora de blocos de código."""
    return MD_LINK.findall(CODE.sub("", text))


def broken_links(src):
    """Links relativos de `src` cujo alvo não existe."""
    out = []
    for target in links_in(src.read_text(encoding="utf-8")):
        if is_external(target) or "<" in target or "..." in target:
            continue
        path = resolve(src, target)
        if path is not None and not path.exists():
            out.append(target)
    return out
