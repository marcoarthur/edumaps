#!/usr/bin/env python3
"""Extração de isóronas escolares — piloto da #278 (bloco C do IVET).

Para cada escola, pede ao Valhalla auto-hospedado duas isóronas (a decisão
de 2026-10-15: a pé 15 min + transporte 45 min), converte o polígono em
células H3 e arealiza a população do Censo 2022 sobre cada célula. Sai um
CSV no formato de clean.isocrona_escolar.

Resolução por horizonte (medida com a sonda em 3 escolas de ES, 2026-10-19):
  - 15 min a pé (~2 km²)  -> H3 r9  (~0,105 km²): 18-25 células/escola
  - 45 min carro (~400-1800 km²) -> H3 r7 (~5,16 km²): 76-313 células/escola
A coluna resolucao_h3 carrega a escolha: o comentário do schema dizia
"r10 ≈ 1 km", mas r10 tem ~15 ha — a intenção documentada é grade de ~1 km.

Entradas:
  --escolas  CSV co_entidade,codigo_ibge,lon,lat   (universo do IVET)
  --setores  CSV codigo_setor,pop_total,wkb_hex     (Censo 2022, SRID 4326)
Saída:
  --saida    CSV co_entidade,codigo_ibge,tempo_minutos,grid_id,
             resolucao_h3,populacao_grade

Regra #154: escola sem isórona (fora da rede) não vira linha; célula sem
setor intersectado fica com população NULL, nunca 0.
"""
from __future__ import annotations

import argparse
import csv
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import h3
import requests
from shapely import STRtree
from shapely.wkb import loads as wkb_loads
from shapely.geometry import Polygon

# Setores censitários grandes passam de 131 KB em WKB hex — o limite padrão do
# módulo csv derruba a leitura.
csv.field_size_limit(sys.maxsize)

# (costing, tempo_minutos, resolução H3) — a ordem importa: a 1ª é o componente
HORIZONTES = [("pedestrian", 15, 9), ("auto", 45, 7)]

TENTATIVAS = 4


def isochrone(base: str, lat: float, lon: float, costing: str, tempo: int):
    """Devolve os anéis (listas de [lon, lat]) da isócrona, ou None se falhar."""
    corpo = {
        "locations": [{"lat": lat, "lon": lon}],
        "costing": costing,
        "contours": [{"time": tempo}],
        "polygons": True,
        "generalize": 0,
    }
    for tentativa in range(TENTATIVAS):
        try:
            r = requests.post(f"{base}/isochrone", json=corpo, timeout=90)
            if r.status_code == 400:
                return None  # ponto sem rede no alcance: sem isórona, sem linha
            r.raise_for_status()
            aneis = []
            for f in r.json().get("features", []):
                g = f["geometry"]
                if g["type"] == "Polygon":
                    aneis.append(g["coordinates"][0])
                elif g["type"] == "MultiPolygon":
                    aneis.extend(p[0] for p in g["coordinates"])
            return aneis
        except requests.RequestException:
            if tentativa == TENTATIVAS - 1:
                raise
            time.sleep(2 ** tentativa)
    return None


def celulas_h3(aneis, res: int) -> set[str]:
    cells: set[str] = set()
    for anel in aneis:
        latlngs = [(lat, lon) for lon, lat in anel]
        cells |= set(h3.polygon_to_cells(h3.LatLngPoly(latlngs), res))
    return cells


def ler_setores(caminho: str):
    """Lê codigo_setor,pop_total,wkb_hex e devolve (árvore STRtree, lista)."""
    geoms, pops, codigos = [], [], []
    with open(caminho, newline="") as fh:
        for row in csv.DictReader(fh):
            pop = row["pop_total"]
            if pop in ("", None):
                continue
            geoms.append(wkb_loads(bytes.fromhex(row["wkb"])))
            pops.append(int(pop))
            codigos.append(row["codigo_setor"])
    return STRtree(geoms), geoms, pops


def populacao_celula(poly: Polygon, tree, geoms, pops) -> int | None:
    """População da célula = Σ setores ponderados pela área da interseção."""
    idxs = tree.query(poly, predicate="intersects")
    if len(idxs) == 0:
        return None
    total = 0.0
    for i in idxs:
        sec = geoms[i]
        inter = poly.intersection(sec)
        if inter.is_empty:
            continue
        razao = inter.area / sec.area
        total += pops[i] * razao
    return int(round(total))


def processar_escola(base, escola, tree, geoms, pops):
    co, codigo_ibge, lon, lat = escola
    linhas = []
    for costing, tempo, res in HORIZONTES:
        aneis = isochrone(base, float(lat), float(lon), costing, tempo)
        if not aneis:
            continue
        for cell in celulas_h3(aneis, res):
            poly = h3.cell_to_boundary(cell)  # ((lat,lon), ...)
            shp = Polygon([(lon_, lat_) for lat_, lon_ in poly])
            pop = populacao_celula(shp, tree, geoms, pops)
            linhas.append((co, codigo_ibge, tempo, cell, res, pop))
    return linhas


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--escolas", required=True)
    ap.add_argument("--setores", required=True)
    ap.add_argument("--saida", required=True)
    ap.add_argument("--valhalla", default="http://localhost:8002")
    ap.add_argument("--threads", type=int, default=8)
    args = ap.parse_args()

    with open(args.escolas, newline="") as fh:
        escolas = [tuple(r) for r in csv.reader(fh) if r and not r[0].startswith("co_entidade")]
    print(f"escolas: {len(escolas)}", flush=True)

    tree, geoms, pops = ler_setores(args.setores)
    print(f"setores censitários: {len(geoms)}", flush=True)

    t0 = time.time()
    cont_sem_isocrona = 0
    with open(args.saida, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["co_entidade", "codigo_ibge", "tempo_minutos", "grid_id",
                    "resolucao_h3", "populacao_grade"])
        with ThreadPoolExecutor(max_workers=args.threads) as pool:
            futuros = [pool.submit(processar_escola, args.valhalla, e, tree, geoms, pops)
                       for e in escolas]
            for i, fut in enumerate(futuros, 1):
                linhas = fut.result()
                if not linhas:
                    cont_sem_isocrona += 1
                for l in linhas:
                    w.writerow(l)
                if i % 250 == 0:
                    print(f"  {i}/{len(escolas)} escolas "
                          f"({time.time() - t0:.0f}s, sem isórona: {cont_sem_isocrona})",
                          flush=True)
    print(f"pronto: {len(escolas)} escolas em {time.time() - t0:.0f}s; "
          f"sem isórona: {cont_sem_isocrona} (#154: não viram linha)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
