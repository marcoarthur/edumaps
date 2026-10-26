#!/usr/bin/env python3
import markdown, pathlib, shutil, os

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

# Copy everything preserving structure
for root, dirs, files in os.walk(SRC):
    # Skip hidden dirs
    dirs[:] = [d for d in dirs if not d.startswith('.')]
    rel_root = pathlib.Path(root).relative_to(SRC)
    dst_root = DST / rel_root
    dst_root.mkdir(parents=True, exist_ok=True)
    for fname in files:
        if fname.startswith('.'): continue
        src_file = pathlib.Path(root) / fname
        dst_file = dst_root / fname
        if fname.endswith('.md') and fname not in ['_template.md']:
            try:
                content = strip_frontmatter(src_file.read_text(encoding='utf-8'))
                depth = len((rel_root / fname).parts) - 1
                prefix = '../' * depth if depth > 0 else ''
                title = fname.replace('.md', '').replace('-', ' ').title()
                html = render_html(content, title, prefix)
                dst_file.with_suffix('.html').write_text(html, encoding='utf-8')
                print(f'Converted {(rel_root/fname).as_posix()}')
            except Exception as e:
                print(f'ERR {fname}: {e}')
        elif fname not in ['_template.md']:
            shutil.copy2(src_file, dst_file)

# Ensure index.html exists
if (DST / 'README.html').exists():
    shutil.copy(DST / 'README.html', DST / 'index.html')
    print('index.html ready')
elif (DST / 'index.html').exists():
    pass
else:
    (DST / 'index.html').write_text('<!doctype html><html><head><meta charset="utf-8"></head><body><h1>Ajuda EduMaps</h1></body></html>')
