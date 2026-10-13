#!/usr/bin/env python3
"""Converte o "Dicionário de Variáveis" oficial do INEP em artefatos do EduMaps.

Por que existe
--------------
O dicionário de dados do Censo Escolar (`clean.censo_data_dictionary`, #134)
nasceu de um seed estático com domínios escritos à mão — e a maioria estava
errada. A fonte de verdade é o anexo oficial do INEP que acompanha os
microdados ("ANEXO I - Dicionário de Dados", arquivo
`dicionário_dados_educação_básica.xlsx`). Este script lê esse xlsx **só com a
stdlib** (zipfile + xml) e gera:

1. o CSV canônico versionado `data_pipeline/dicionarios/censo_inep_variaveis.csv`
   (uma linha por aba × variável, todas as abas);
2. com `--sql ARQ`, o deploy Sqitch `censo_data_dictionary_inep`, com os dados
   das 4 abas mapeadas embutidos em `INSERT … VALUES` (o deploy não lê arquivo
   nenhum em tempo de execução, o que mantém o checksum do Sqitch estável).

Uso
---
    python3 tools/censo-dicionario/gerar.py <xlsx> [--saida data_pipeline/dicionarios]
    python3 tools/censo-dicionario/gerar.py <xlsx> --sql data_pipeline/deploy/censo_data_dictionary_inep.sql
    python3 tools/censo-dicionario/gerar.py --csv data_pipeline/dicionarios/censo_inep_variaveis.csv \\
            --sql data_pipeline/deploy/censo_data_dictionary_inep.sql

Sem xlsx, `--sql` lê o CSV versionado (assim o deploy pode ser regenerado sem
o anexo do INEP). A saída é determinística: mesma entrada, mesmos bytes.

Layout do xlsx (conferido em 2026-10-13, edição 2025)
-----------------------------------------------------
Cada aba tem uma legenda de cores nas linhas 1-3, o título, e o cabeçalho na
linha cuja coluna B é "Nome da Variável" (linha 7; linha 8 na aba de Curso
Técnico). A linha seguinte traz os anos com 2 dígitos sob as colunas de
coleta ("07".."25"; a aba de Gestor só tem "19".."25"), e a coluna de notas é
a que tem "Notas Importantes" no cabeçalho (Z na maioria, N no Gestor, Y no
Curso Técnico). Por isso o layout é **detectado**, nunca fixo por letra.

Colunas: A=N, B=variável, C=descrição, D=tipo (Num|Char), E=tamanho,
F=categorias ("código - rótulo" por linha; "   - Não aplicável…" sem código é o
significado de NULL), anos ('s'/'n'), notas.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import sys
import unicodedata
import zipfile
import xml.etree.ElementTree as ET

NS_MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
NS_REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
NS_PKG = 'http://schemas.openxmlformats.org/package/2006/relationships'

CSV_NOME = 'censo_inep_variaveis.csv'
CSV_COLUNAS = [
    'aba', 'variavel', 'descricao', 'tipo', 'tamanho', 'categorias',
    'nao_aplicavel', 'anos_coletados', 'ano_inicio', 'ano_fim', 'notas',
]

# Aba do xlsx → nome curto (coluna `aba` do CSV).
ABAS = {
    'tabela_de_escola': 'Escola',
    'tabela_de_matricula': 'Matricula',
    'tabela_de_docente': 'Docente',
    'tabela_de_turma': 'Turma',
    'tabela_de_gestor': 'Gestor',
    'tabela_curso_tecnico': 'CursoTecnico',
}

# Aba → tabela do EduMaps. Turma e Curso Técnico não têm tabela (ficam só no CSV).
MAPA_TABELAS = {
    'Escola': 'clean.censo_escolas',
    'Matricula': 'clean.censo_matriculas',
    'Docente': 'clean.censo_docentes',
    'Gestor': 'clean.censo_gestor',
}

FONTE_ARQUIVO = 'dicionário_dados_educação_básica.xlsx'
FONTE_DESCRICAO = ('INEP, Dicionário de Variáveis do Censo Escolar da Educação '
                   'Básica (Anexo I dos microdados 2025); Zotero 10296 / ICPJZK6R')
FONTE_URL = ('https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/'
             'microdados/censo-escolar')
FONTE_LICENCA = 'Material de referência público do INEP (dados abertos)'
CSV_VERSIONADO = 'data_pipeline/dicionarios/' + CSV_NOME

# Colunas do EduMaps com nome diferente da variável do INEP (o nome da
# migration foi encurtado ou tem erro de digitação; os CSVs do INEP e as
# fixtures trazem o nome oficial). (tabela, coluna no banco) → variável INEP.
# A linha do dicionário fica com o nome da coluna real e a nota registra o
# nome oficial.
APELIDOS = {
    ('clean.censo_matriculas', 'qt_mat_prof_fic_con'): 'qt_mat_prof_fic_conc',
    ('clean.censo_matriculas', 'qt_mat_prof_tec_con'): 'qt_mat_prof_tec_conc',
    ('clean.censo_docentes', 'qt_doc_prof_fic_con'): 'qt_doc_prof_fic_conc',
    ('clean.censo_docentes', 'qt_doc_prof_tec_con'): 'qt_doc_prof_tec_conc',
    ('clean.censo_gestor', 'qt_gest_bas_acesso_cargo_conca'): 'qt_gest_bas_acesso_cargo_conc',
}

# Códigos que existem nos microdados do INEP mas faltam no dicionário do INEP.
# Cada entrada foi medida nos dados reais (edumaps_dev, Censo 2025) e nas
# fixtures do CI; o CSV continua fiel ao xlsx e o complemento entra só no
# value_domain, com nota. (tabela, coluna) → {código: rótulo}.
_AMB = ('O INEP grava 9 nestas variáveis quando IN_EDUC_AMBIENTAL = 0 '
        '(medido: 88.321 escolas em 2025), mas o dicionário só lista 0/1.')
COMPLEMENTOS = {
    ('clean.censo_escolas', c): ({'9': 'Não se aplica (escola sem ações de educação ambiental)'}, _AMB)
    for c in ('in_educ_amb_conteudo', 'in_educ_amb_curricular', 'in_educ_amb_eixo',
              'in_educ_amb_eventos', 'in_educ_amb_projetos', 'in_educ_amb_nenhuma')
}

# Colunas criadas pelo EduMaps, com a explicação que vai para `notes`.
# Qualquer outra coluna real sem par no INEP recebe a nota genérica.
DERIVADAS = {
    'linha_id': 'Chave substituta do EduMaps: número da linha no arquivo de origem.',
    'geometry': 'Ponto (EPSG:4674) construído pelo EduMaps a partir de LATITUDE/LONGITUDE.',
    'cluster_id': 'Agrupamento calculado pela análise do EduMaps (edumapsr).',
    'nro_etapas': 'Contagem de etapas de ensino ofertadas, calculada pelo EduMaps.',
    'nro_participacoes_exame': 'Contagem de participações em exames, calculada pelo EduMaps.',
}
NOTA_DERIVADA = ('Coluna criada pelo EduMaps; sem correspondência no Dicionário de '
                 'Variáveis do INEP.')


# --------------------------------------------------------------------------
# Leitura do xlsx (stdlib)
# --------------------------------------------------------------------------

def _q(ns, tag):
    return '{%s}%s' % (ns, tag)


def _col_letras(ref):
    return re.match(r'[A-Z]+', ref).group()


def col_indice(letras):
    """'A' → 0, 'Z' → 25, 'AA' → 26."""
    n = 0
    for ch in letras:
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def _texto(el):
    return ''.join(t.text or '' for t in el.iter(_q(NS_MAIN, 't')))


def ler_xlsx(caminho):
    """Devolve [(nome_aba, {linha: {letra: valor}})] na ordem do workbook."""
    with zipfile.ZipFile(caminho) as z:
        nomes = set(z.namelist())
        compartilhadas = []
        if 'xl/sharedStrings.xml' in nomes:
            raiz = ET.fromstring(z.read('xl/sharedStrings.xml'))
            compartilhadas = [_texto(si) for si in raiz.findall(_q(NS_MAIN, 'si'))]
        rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
        alvo = {r.get('Id'): r.get('Target') for r in rels.findall(_q(NS_PKG, 'Relationship'))}
        wb = ET.fromstring(z.read('xl/workbook.xml'))
        abas = []
        for sh in wb.find(_q(NS_MAIN, 'sheets')).findall(_q(NS_MAIN, 'sheet')):
            destino = alvo[sh.get(_q(NS_REL, 'id'))].lstrip('/')
            if not destino.startswith('xl/'):
                destino = 'xl/' + destino
            abas.append((sh.get('name'), _ler_aba(z.read(destino), compartilhadas)))
        return abas


def _ler_aba(xml_bytes, compartilhadas):
    linhas = {}
    raiz = ET.fromstring(xml_bytes)
    for row in raiz.iter(_q(NS_MAIN, 'row')):
        celulas = {}
        for c in row.findall(_q(NS_MAIN, 'c')):
            t = c.get('t')
            v = c.find(_q(NS_MAIN, 'v'))
            if t == 's' and v is not None:
                val = compartilhadas[int(v.text)]
            elif t == 'inlineStr':
                val = _texto(c)
            elif v is not None:
                val = v.text
            else:
                continue
            if val is not None and val != '':
                celulas[_col_letras(c.get('r'))] = val
        linhas[int(row.get('r'))] = celulas
    return linhas


# --------------------------------------------------------------------------
# Parsers puros (testados em t/)
# --------------------------------------------------------------------------

def sem_acento(s):
    return ''.join(ch for ch in unicodedata.normalize('NFKD', s)
                   if not unicodedata.combining(ch))


def nome_aba(nome_xlsx):
    """'Tabela_de_Matrícula' → 'Matricula'; desconhecida → normalizada."""
    chave = re.sub(r'\s+', '', sem_acento(nome_xlsx)).lower()
    if chave in ABAS:
        return ABAS[chave]
    return re.sub(r'^tabela_(de_)?', '', chave).title().replace('_', '')


RE_CODIGO = re.compile(r'^\s*(\d+)\s*-\s*(.*?)\s*$')
RE_NA = re.compile(r'^\s*-\s*(.*?)\s*$')


def parse_categorias(texto, numerico=True):
    """Coluna F → (categorias, nao_aplicavel, texto_livre).

    - "1 - Federal"          → categorias['1'] = 'Federal'
    - "   - Não aplicável…"  → nao_aplicavel (significado de NULL)
    - linha sem código nem hífen logo após um item → continuação do item
    - linha sem código nem hífen sem item anterior → texto_livre
    Em variáveis numéricas o código é normalizado ('01' → '1'), que é como o
    valor aparece em `valor::text` no banco.
    """
    categorias = {}
    nao_aplicavel = []
    livre = []
    ultimo = None  # ('cod', código) | ('na', índice)
    if not texto:
        return {}, '', ''
    for bruta in texto.replace('\r\n', '\n').replace('\r', '\n').split('\n'):
        if not bruta.strip():
            continue
        m = RE_CODIGO.match(bruta)
        if m:
            cod = str(int(m.group(1))) if numerico else m.group(1)
            if cod not in categorias:
                categorias[cod] = m.group(2)
            ultimo = ('cod', cod)
            continue
        m = RE_NA.match(bruta)
        if m:
            nao_aplicavel.append(m.group(1))
            ultimo = ('na', len(nao_aplicavel) - 1)
            continue
        cont = bruta.strip()
        if ultimo is None:
            livre.append(cont)
        elif ultimo[0] == 'cod':
            categorias[ultimo[1]] = (categorias[ultimo[1]] + ' ' + cont).strip()
        else:
            nao_aplicavel[ultimo[1]] = (nao_aplicavel[ultimo[1]] + ' ' + cont).strip()
    limpa = lambda s: re.sub(r'\s+', ' ', s).strip()
    categorias = {k: limpa(v) for k, v in categorias.items()}
    return (categorias,
            '; '.join(limpa(x) for x in nao_aplicavel),
            ' '.join(limpa(x) for x in livre))


RE_CATEGORIA_NOTA = re.compile(r'categoria\s*"(\d+)\s*-\s*([^"\n]+?)\s*"', re.I)


def categorias_das_notas(notas, numerico=True):
    """Categorias citadas nas notas, ex.: 'Existe adicionalmente a categoria
    "9 - Não informado".' → {'9': 'Não informado'}. O INEP usa esse formato
    para códigos que valem só em parte da série (ex.: o 9 de 2019)."""
    extras = {}
    for m in RE_CATEGORIA_NOTA.finditer(notas or ''):
        cod = str(int(m.group(1))) if numerico else m.group(1)
        extras.setdefault(cod, re.sub(r'\s+', ' ', m.group(2)).strip())
    return extras


def faixas_anos(anos):
    """[2007, 2008, 2009, 2014] → '2007-2009,2014'."""
    anos = sorted(set(anos))
    if not anos:
        return ''
    partes = []
    ini = fim = anos[0]
    for a in anos[1:]:
        if a == fim + 1:
            fim = a
            continue
        partes.append(str(ini) if ini == fim else '%d-%d' % (ini, fim))
        ini = fim = a
    partes.append(str(ini) if ini == fim else '%d-%d' % (ini, fim))
    return ','.join(partes)


def _limpa_notas(s):
    if not s:
        return ''
    linhas = [re.sub(r'[ \t]+', ' ', ln).strip() for ln in s.replace('\r', '').split('\n')]
    return '\n'.join(ln for ln in linhas if ln)


def extrair_aba(nome_xlsx, linhas):
    """Linhas de uma aba → lista de dicts no formato do CSV."""
    aba = nome_aba(nome_xlsx)
    cab = next((n for n in sorted(linhas)
                if linhas[n].get('B', '').strip().lower().startswith('nome da vari')), None)
    if cab is None:
        raise ValueError('aba %r: cabeçalho "Nome da Variável" não encontrado' % nome_xlsx)
    col_notas = next((l for l, v in linhas[cab].items()
                      if sem_acento(v).strip().lower().startswith('notas')), None)
    anos_col = {}
    for letra, v in linhas.get(cab + 1, {}).items():
        if re.fullmatch(r'\s*\d{2}\s*', v):
            anos_col[letra] = 2000 + int(v)
        elif re.fullmatch(r'\s*\d{4}\s*', v):
            anos_col[letra] = int(v)
    if not anos_col:
        raise ValueError('aba %r: linha de anos não encontrada' % nome_xlsx)
    ultimo_ano = max(anos_col.values())
    saida = []
    vistos = set()
    for n in sorted(linhas):
        if n <= cab + 1:
            continue
        cel = linhas[n]
        var = cel.get('B', '').strip()
        if not var or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', var):
            continue
        var = var.lower()
        if var in vistos:
            raise ValueError('aba %r: variável repetida %s' % (nome_xlsx, var))
        vistos.add(var)
        tipo = cel.get('D', '').strip()
        numerico = tipo.lower().startswith('num')
        cats, na, livre = parse_categorias(cel.get('F', ''), numerico=numerico)
        anos = sorted(a for l, a in anos_col.items() if cel.get(l, '').strip().lower() == 's')
        notas = _limpa_notas(cel.get(col_notas, '')) if col_notas else ''
        for cod, rot in categorias_das_notas(notas, numerico).items():
            cats.setdefault(cod, rot)
        if livre:
            notas = ('Categoria (INEP): ' + livre + ('\n' + notas if notas else ''))
        tam = cel.get('E', '').strip()
        if re.fullmatch(r'\d+\.0', tam):
            tam = tam[:-2]
        saida.append({
            'aba': aba,
            'variavel': var,
            'descricao': re.sub(r'\s+', ' ', cel.get('C', '')).strip(),
            'tipo': tipo,
            'tamanho': tam,
            'categorias': json.dumps(cats, ensure_ascii=False) if cats else '',
            'nao_aplicavel': na,
            'anos_coletados': faixas_anos(anos),
            'ano_inicio': str(anos[0]) if anos else '',
            'ano_fim': '' if not anos or anos[-1] == ultimo_ano else str(anos[-1]),
            'notas': notas,
        })
    return saida


def extrair(caminho_xlsx):
    linhas = []
    for nome, dados in ler_xlsx(caminho_xlsx):
        linhas.extend(extrair_aba(nome, dados))
    return linhas


# --------------------------------------------------------------------------
# CSV
# --------------------------------------------------------------------------

def escrever_csv(linhas, destino):
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=CSV_COLUNAS, lineterminator='\n',
                       quoting=csv.QUOTE_MINIMAL)
    w.writeheader()
    for ln in linhas:
        w.writerow(ln)
    with open(destino, 'w', encoding='utf-8', newline='') as f:
        f.write(buf.getvalue())


def ler_csv(origem):
    with open(origem, encoding='utf-8', newline='') as f:
        return list(csv.DictReader(f))


# --------------------------------------------------------------------------
# SQL do deploy
# --------------------------------------------------------------------------

def ano_mudanca(notas, ano_inicio):
    """Ano da última mudança de nome/código/metodologia citada nas notas.

    Heurística conservadora sobre o texto do INEP:
      "A partir de 2019" / "Em 2023 foi…"   → esse ano
      "Entre 2007 e 2021" / "De 2012 a 2018" → ano seguinte ao fim do intervalo
    Só valem anos > ano_inicio e <= 2025. Sem menção → None.
    """
    if not notas:
        return None
    t = sem_acento(notas).lower()
    cands = []
    for m in re.finditer(r'(?:entre|de)\s+(\d{4})\s+(?:e|a)\s+(\d{4})', t):
        cands.append(int(m.group(2)) + 1)
    for m in re.finditer(r'(?:a partir de|em|desde)\s+(\d{4})', t):
        cands.append(int(m.group(1)))
    ini = int(ano_inicio) if ano_inicio else 0
    cands = [a for a in cands if ini < a <= 2025]
    return max(cands) if cands else None


def _lit(v):
    if v is None or v == '':
        return 'NULL'
    return "'" + str(v).replace("'", "''") + "'"


def dominio_sql(var, categorias_json, tipo, tamanho, tabela=None):
    """value_domain e nota extra de uma variável mapeada.

    Só tp_* e in_* são domínios fechados. Nas demais (qt_*, nu_cnpj_*), os
    códigos do INEP são sentinelas dentro de um valor aberto (88888 = valor
    extremo, 99999999999999 = sem declaração) e vão para a nota.
    """
    cats = json.loads(categorias_json) if categorias_json else {}
    fechado = var.startswith('tp_') or var.startswith('in_')
    extra, nota_extra = COMPLEMENTOS.get((tabela, var), ({}, None))
    if fechado and cats:
        for cod, rot in extra.items():
            cats.setdefault(cod, rot)
        if nota_extra:
            nota_extra = ('Complemento EduMaps ao domínio (código %s ausente do dicionário do INEP): %s'
                          % (', '.join(sorted(extra)), nota_extra))
        return json.dumps(cats, ensure_ascii=False, sort_keys=False), nota_extra
    if var.startswith('in_'):
        if tipo.lower().startswith('num') and tamanho == '1':
            return ('{"0": "Não", "1": "Sim"}',
                    'Domínio binário 0/1 inferido: o INEP define a variável como Num(1) sem categorias.')
        return None, 'Variável in_* sem categorias no INEP e fora do padrão Num(1); domínio não inferido.'
    if cats:
        return None, 'Valores especiais (INEP): ' + '; '.join('%s = %s' % kv for kv in cats.items())
    return None, None


def gerar_sql(linhas):
    """Deploy Sqitch da change censo_data_dictionary_inep."""
    valores = []
    por_var = {(MAPA_TABELAS.get(ln['aba']), ln['variavel']): ln for ln in linhas}
    itens = [(MAPA_TABELAS[ln['aba']], ln['variavel'], ln, None)
             for ln in linhas if ln['aba'] in MAPA_TABELAS]
    for (tabela, coluna), oficial in sorted(APELIDOS.items()):
        ln = por_var.get((tabela, oficial))
        if ln is None:
            # Sem a variável oficial a coluna cai em 'derivada' — avisa e segue.
            print('AVISO: apelido %s.%s → %s: variável ausente do INEP' % (tabela, coluna, oficial),
                  file=sys.stderr)
            continue
        itens.append((tabela, coluna, ln, oficial))
    for tabela, coluna, ln, oficial in itens:
        dom, nota_dom = dominio_sql(ln['variavel'], ln['categorias'], ln['tipo'], ln['tamanho'],
                                    tabela=tabela)
        partes = []
        if oficial:
            partes.append('Nome oficial no INEP: %s (a coluna do EduMaps tem nome diferente).'
                          % oficial.upper())
        if ln['notas']:
            partes.append(ln['notas'])
        if ln['nao_aplicavel']:
            partes.append('NULL = ' + ln['nao_aplicavel'])
        if nota_dom:
            partes.append(nota_dom)
        partes.append('Coletada (INEP): ' + (ln['anos_coletados'] or 'nunca'))
        mud = ano_mudanca(ln['notas'], ln['ano_inicio'])
        valores.append('  (%s, %s, %s, %s, %s, %s, %s, %s)' % (
            _lit(tabela), _lit(coluna), _lit(ln['descricao']),
            (_lit(dom) + '::jsonb') if dom else 'NULL::jsonb',
            ln['ano_inicio'] or 'NULL', ln['ano_fim'] or 'NULL',
            mud if mud else 'NULL',
            _lit('\n'.join(partes)),
        ))
    derivadas = ',\n'.join('  (%s, %s)' % (_lit(k), _lit(v)) for k, v in sorted(DERIVADAS.items()))
    return SQL_MODELO.format(
        valores=',\n'.join(valores),
        derivadas=derivadas,
        nota_derivada=_lit(NOTA_DERIVADA),
        fonte_arquivo=_lit(CSV_VERSIONADO),
        fonte_url=_lit(FONTE_URL),
        fonte_licenca=_lit(FONTE_LICENCA),
        fonte_descricao=FONTE_DESCRICAO,
        n=len(valores),
    )


SQL_MODELO = r"""-- Deploy edumaps:censo_data_dictionary_inep to pg
-- requires: censo_data_dictionary
--
-- GERADO por tools/censo-dicionario/gerar.py --sql — NÃO editar à mão.
-- Fonte: {fonte_descricao}.
-- Dados: {n} variáveis das abas Escola, Matrícula, Docente e Gestor
-- (data_pipeline/dicionarios/censo_inep_variaveis.csv).
--
-- O que faz (issue #134, docs/specs/2026-10-13-dicionario-censo-inep.md):
--   1. coluna `origem` ('inep' | 'derivada');
--   2. registra colunas reais das 4 tabelas ainda ausentes do dicionário;
--   3. atualiza descrição, domínio, anos e notas a partir do INEP;
--   4. marca como 'derivada' o que não existe no INEP;
--   5. cria clean.censo_dict_violacoes().

BEGIN;

ALTER TABLE clean.censo_data_dictionary
    ADD COLUMN origem text NOT NULL DEFAULT 'inep'
    CONSTRAINT censo_data_dictionary_origem_chk CHECK (origem IN ('inep', 'derivada'));

COMMENT ON COLUMN clean.censo_data_dictionary.origem IS
'inep = variável do Dicionário de Variáveis do INEP; derivada = coluna criada pelo EduMaps';

-- A PK inclui year_introduced, que deixa de ser 2025 e passa ao ano de início
-- do INEP. O UPDATE só é seguro com uma linha por (tabela, coluna).
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM clean.censo_data_dictionary
        GROUP BY table_name, column_name HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'censo_data_dictionary tem mais de uma linha por (tabela, coluna); revisar antes da carga INEP';
    END IF;
END $$;

-- Colunas reais das 4 tabelas que ainda não estão no dicionário (ex.: criadas
-- por changes posteriores a censo_data_dictionary).
INSERT INTO clean.censo_data_dictionary (table_name, column_name, data_type, year_introduced)
SELECT 'clean.' || c.table_name, c.column_name, c.data_type, 2025
FROM information_schema.columns c
WHERE c.table_schema = 'clean'
  AND c.table_name IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
  AND NOT EXISTS (
      SELECT 1 FROM clean.censo_data_dictionary d
      WHERE d.table_name = 'clean.' || c.table_name AND d.column_name = c.column_name
  );

CREATE TEMP TABLE censo_inep_carga (
    table_name      text NOT NULL,
    column_name     text NOT NULL,
    description     text,
    value_domain    jsonb,
    year_introduced smallint,
    year_deprecated smallint,
    year_changed    smallint,
    notes           text,
    PRIMARY KEY (table_name, column_name)
) ON COMMIT DROP;

INSERT INTO censo_inep_carga
    (table_name, column_name, description, value_domain,
     year_introduced, year_deprecated, year_changed, notes)
VALUES
{valores};

UPDATE clean.censo_data_dictionary d
SET description     = c.description,
    value_domain    = c.value_domain,
    year_introduced = coalesce(c.year_introduced, d.year_introduced),
    year_deprecated = c.year_deprecated,
    year_changed    = c.year_changed,
    notes           = c.notes,
    origem          = 'inep',
    source_file     = {fonte_arquivo},
    source_url      = {fonte_url},
    source_license  = {fonte_licenca},
    retrieved_at    = '2026-05-08T18:25:13Z',  -- anexo entrou no Zotero (10296)
    updated_at      = now()
FROM censo_inep_carga c
WHERE d.table_name = c.table_name
  AND d.column_name = c.column_name;

-- Sem correspondência no INEP: coluna do EduMaps.
UPDATE clean.censo_data_dictionary d
SET origem       = 'derivada',
    value_domain = NULL,
    notes        = coalesce(x.nota, {nota_derivada}),
    updated_at   = now()
FROM clean.censo_data_dictionary d2
LEFT JOIN (VALUES
{derivadas}
) AS x(coluna, nota) ON x.coluna = d2.column_name
WHERE d.table_name = d2.table_name
  AND d.column_name = d2.column_name
  AND d.year_introduced = d2.year_introduced
  AND d.table_name IN ('clean.censo_escolas', 'clean.censo_matriculas',
                       'clean.censo_docentes', 'clean.censo_gestor')
  AND NOT EXISTS (
      SELECT 1 FROM censo_inep_carga c
      WHERE c.table_name = d.table_name AND c.column_name = d.column_name
  );

-- -----------------------------------------------------------------
-- Violações do dicionário nas 4 tabelas do Censo
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION clean.censo_dict_violacoes()
RETURNS TABLE (tipo text, tabela text, coluna text, valor text, n bigint)
LANGUAGE plpgsql STABLE
SET search_path = pg_catalog, pg_temp
AS $fn$
DECLARE
    t      text;
    cols   text;
    alvo   regclass;
BEGIN
    -- 1) Coluna real sem linha no dicionário.
    RETURN QUERY
    SELECT 'coluna_sem_dicionario'::text, 'clean.' || cl.relname::text, a.attname::text,
           NULL::text, NULL::bigint
    FROM pg_attribute a
    JOIN pg_class cl ON cl.oid = a.attrelid
    JOIN pg_namespace ns ON ns.oid = cl.relnamespace
    WHERE ns.nspname = 'clean'
      AND cl.relname IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
      AND a.attnum > 0 AND NOT a.attisdropped
      AND NOT EXISTS (
          SELECT 1 FROM clean.censo_data_dictionary d
          WHERE d.table_name = 'clean.' || cl.relname AND d.column_name = a.attname
      )
    ORDER BY 2, 3;

    -- 2) Valores fora do domínio. Uma varredura por tabela: as colunas
    --    codificadas viram pares (coluna, valor::text) e só os distintos são
    --    comparados com o domínio. in_* sem domínio → {{0,1}}.
    FOREACH t IN ARRAY ARRAY['censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor'] LOOP
        alvo := to_regclass(format('clean.%I', t));
        CONTINUE WHEN alvo IS NULL;

        SELECT string_agg(format('(%L, x.%I::text)', a.attname, a.attname), ', ' ORDER BY a.attnum)
        INTO cols
        FROM pg_attribute a
        WHERE a.attrelid = alvo AND a.attnum > 0 AND NOT a.attisdropped
          AND (a.attname LIKE 'in\_%' OR EXISTS (
                SELECT 1 FROM clean.censo_data_dictionary d
                WHERE d.table_name = 'clean.' || t AND d.column_name = a.attname
                  AND d.value_domain IS NOT NULL));
        CONTINUE WHEN cols IS NULL;

        RETURN QUERY EXECUTE format($q$
            WITH valores AS (
                SELECT v.coluna, v.valor, count(*) AS n
                FROM %s x
                CROSS JOIN LATERAL (VALUES %s) AS v(coluna, valor)
                WHERE v.valor IS NOT NULL
                GROUP BY 1, 2
            ),
            dominio AS (
                SELECT DISTINCT ON (d.column_name) d.column_name, d.value_domain
                FROM clean.censo_data_dictionary d
                WHERE d.table_name = %L
                ORDER BY d.column_name, d.year_introduced DESC
            )
            SELECT CASE WHEN v.coluna LIKE 'in\_%%' THEN 'binaria_invalida'
                        ELSE 'codigo_fora_do_dominio' END,
                   %L, v.coluna, v.valor, v.n
            FROM valores v
            LEFT JOIN dominio dm ON dm.column_name = v.coluna
            WHERE CASE
                    WHEN dm.value_domain IS NOT NULL THEN NOT (dm.value_domain ? v.valor)
                    ELSE v.valor NOT IN ('0', '1')
                  END
            ORDER BY v.coluna, v.valor
        $q$, alvo, cols, 'clean.' || t, 'clean.' || t);
    END LOOP;
END
$fn$;

COMMENT ON FUNCTION clean.censo_dict_violacoes() IS
'Violações do dicionário nas tabelas clean.censo_{{escolas,matriculas,docentes,gestor}}:
coluna_sem_dicionario (coluna real ausente do dicionário), codigo_fora_do_dominio
(valor não nulo fora de value_domain) e binaria_invalida (in_* fora de {{0,1}} ou do
seu domínio). Vazia = dicionário coerente com os dados (#134).';

UPDATE clean.import_metadata
SET notes = 'Dicionário gerado do catálogo e atualizado pelo Dicionário de Variáveis do INEP (censo_data_dictionary_inep)'
WHERE table_name = 'clean.censo_data_dictionary';

COMMIT;
"""


# --------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('xlsx', nargs='?', help='dicionário do INEP (.xlsx)')
    ap.add_argument('--saida', default='data_pipeline/dicionarios',
                    help='diretório do CSV (padrão: %(default)s)')
    ap.add_argument('--csv', help='lê este CSV em vez do xlsx (só com --sql)')
    ap.add_argument('--sql', help='grava também o deploy Sqitch neste caminho')
    a = ap.parse_args(argv)

    if a.xlsx:
        linhas = extrair(a.xlsx)
        os.makedirs(a.saida, exist_ok=True)
        destino = os.path.join(a.saida, CSV_NOME)
        escrever_csv(linhas, destino)
        print('%s: %d variáveis' % (destino, len(linhas)), file=sys.stderr)
    elif a.csv and a.sql:
        linhas = ler_csv(a.csv)
    else:
        ap.error('informe o xlsx, ou --csv junto com --sql')

    if a.sql:
        with open(a.sql, 'w', encoding='utf-8', newline='') as f:
            f.write(gerar_sql(linhas))
        print('%s: deploy gerado' % a.sql, file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
