#!/usr/bin/env python3
"""Gera os fixtures de CI do EduMaps a partir dos datasets reais.

Por que existe
--------------
As 13 migrations de dados do Sqitch leem arquivos de `/data/` via `COPY` (e dois
via OGR FDW). Os arquivos reais somam ~765 MB, inviável num job de CI. Este
script extrai um subconjunto mínimo mas *real*: o mesmo header, verbatim, e
linhas reais do IBGE/INEP. Como cada `COPY` declara a lista explícita de
colunas, nenhum ajuste nas migrations é necessário — o fixture entra por baixo
delas e o `sqitch deploy` produz o mesmo schema dos 64 migrations.

O que o fixture contém
----------------------
18 municípios (as 5 regiões geográficas, mais os códigos que a suíte cita) e
~180 escolas (182 linhas em `clean.censo_escolas`). A seleção de escolas é
guiada por três critérios, nesta ordem:

1. `INEPS_EXIGIDOS` — escolas nomeadas literalmente por testes, com o motivo.
2. Diversidade de `TP_DEPENDENCIA` (1 privada, 2 estadual, 3 municipal,
   4 federal). A maioria dos testes quer uma escola municipal; `SchoolNetwork.t`
   quer uma rede municipal *em São Paulo*.
3. Maior cobertura entre os 10 arquivos por escola (escolher uma escola que
   não tem linha no IDEB deixaria `clean.ideb_notas_escolas` vazia).

Uso
---
    python3 db/fixtures/gerar.py --entrada /caminho/para/edumaps_data

O shapefile de municípios é gerado à parte por `gerar_zip_municipios.sh` (que
precisa de gdal-bin); este script só avisa se o ZIP estiver desatualizado.

Saída
-----
    db/fixtures/*.csv              os 12 arquivos lidos por COPY
    db/fixtures/fix-manifest.json  o que cada fixture contém (INEPs, municípios)

Este arquivo NÃO roda no CI: o CI usa os arquivos já versionados. Ele existe
para regenerar os fixtures quando os headers do IBGE mudarem.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from collections import defaultdict

# (código IBGE, nome, limite de escolas — None = todas)
#
# Limites: None onde o município é pequeno e caber inteiro (o clustering
# de t/04-api/school/clustering.t usa 2104073, que tem 8 escolas na fonte); nos
# grandes (São Paulo tem 7905) corta-se para manter o fixture pequeno, sempre
# incluindo primeiro as escolas exigidas e as municipais.
MUNICIPIOS = [
    ('1100015', "Alta Floresta D'Oeste", None),  # RO, região 1
    ('1100205', 'Porto Velho', 8),                # RO, região 1 — t/01-app/basic.t
    ('1200401', 'Rio Branco', 8),                 # AC, região 1 — t/01-app/basic.t
    ('1302603', 'Manaus', 8),                     # AM, região 1 — t/01-app/basic.t
    ('1501402', 'Belém', 8),                      # PA, região 1 — t/01-app/basic.t
    ('2104073', 'Feira Nova do Maranhão', None),  # MA, região 2 — clustering.t
    ('2111300', 'São Luís', 8),                   # MA, região 2
    ('2302701', 'Campos Sales', 8),               # CE, região 2 — t/04-api/municipio.t
    ('3106200', 'Belo Horizonte', 8),             # MG, região 3 — t/02-models/school/grades.t
    ('3509502', 'Campinas', 8),                   # SP, região 3 — t/03-plugins/analytics.t
    ('3550308', 'São Paulo', 8),                  # SP, região 3 — citado em 10 testes
    ('3553807', 'Taquarituba', None),             # SP, região 3 — t/04-api/municipio.t
    ('3554102', 'Taubaté', 8),                    # SP, região 3 — t/05-tasks/clustering2.t
    ('3555406', 'Ubatuba', 12),                   # SP, região 3 — t/02-models/school/geo.t
    ('4106902', 'Curitiba', 8),                   # PR, região 4
    ('4316808', 'Santa Cruz do Sul', 4),          # RS, região 4 — cache_school_search.t
    ('4316907', 'Santa Maria', 8),                # RS, região 4 — t/04-api/search-analytic.t
    ('5107040', 'Primavera do Leste', 8),         # MT, região 5 — t/02-models/city/similiraty.t
]

# Escolas citadas literalmente pela suíte. Todas entram no fixture mesmo que o
# limite do município já tenha sido atingido, porque o teste depende delas.
INEPS_EXIGIDOS = {
    '11000040': 't/04-api/gestor/painel.t e t/04-api/gestor/similares.t',
    '23027010': 't/04-api/municipio.t',
    '33064164': 't/02-models/school/grades.t',
    '33069395': 't/02-models/school/grades.t',
    # As coordenadas de t/02-models/school/geo.t (-23.54271,-45.231964) são as
    # desta escola, arredondadas: é a única que satisfaz a busca num raio de 5 km.
    '35007656': 't/02-models/school/geo.t (coordenadas exatas da busca por proximidade)',
    '35011162': 't/02-models/school/profile.t',
    # t/03-plugins/middlewares/cache_school_search.t consulta q=santuario e
    # espera X-Cache: HIT na 2a requisicao. Com resultado vazio o middleware nao
    # cacheia, entao a escola precisa existir: 'EMEF SANTUARIO' e a unica de
    # Santa Cruz do Sul.
    '43172210': 't/03-plugins/middlewares/cache_school_search.t (nome "EMEF SANTUARIO")',
}

#(fontes chaveadas por escola): (arquivo, separador, coluna)
FONTES_ESCOLA = [
    ('Tabela_Escolas.csv', ';', 'CO_ENTIDADE'),
    ('Tabela_Matricula_2025.csv', ';', 'CO_ENTIDADE'),
    ('Tabela_Docente_2025.csv', ';', 'CO_ENTIDADE'),
    ('Tabela_Gestor_Escolar_2025.csv', ';', 'CO_ENTIDADE'),
    ('escolas.csv', ',', 'Código INEP'),
    ('inep.csv', ',', 'ID_ESCOLA'),
    ('divulgacao_anos_finais_escolas_2023.csv', ',', 'ID_ESCOLA'),
    ('divulgacao_anos_iniciais_escolas_2023.csv', ',', 'ID_ESCOLA'),
    ('divulgacao_ensino_medio_escolas_2023.csv', ',', 'ID_ESCOLA'),
    ('inse_2023.csv', ';', 'ID_ESCOLA'),
]


def _municipio_de_pop_2025(linha: dict) -> bool:
    """pop_2025_mun não tem o código IBGE de 7 dígitos montado: vem 'COD. UF'
    (2 dígitos) e 'COD. MUNIC' (5 dígitos) em colunas separadas — 11 + 00015."""
    return ((linha.get('COD. UF') or '') + (linha.get('COD. MUNIC') or '')).strip() \
        in MUNIC_CODES


def _municipio_direto(chave: str):
    def pred(linha: dict) -> bool:
        return (linha.get(chave) or '').strip() in MUNIC_CODES
    return pred


# fontes chaveadas por município: (arquivo, separador, predicado sobre a linha)
FONTES_MUNICIPIO = [
    ('pop_2025_mun.csv', ',', _municipio_de_pop_2025),
    # populacao_faixas_etarias traz o código IBGE de 7 dígitos em 'Cód.'.
    ('populacao_faixas_etarias.csv', ',', _municipio_direto('Cód.')),
]

MUNIC_CODES = {c for c, _, _ in MUNICIPIOS}
NOME_MUNIC = {c: n for c, n, _ in MUNICIPIOS}
LIMITE = {c: l for c, _, l in MUNICIPIOS}


def log(msg: str) -> None:
    print(msg, flush=True)


def abrir(entrada: str, nome: str, sep: str):
    """Abre um CSV do dataset real com utf-8-sig (o BOM é frequente)."""
    caminho = os.path.join(entrada, nome)
    if not os.path.exists(caminho):
        sys.exit(f'ERRO: dataset ausente: {caminho}')
    return open(caminho, encoding='utf-8-sig', errors='replace', newline='')


def escolher_escolas(entrada: str) -> dict:
    """Escolhe as escolas do fixture, município a município.

    Determinístico: desempates resolvem pelo INEP, então o resultado não depende
    da ordem das linhas do arquivo.
    """
    log('  · mapeando presença por escola nos 10 arquivos...')
    cobertura: dict[str, set] = defaultdict(set)
    municipio_de: dict[str, str] = {}
    dependencia_de: dict[str, str] = {}
    nome_de: dict[str, str] = {}

    # Tabela_Escolas primeiro: é ela que define quais escolas existem e de que
    # município são.
    with abrir(entrada, 'Tabela_Escolas.csv', ';') as fh:
        for linha in csv.DictReader(fh, delimiter=';'):
            mun = (linha.get('CO_MUNICIPIO') or '').strip()
            if mun not in MUNIC_CODES:
                continue
            inep = (linha.get('CO_ENTIDADE') or '').strip()
            if not inep:
                continue
            municipio_de[inep] = mun
            dependencia_de[inep] = (linha.get('TP_DEPENDENCIA') or '').strip()
            nome_de[inep] = (linha.get('NO_ENTIDADE') or '').strip()
            cobertura[inep].add('Tabela_Escolas.csv')

    for nome, sep, coluna in FONTES_ESCOLA:
        if nome == 'Tabela_Escolas.csv':
            continue
        with abrir(entrada, nome, sep) as fh:
            for linha in csv.DictReader(fh, delimiter=sep):
                inep = (linha.get(coluna) or '').strip()
                if inep in municipio_de:
                    cobertura[inep].add(nome)

    por_mun: dict[str, list] = defaultdict(list)
    for inep, mun in municipio_de.items():
        por_mun[mun].append(inep)

    escolhidas: list[str] = []
    for codigo, nome_mun, _ in MUNICIPIOS:
        limite = LIMITE[codigo]
        candidatas = sorted(por_mun.get(codigo, []),
                            key=lambda i: (-len(cobertura[i]), i))

        do_municipio = [i for i in escolhidas if municipio_de[i] == codigo]

        # 1. escolas exigidas por testes
        for inep, motivo in sorted(INEPS_EXIGIDOS.items()):
            if municipio_de.get(inep) != codigo:
                continue
            if inep not in do_municipio:
                do_municipio.append(inep)
                log(f'    · {codigo} {nome_mun}: exige {inep} ({motivo})')

        # 2. uma escola de cada TP_DEPENDENCIA disponível no município, na
        #    ordem 3 (municipal), 1 (privada), 4 (federal), 2 (estadual).
        #    `SchoolNetwork.t` e `t/04-api/network/summary.t` exigem as quatro
        #    redes em São Paulo; `rank.t` compara a mesma escola entre redes.
        #    A municipal vem primeiro porque é a que a maioria dos testes usa.
        #    O `last` é essencial: sem ele a primeira dep varre todas as
        #    escolas daquela dep e consome o limite inteiro.
        if limite is None:
            alvo = len(candidatas)
        else:
            alvo = limite
        for dep in ('3', '1', '4', '2'):
            for inep in candidatas:
                if len(do_municipio) >= alvo:
                    break
                if dependencia_de[inep] == dep and inep not in do_municipio:
                    do_municipio.append(inep)
                    break
        # 3. completa por cobertura
        for inep in candidatas:
            if len(do_municipio) >= alvo:
                break
            if inep not in do_municipio:
                do_municipio.append(inep)

        if not do_municipio:
            log(f'    AVISO {codigo} {nome_mun}: nenhuma escola na fonte')
        escolhidas.extend(sorted(set(do_municipio)))

    faltando = [i for i in INEPS_EXIGIDOS if i not in escolhidas]
    if faltando:
        log(f'  AVISO: escolas exigidas ausentes da fonte: {faltando}')

    return {
        'ineps': sorted(set(escolhidas)),
        'municipio_de': municipio_de,
        'dependencia_de': dependencia_de,
        'nome_de': nome_de,
        'cobertura': cobertura,
    }


def escrever(entrada: str, saida: str, nome: str, sep: str, manter) -> int:
    """Escreve header verbatim + as linhas que `manter` aceitar.

    `manter` recebe a linha como dicionário, para que a predicação possa
    combinar mais de uma coluna (ver _municipio_de_pop_2025).
    """
    destino = os.path.join(saida, nome)
    n = 0
    with abrir(entrada, nome, sep) as fh:
        leitor = csv.DictReader(fh, delimiter=sep)
        campo = leitor.fieldnames
        tmp = destino + '.tmp'
        with open(tmp, 'w', encoding='utf-8', newline='') as out:
            # csv.QUOTE_MINIMAL é o padrão do Postgres em CSV e do Python; o
            # header real sai idêntico ao original byte a byte.
            w = csv.DictWriter(out, fieldnames=campo, delimiter=sep,
                               lineterminator='\n')
            w.writeheader()
            for linha in leitor:
                if manter(linha):
                    w.writerow(linha)
                    n += 1
    os.replace(tmp, destino)
    return n


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--entrada', default='/home/itaipu/Data/edumaps_data',
                    help='diretório com os datasets reais')
    ap.add_argument('--saida', default=os.path.dirname(os.path.abspath(__file__)),
                    help='diretório de destino dos fixtures')
    args = ap.parse_args()

    os.makedirs(args.saida, exist_ok=True)
    log(f'entrada: {args.entrada}\nsaida:  {args.saida}')

    log('\n[1/2] escolhendo escolas...')
    sel = escolher_escolas(args.entrada)
    ineps = set(sel['ineps'])
    por_mun = defaultdict(int)
    for i in sel['ineps']:
        por_mun[sel['municipio_de'][i]] += 1
    log(f'  · {len(ineps)} escolas em {len(por_mun)} municípios')
    for codigo, nome, _ in MUNICIPIOS:
        log(f"    {codigo}  {nome:<26} {por_mun.get(codigo, 0):>3} escola(s)")

    log('\n[2/2] escrevendo fixtures...')
    manifesto = {'municipios': {c: n for c, n, _ in MUNICIPIOS},
                 'escolas': [], 'arquivos': {}}

    for nome, sep, coluna in FONTES_ESCOLA:
        n = escrever(args.entrada, args.saida, nome, sep,
                     lambda l, c=coluna: (l.get(c) or '').strip() in ineps)
        manifesto['arquivos'][nome] = n
        log(f'  {n:>5} linhas  {nome}')

    for nome, sep, pred in FONTES_MUNICIPIO:
        n = escrever(args.entrada, args.saida, nome, sep, pred)
        manifesto['arquivos'][nome] = n
        log(f'  {n:>5} linhas  {nome}')

    for i in sel['ineps']:
        manifesto['escolas'].append({
            'inep': i,
            'municipio': sel['municipio_de'][i],
            'nome_municipio': NOME_MUNIC[sel['municipio_de'][i]],
            'nome': sel['nome_de'][i],
            'tp_dependencia': sel['dependencia_de'][i],
            'exigida_por': INEPS_EXIGIDOS.get(i),
            'fontes': sorted(sel['cobertura'][i]),
        })

    with open(os.path.join(args.saida, 'fix-manifest.json'), 'w',
              encoding='utf-8') as fh:
        json.dump(manifesto, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    log('\nfix-manifest.json escrito.')

    zip_path = os.path.join(args.saida, 'BR_Municipios_2024.zip')
    if not os.path.exists(zip_path):
        log('AVISO: BR_Municipios_2024.zip ausente — rode gerar_zip_municipios.sh')


if __name__ == '__main__':
    main()
