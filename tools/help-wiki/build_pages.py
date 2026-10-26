#!/usr/bin/env python3
import markdown, pathlib, shutil, os, re

ROOT = pathlib.Path('.')
SRC = ROOT / 'docs' / 'ajuda'
DST = ROOT / '_site'

DST.mkdir(exist_ok=True)
md = markdown.Markdown(extensions=['extra','toc','fenced_code','tables'])

def strip_frontmatter(text):
    if text.startswith('---'):
        parts = text.split('---', 2)
        if len(parts) == 3:
            return parts[2].lstrip('\n')
    return text

def render_html(content, title, prefix):
    html = md.convert(content)
    md.reset()
    nav = f'<nav><a href="{prefix}index.html">← Início</a> | <a href="https://github.com/marcoarthur/edumaps">Repositório</a></nav>'
    return f'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} - Ajuda EduMaps</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/water.css@2/out/water.css">
<style>
body{{max-width:900px;margin:0 auto;padding:1rem}}
nav{{margin-bottom:2rem;padding-bottom:1rem;border-bottom:1px solid #ddd}}
pre{{overflow-x:auto}}
</style>
</head>
<body>{nav}<main>{html}</main></body>
</html>'''

# Copy and convert
shutil.copy(SRC / 'README.md', DST / 'README.md')
# Copy subdirs
for sub in ['gestor', 'comunidade', 'administrador', 'professor', 'desenvolvedor']:
    s = SRC / sub
    if s.exists():
        d = DST / sub
        d.mkdir(exist_ok=True)
        for f in s.glob('*.md'):
            shutil.copy(f, d / f.name)
for extra in ['_glossario.md', '_template.md']:
    if (SRC / extra).exists():
        shutil.copy(SRC / extra, DST / extra)

# Convert all md
for root, dirs, files in os.walk(DST):
    for fname in files:
        if not fname.endswith('.md'): continue
        if fname == '_template.md': continue
        p = pathlib.Path(root) / fname
        try:
            content = strip_frontmatter(p.read_text(encoding='utf-8'))
            depth = len(p.relative_to(DST).parts) - 1
            prefix = '../' * depth if depth > 0 else ''
            html = render_html(content, p.stem.replace('-', ' ').title(), prefix)
            p.with_suffix('.html').write_text(html, encoding='utf-8')
            print(f'OK {p.relative_to(DST)}')
        except Exception as e:
            print(f'ERR {p}: {e}')

# index
if (DST / 'README.html').exists():
    shutil.copy(DST / 'README.html', DST / 'index.html')
    print('index.html created')
