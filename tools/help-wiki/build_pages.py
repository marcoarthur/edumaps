#!/usr/bin/env python3
"""Gera o site de ajuda (GitHub Pages) em _site/.

Estrutura do site = estrutura de docs/:
  _site/ajuda/...            páginas de ajuda
  _site/funcionalidades/...  fichas do catálogo
assim os links relativos da ajuda para as fichas funcionam sem reescrita.
Links para fora dessas duas pastas viram links do arquivo no GitHub.
"""
import html as htmlmod
import os
import re
import shutil
import sys
from pathlib import Path

import markdown
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from links import DOCS, PUBLISHED, REPO_URL, ROOT, is_external, is_published, resolve  # noqa: E402

DST = ROOT / "_site"
SKIP = {"_template.md"}
SECTIONS = {"ajuda": "Ajuda", "funcionalidades": "Funcionalidades"}

md = markdown.Markdown(extensions=["extra", "toc", "fenced_code", "tables"])


def split_frontmatter(text):
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) == 3:
            try:
                fm = yaml.safe_load(parts[1]) or {}
            except yaml.YAMLError:
                fm = {}
            return fm, parts[2].lstrip("\n")
    return {}, text


def rewrite_href(src, href):
    if is_external(href) or href.startswith("/"):
        return href
    target = resolve(src, href)
    if target is None:
        return href
    anchor = "#" + href.split("#", 1)[1] if "#" in href else ""
    if is_published(target) and target.name not in SKIP:
        if target.suffix == ".md":
            href = re.sub(r"\.md(?=$|#)", ".html", href)
        return href
    # Fora do site: aponta para o arquivo no repositório
    try:
        rel = target.relative_to(ROOT).as_posix()
    except ValueError:
        return href
    kind = "tree" if target.is_dir() else "blob"
    return f"{REPO_URL}/{kind}/main/{rel}{anchor}"


def fix_links(html, src):
    return re.sub(
        r'(href|src)="([^"]+)"',
        lambda m: f'{m.group(1)}="{htmlmod.escape(rewrite_href(src, htmlmod.unescape(m.group(2))))}"',
        html,
    )


def page(title, body, prefix):
    nav = (
        f'<nav><a href="{prefix}ajuda/index.html">Ajuda</a> · '
        f'<a href="{prefix}funcionalidades/index.html">Funcionalidades</a> · '
        f'<a href="{REPO_URL}">Repositório</a></nav>'
    )
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{htmlmod.escape(title)} - Ajuda EduMaps</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/water.css@2/out/water.css">
<style>
body{{max-width:900px;margin:0 auto;padding:1rem}}
nav{{margin-bottom:2rem;padding-bottom:1rem;border-bottom:1px solid #ddd}}
pre{{overflow-x:auto}}
</style>
</head>
<body>{nav}<main>{body}</main></body>
</html>"""


def redirect(to):
    return (
        '<!doctype html><meta charset="utf-8">'
        f'<meta http-equiv="refresh" content="0; url={to}">'
        f'<link rel="canonical" href="{to}"><a href="{to}">{to}</a>'
    )


def build():
    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir()
    for section in PUBLISHED:
        src_root = DOCS / section
        for root, dirs, files in os.walk(src_root):
            dirs[:] = sorted(d for d in dirs if not d.startswith("."))
            root = Path(root)
            out_dir = DST / root.relative_to(DOCS)
            out_dir.mkdir(parents=True, exist_ok=True)
            depth = len(root.relative_to(DOCS).parts)
            prefix = "../" * depth
            for fname in sorted(files):
                if fname.startswith(".") or fname in SKIP:
                    continue
                src = root / fname
                if fname.endswith(".md"):
                    fm, body = split_frontmatter(src.read_text(encoding="utf-8"))
                    title = str(fm.get("titulo") or fname[:-3].replace("-", " ").capitalize())
                    html = fix_links(md.reset().convert(body), src)
                    out = out_dir / (fname[:-3] + ".html")
                    out.write_text(page(title, html, prefix), encoding="utf-8")
                    if fname == "README.md":
                        shutil.copy(out, out_dir / "index.html")
                else:
                    shutil.copy2(src, out_dir / fname)

    # Raiz do site → ajuda; endereços antigos (ajuda na raiz) redirecionam
    (DST / "index.html").write_text(redirect("ajuda/index.html"), encoding="utf-8")
    for old in (DST / "ajuda").rglob("*.html"):
        rel = old.relative_to(DST / "ajuda")
        stub = DST / rel
        if stub.exists():
            continue
        stub.parent.mkdir(parents=True, exist_ok=True)
        up = "../" * (len(rel.parts) - 1)
        stub.write_text(redirect(f"{up}ajuda/{rel.as_posix()}"), encoding="utf-8")
    (DST / ".nojekyll").write_text("")
    print(f"Site gerado em {DST.relative_to(ROOT)}/: "
          f"{sum(1 for _ in DST.rglob('*.html'))} páginas HTML")


if __name__ == "__main__":
    build()
