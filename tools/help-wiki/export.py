#!/usr/bin/env python3
import os, sys, re, yaml
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
HELP = ROOT / "docs" / "ajuda"
FUNC = ROOT / "docs" / "funcionalidades"

REQUIRED = {"titulo", "publico", "modulo", "nivel", "status", "ultima_revisao"}
ENUMS = {
    "publico": {"gestor", "professor", "comunidade", "administrador", "desenvolvedor"},
    "modulo": {"gestor", "professor", "comunidade", "administrador", "desenvolvedor"},
    "nivel": {"basico", "intermediario", "avancado"},
    "status": {"ativo", "parcial", "planejado", "descontinuado"},
}

def parse_frontmatter(text):
    if not text.startswith("---"):
        return None, text
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None, text
    try:
        fm = yaml.safe_load(parts[1]) or {}
    except Exception as e:
        raise ValueError(f"YAML inválido no front-matter: {e}")
    body = parts[2].lstrip("\n")
    return fm, body

def check_file(path):
    errors = []
    text = path.read_text(encoding="utf-8")
    fm, body = parse_frontmatter(text)
    if fm is None:
        errors.append("Sem front-matter --- ... ---")
        return errors
    missing = REQUIRED - set(fm.keys())
    if missing:
        errors.append(f"Campos obrigatórios ausentes: {sorted(missing)}")
    for k,v in fm.items():
        if k in ENUMS:
            vals = v if isinstance(v, list) else [v]
            for val in vals:
                if val not in ENUMS[k]:
                    errors.append(f"Valor inválido para {k}: {val} (permitidos: {sorted(ENUMS[k])})")
    if "funcionalidade" in fm and fm["funcionalidade"]:
        fpath = (path.parent / fm["funcionalidade"]).resolve()
        if not fpath.exists():
            errors.append(f"funcionalidade não encontrada: {fm['funcionalidade']}")
    if fm.get("status") == "parcial":
        if "Limitações conhecidas" not in body and "Limitações" not in body:
            errors.append("status: parcial sem seção 'Limitações conhecidas'")
    return errors

def collect_funcionalidades():
    funcs = []
    if not FUNC.exists():
        return funcs
    for md in FUNC.rglob("*.md"):
        if md.name in {"README.md"}:
            continue
        try:
            text = md.read_text(encoding="utf-8")
            fm,_ = parse_frontmatter(text)
        except Exception:
            fm = None
        status = fm.get("status") if fm else None
        funcs.append({
            "path": md,
            "rel": md.relative_to(ROOT).as_posix(),
            "status": status,
            "fm": fm or {}
        })
    return funcs

def collect_help_links():
    links = set()
    if not HELP.exists():
        return links
    for md in HELP.rglob("*.md"):
        try:
            text = md.read_text(encoding="utf-8")
            fm,_ = parse_frontmatter(text)
            if not fm:
                continue
            fn = fm.get("funcionalidade")
            if not fn:
                continue
            target = (md.parent / fn).resolve()
            try:
                links.add(target.relative_to(ROOT).as_posix())
            except Exception:
                pass
        except Exception:
            continue
    return links

def main():
    if not HELP.exists():
        print(f"ERRO: {HELP} não existe")
        sys.exit(1)
    errors_all = []
    count = 0
    for md in sorted(HELP.rglob("*.md")):
        if md.name.startswith("_") and md.name not in {"_template.md", "_glossario.md"}:
            continue
        count += 1
        errs = check_file(md)
        for e in errs:
            errors_all.append(f"{md.relative_to(ROOT)}: {e}")
    print(f"Verificados: {count} arquivos em docs/ajuda/")
    if errors_all:
        print(f"\nERROS ({len(errors_all)}):")
        for e in errors_all:
            print(f"  - {e}")
        sys.exit(1)
    print("\nOK: front-matter e regras básicas validados.")

    # Cobertura funcionalidades -> ajuda
    funcs = collect_funcionalidades()
    linked = collect_help_links()
    ativos = [f for f in funcs if f["status"] == "ativo"]
    missing = []
    for f in ativos:
        if f["rel"] not in linked:
            missing.append(f["rel"])
    print(f"\nCobertura: {len(ativos)} funcionalidades ativas, {len(ativos)-len(missing)} com página de ajuda")
    if missing:
        print(f"Sem página de ajuda ({len(missing)}):")
        for m in sorted(missing):
            print(f"  - {m}")
    else:
        print("Cobertura completa para funcionalidades ativas.")
    sys.exit(0)

if __name__ == "__main__":
    main()
