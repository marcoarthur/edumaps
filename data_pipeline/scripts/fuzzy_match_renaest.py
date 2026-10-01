#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fuzzy matching script para completar o de-para RENAEST localidade → município IBGE.

Uso:
    python fuzzy_match_renaest.py --input-csv renaest_localidades.csv --output-csv matches.csv
    python fuzzy_match_renaest.py --pg-host localhost --pg-db edumaps_dev --pg-user devel --pg-password senhaboa123

O script:
1. Carrega municípios IBGE da tabela malha_municipio
2. Carrega localidades RENAEST (de CSV ou tabela renaest_sinistro)
3. Faz matching exato → fuzzy (rapidfuzz) → manual
4. Exporta CSV com matches para revisão/importação
"""

import argparse
import sys
import csv
import psycopg2
from rapidfuzz import fuzz, process
import unicodedata
import re

def normalize(text):
    """Normaliza texto para matching: remove acentos, lowercase, remove pontuação extra."""
    if not text:
        return ""
    # Normaliza unicode
    text = unicodedata.normalize('NFKD', text)
    # Remove acentos
    text = ''.join(c for c in text if not unicodedata.combining(c))
    # Lowercase
    text = text.lower()
    # Remove pontuação exceto espaços e hífens
    text = re.sub(r'[^\w\s-]', '', text)
    # Normaliza espaços
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def load_ibge_municipios(pg_conn):
    """Carrega municípios IBGE da tabela malha_municipio."""
    query = """
        SELECT codigo_ibge, nome_municipio, sigla_uf
        FROM clean.malha_municipio
        WHERE codigo_ibge IS NOT NULL AND nome_municipio IS NOT NULL
    """
    cursor = pg_conn.cursor()
    cursor.execute(query)
    rows = cursor.fetchall()
    
    # Cria dicionário normalizado → (codigo_ibge, nome_original, uf)
    municipios = {}
    for row in rows:
        codigo_ibge, nome, uf = row
        norm = normalize(nome)
        key = (norm, uf)
        if key not in municipios:
            municipios[key] = []
        municipios[key].append((codigo_ibge, nome, uf))
    return municipios

def load_renaest_localidades_csv(csv_path):
    """Carrega localidades RENAEST de CSV."""
    localidades = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            localidade = row.get('localidade') or row.get('localidade_nome')
            uf = row.get('uf') or row.get('sigla_uf')
            if localidade and uf:
                localidades.append((localidade.strip(), uf.strip()))
    return localidades

def load_renaest_localidades_pg(pg_conn):
    """Carrega localidades RENAEST da tabela renaest_sinistro."""
    query = """
        SELECT DISTINCT localidade, uf
        FROM clean.renaest_sinistro
        WHERE localidade IS NOT NULL AND uf IS NOT NULL
    """
    cursor = pg_conn.cursor()
    cursor.execute(query)
    rows = cursor.fetchall()
    return [(row[0].strip(), row[1].strip()) for row in rows]

def fuzzy_match(localidade, uf, ibge_dict, threshold=70, limit=5):
    """Faz fuzzy matching de uma localidade contra municípios IBGE."""
    norm_loc = normalize(localidade)
    key = (normalize(localidade), uf)
    
    # 1. Match exato
    if key in ibge_dict:
        matches = ibge_dict[key]
        return [(codigo, nome, uf, 100, 'exact') for codigo, nome, uf in matches]
    
    # 2. Fuzzy matching
    candidates = []
    for (norm_nome, norm_uf), municipios in ibge_dict.items():
        if norm_uf != uf:
            continue
        score = fuzz.ratio(norm_loc, norm_nome)
        if score >= threshold:
            for codigo, nome, uf_orig in municipios:
                candidates.append((codigo, nome, uf_orig, score, 'fuzzy'))
    
    # Ordena por score decrescente
    candidates.sort(key=lambda x: x[3], reverse=True)
    return candidates[:limit]

def main():
    parser = argparse.ArgumentParser(description='Fuzzy matching RENAEST localidade → município IBGE')
    parser.add_argument('--input-csv', help='CSV com localidades RENAEST (colunas: localidade, uf)')
    parser.add_argument('--output-csv', default='renaest_matches.csv', help='CSV de saída com matches')
    parser.add_argument('--pg-host', default='localhost', help='PostgreSQL host')
    parser.add_argument('--pg-port', default=5432, type=int, help='PostgreSQL port')
    parser.add_argument('--pg-db', default='edumaps_dev', help='PostgreSQL database')
    parser.add_argument('--pg-user', default='devel', help='PostgreSQL user')
    parser.add_argument('--pg-password', default='senhaboa123', help='PostgreSQL password')
    parser.add_argument('--threshold', type=int, default=70, help='Threshold fuzzy match (0-100)')
    parser.add_argument('--limit', type=int, default=3, help='Limite de matches por localidade')
    args = parser.parse_args()
    
    # Conecta ao PostgreSQL
    try:
        pg_conn = psycopg2.connect(
            host=args.pg_host, port=args.pg_port,
            database=args.pg_db, user=args.pg_user,
            password=args.pg_password
        )
    except Exception as e:
        print(f"Erro ao conectar ao PostgreSQL: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Carrega municípios IBGE
    print("Carregando municípios IBGE...")
    ibge_dict = load_ibge_municipios(pg_conn)
    print(f"  {len(ibge_dict)} chaves únicas (nome_normalizado, UF) carregadas.")
    
    # Carrega localidades RENAEST
    if args.input_csv:
        print(f"Carregando localidades de {args.input_csv}...")
        localidades = load_renaest_localidades_csv(args.input_csv)
    else:
        print("Carregando localidades RENAEST da tabela renaest_sinistro...")
        localidades = load_renaest_localidades_pg(pg_conn)
    print(f"  {len(localidades)} localidades carregadas.")
    
    # Matching
    print("Executando matching...")
    results = []
    exact_count = 0
    fuzzy_count = 0
    no_match_count = 0
    
    for localidade, uf in localidades:
        matches = fuzzy_match(localidade, uf, ibge_dict, args.threshold, args.limit)
        
        if not matches:
            results.append({
                'localidade_renaest': localidade,
                'uf': uf,
                'codigo_ibge': '',
                'municipio_ibge': '',
                'match_type': 'none',
                'match_score': 0,
                'notes': 'Sem match encontrado'
            })
            no_match_count += 1
        elif matches[0][3] == 100 and matches[0][4] == 'exact':
            # Match exato - pega o primeiro
            codigo, nome, uf_match, score, mtype = matches[0]
            results.append({
                'localidade_renaest': localidade,
                'uf': uf,
                'codigo_ibge': codigo,
                'municipio_ibge': nome,
                'match_type': 'exact',
                'match_score': score,
                'notes': ''
            })
            exact_count += 1
        else:
            # Match fuzzy - pega o melhor
            codigo, nome, uf_match, score, mtype = matches[0]
            results.append({
                'localidade_renaest': localidade,
                'uf': uf,
                'codigo_ibge': codigo,
                'municipio_ibge': nome,
                'match_type': 'fuzzy',
                'match_score': score,
                'notes': f'Top {len(matches)} matches; best: {nome} ({score})'
            })
            fuzzy_count += 1
    
    # Exporta CSV
    fieldnames = ['localidade_renaest', 'uf', 'codigo_ibge', 'municipio_ibge', 'match_type', 'match_score', 'notes']
    with open(args.output_csv, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)
    
    print(f"\nResultados:")
    print(f"  Match exato: {exact_count}")
    print(f"  Match fuzzy: {fuzzy_count}")
    print(f"  Sem match: {no_match_count}")
    print(f"  Total: {len(results)}")
    print(f"\nCSV salvo em: {args.output_csv}")
    
    # Estatísticas por UF
    uf_stats = {}
    for r in results:
        uf = r['uf']
        if uf not in uf_stats:
            uf_stats[uf] = {'total': 0, 'exact': 0, 'fuzzy': 0, 'none': 0}
        uf_stats[uf]['total'] += 1
        uf_stats[uf][r['match_type']] += 1
    
    print("\nPor UF:")
    for uf in sorted(uf_stats.keys()):
        s = uf_stats[uf]
        print(f"  {uf}: total={s['total']}, exact={s['exact']}, fuzzy={s['fuzzy']}, none={s['none']}")

if __name__ == '__main__':
    main()