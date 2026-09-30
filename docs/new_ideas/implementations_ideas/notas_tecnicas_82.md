# Nota Técnica 82 — Fase 6: Mobilidade — Isocronas + ANTT OD + RENAVAM + Tráfego + VMDA + Recife (#130)

**Data**: 2026-09-30  
**PR**: #147 (merge commit `c404522`)  
**Branch**: `feat/data/fase6-mobilidade` → `main`  
**Commit**: `f74ba79`

---

## Contexto

Issue #130 (prioridade `[alta]`) — **Fecha a lacuna 5 (mobilidade)**. O diagnóstico correto: o problema nunca foi **cobertura**, foi **publicação**. Transporte escolar com chave de escola existe em **um único município verificado** (Recife).

---

## Entregas

| Migration | Tabela/View | Status | Descrição |
|-----------|-------------|--------|-----------|
| `isocrona_escolar` | `clean.isocrona_escolar` | ✅ Vazia (estrutura) | Isocronas OSRM/Valhalla auto-hospedados. Grade H3 resolução 10 (~1km). Tileset extraído uma vez, engine version + build date registrados. |
| `antt_od_municipio` | `clean.antt_od_municipio` | ✅ Vazia (estrutura) | MONITRIIP matriz OD município×município×mês (ônibus rodoviário intermunicipal). Supressão `count < 10` obrigatória. |
| `renavam_frota_municipio` | `clean.renavam_frota_municipio` | ✅ Vazia (estrutura) | Frota agregada por município/mês (domínio público, mensal desde mai/2013). |
| `antt_contagem_equipamento` | `clean.antt_contagem_equipamento` | ✅ Vazia (estrutura) | Tráfego em equipamentos de medição (rodovias concedidas). JOIN com `antt_trecho_geodados` para município. |
| `snv_trecho_vmda` | `clean.snv_trecho_vmda` | ✅ Vazia (estrutura) | DNIT/INDE SNV + VMDA — **MODELAGEM** (PNCT + pedágio + matriz OD PNT 2016/2017), **não medição**. **Decisão jurídica pendente**. |
| `recife_transporte_escolar` | `clean.recife_transporte_escolar` | ✅ Vazia (estrutura) | Transporte escolar Recife (CKAN ODbL). LEITURA PERMITIDA; materialização sob share-alike = decisão do jurídico. |

---

## Decisões Críticas

### 1. **OSRM/Valhalla: Auto-hospedado obrigatório**

As instâncias públicas (`router.project-osrm.org`, `valhalla1.openstreetmap.de`) são **servidores de demonstração sem SLA**. O tileset deve ser extraído **uma vez** (ex.: Geofabrik Brazil) e auto-hospedado em container. `engine_version` + `tileset_build_date` registrados para reprodutibilidade.

### 2. **Isocronas em grade 1km (H3 res 10), NUNCA por escola isolada**

Em cidade pequena, isocrona por escola é **reidentificável**. Agregação obrigatória em grade H3 resolução 10 (~1km). `engine_version` + `tileset_build_date` registrados para reprodutibilidade.

### 3. **ANTT OD: Supressão `count < 10` obrigatória; `tipo_gratuidade` excluído**

- Supressão `quantidade_bilhetes < 10` **antes** de qualquer agregação espacial.
- `tipo_gratuidade` é indutor de reidentificação quando cruzado com município de origem e data → **excluído da camada analítica**.

### 4. **ANTT acidentes sem município → JOIN OBRIGATÓRIO**

Chave bruta: `Concessionaria;Data;Km;Trecho` — **sem município**. JOIN **obrigatório** com `antt_trecho_geodados` (que tem `municipio` + `codigo_ibge` + geometria `LineString` SRID 4674).

### 5. **SNV/VMDA = MODELAGEM, não medição**

A camada VMDA é **estimada** a partir de PNCT + pedágios + matriz OD PNT 2016/2017. **NÃO é contagem real**. Boa variável comparativa entre trechos, **não substitui contagem real**.

**Decisão jurídica pendente**: INDE declara Public Domain, mas catálogo GeoNetwork traz texto contraditório ("o governo concedeu o direito exclusivo..."). Registrar contradição em ADR **antes** de materializar.

### 6. **Recife ODbL: leitura permitida; materialização = decisão jurídica**

CKAN Recife transporte escolar = ODbL share-alike. **Leitura permitida**; materialização sob share-alike = decisão do jurídico. Ficha = prova de viabilidade do indicador escolar. Agregar a **no mínimo zona OD** antes de armazenar.

### 6. **INPE Queimadas = redundante com MapBiomas Fogo**

MapBiomas Fogo (classe 6) já cobre com melhor granularidade (30m vs 1km) e metodologia documentada. **Não ingerir INPE Queimadas**.

---

## Allowlist Atualizada (Fase 6)

| Fonte | Endpoints Permitidos |
|-------|---------------------|
| **OSRM/Valhalla** | Auto-hospedado (sem HTTP endpoint) |
| **Overpass API** | `/api/interpreter` (POIs, vias, transporte público) |
| **ANTT OD** | `/dataset/monitriip-servico-regular` |
| **RENAVAM** | `/dataset/frota-por-municipio` |
| **ANTT Tráfego** | `/dataset/contagem-equipamentos` (KMZ → GPKG) |
| **INDE VMDA** | Geoftp malha rodoviária |
| **Recife CKAN** | Transporte escolar |

---

## Deploy Sqitch

```
Deploying changes to db:pg://devel@db/edumaps_dev
  + isocrona_escolar ........... ok
  + antt_od_municipio .......... ok
  + renavam_frota_municipio .... ok
  + antt_contagem_equipamento .. ok
  + snv_trecho_vmda ............ ok
  + recife_transporte_escolar .. ok

Verifying db:pg://devel@db/edumaps_dev
  * isocrona_escolar ................ ok
  * antt_od_municipio .............. ok
  * renavam_frota_municipio ........ ok
  * antt_contagem_equipamento ...... ok
  * snv_trecho_vmda ................ ok
  * recife_transporte_escolar ...... ok
```

---

## Dependências Desbloqueadas

| Issue | Descrição | Status |
|-------|-----------|--------|
| **#131** | Overpass/OSM viés de cobertura | ✅ Desbloqueada |
| **#132** | e-SIC INEP/MEC/FNDE | ✅ Desbloqueada |

---

## Próximos Passos

1. **Jobs de ingestão** (R/Perl) para popular as 6 tabelas via allowlist com retry/backoff.
2. **#131 (Overpass/OSM viés)**: implementar `iv_mobilidade_completude_malha` publicado junto de todo indicador OSM.
3. **#132 (e-SIC)**: INEP (licença Censo Escolar), MEC/NIC.br (Medidor Educação Conectada), FNDE (PNATE/Proinfância/PNATE).
4. **De-para RENAEST localidade → município**: construir e versionar.
5. **View analítica `analytics.mobilidade_escola`**: cruzar isocronas + ANTT OD + RENAVAM frota + sinistros RENAEST + VMDA + Recife → `analytics.mobilidade_escola`.

---

## Lições Aprendidas

1. **Auto-hospedar é a única opção viável** para roteamento/isocronas em produção (SLA zero em instâncias públicas).
2. **Grade > escola isolada**: isocrona por escola em cidade pequena = reidentificação. Grade H3 res 10 (~1km) é o equilíbrio certo.
3. **Supressão antes de agregar**: ANTT OD supressão `count < 10` **antes** de qualquer agregação espacial.
4. **Modelagem ≠ medição**: SNV/VMDA é modelagem baseada em OD 2016/2017, não substitui contagem real.
8. **Licença contraditória = ADR obrigatório**: INDE contraditório → ADR antes de materializar.
9. **Recife ODbL = prova de viabilidade**: não é para ingerir como está, é para provar que o indicador escolar é possível.