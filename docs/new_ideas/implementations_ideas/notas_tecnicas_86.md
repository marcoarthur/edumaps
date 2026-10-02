# Nota técnica 86 — Loader Transportes (RENAVAM + RENAEST), issue #169

**Data:** 2026-10-02
**Issue:** #169 (`feat(data): loader Transportes (RENAVAM + RENAEST)`)
**Âmbito:** `backend/lib/EduMaps/Ingestion/Job/Transportes.pm`,
`backend/t/05-tasks/transportes_loader.t`,
`docs/funcionalidades/plataforma/fontes-de-dados.md`

---

## 1. O que se fez

Substituiu-se o esqueleto de `Job::Transportes` (15 linhas, três comentários
`# ...`) por um loader completo, com contrato declarado, agregação explícita e
testes de regressão. Três tabelas que estavam vazias e sem carga real passaram a
ter dados:

| Tabela | Antes | Depois |
|---|---|---|
| `clean.renaest_localidade_municipio` | 5573 linhas, todas `match_type='exact'`, `validated_by='auto_seed'` (auto-junção do IBGE) | **5570** linhas de fonte real, `exact=5560`, `fuzzy=10`, `validated_by='fonte_renaest'` |
| `clean.renaest_sinistro` | 0 | **30 647** linhas (localidade/UF/dia) |
| `clean.renavam_frota_municipio` | 0 | **5 538** municípios, só `total_frota` |

---

## 2. O que foi medido antes de decidir

Nenhuma coluna foi preenchida com base no nome do campo. As três fontes foram
inspeccionadas com dados reais.

### 2.1 O dataset da migração não existe

`deploy/renavam_frota_municipio.sql` e o `COMMENT` da tabela apontam para
`dados.transportes.gov.br/dataset/frota-por-municipio`. Esse identificador
devolve **Not Found** no CKAN. O dataset que existe
(`registro-nacional-de-veiculos-automotores-renavam`, 156 recursos) publica
`UF;Município;Marca Modelo;Ano Fabricação;Qtd. Veículos` — **marca/modelo/ano**,
por **nome** de município, e **sem tipo de veículo**.

Logo, as dez colunas de tipo (`automoveis`, `caminhao`, `moto`, …) **não têm
fonte neste portal**. Decisão do developer: carregar só `total_frota` e deixar
os tipos a `NULL`.

### 2.2 O grão da tabela não é o grão da fonte

`clean.renaest_sinistro` tem `UNIQUE (localidade, uf, data_sinistro,
dt_snapshot)`. A chave **não** inclui o número do acidente, e a fonte tem uma
linha por acidente (verificado: `num_acidente` distinto em 98 411 linhas
amostradas).

Consequência que teria passado despercebida: carregar linha a linha com
`ON CONFLICT` faria o segundo acidente do dia **sobrescrever** o primeiro, e as
vítimas desapareceriam sem erro. O loader **agrega por localidade/UF/dia** e
soma. Isto está coberto por um subtest que carrega dois acidentes no mesmo dia
e exige que os mortos somem (1+2) em vez de o segundo apagar o primeiro.

### 2.3 O que a fonte dá e o que não dá

| CSV | Comprimido | Descomprimido | Serve para |
|---|---|---|---|
| `Acidentes` | 332 MB | 2,7 GB | mortos, veículos envolvidos |
| `Localidade` | 10 MB | 46 MB | nome da localidade + `codigo_ibge` |
| `TipoVeiculo` | 35 MB | 336 MB | (não usado) |
| `Vitimas` | 145 MB | 1,8 GB | gravidade das lesões |

`gravidade_lesao` (`LEVE`, `GRAVE`, `OBITO`, `SEM FERIMENTO`, `NAO INFORMADO`,
`DESCONHECIDO`) só existe em `Vitimas`. Decisão do developer: não processar os
1,8 GB; `feridos_graves`, `feridos_leves` e `ilesos` ficam **NULL**.

`qtde_feridosilesos` de `Acidentes` **não** foi posto em `ilesos`: a coluna
soma feridos **e** ilesos, e escrevê-la ali seria afirmar que ninguém ficou
ferido.

### 2.4 `localidade` não é o que o `COMMENT` dizia

`deploy/renaest_localidade_municipio.sql` documenta `localidade` como nome
("São Paulo", "Campinas"). O campo `chv_localidade` da fonte **não** é um nome:
é `<uf><codigo_ibge><yyyy><mm>` — uma chave **mensal** (559 700 linhas para
5 570 municípios). O nome é o campo `municipio` do CSV `Localidade`. A chave
passou a ser esse nome, que é o que a tabela promete e o que permite ligar
sinistros ao de-para.

---

## 3. Decisões de desenho

1. **Agregar em vez de duplicar.** O `UNIQUE` da tabela define o grão; o loader
   respeita-o em vez de o driblar.
2. **NULL explícito contra `DEFAULT 0`.** `feridos_graves`, `feridos_leves` e
   `ilesos` têm `DEFAULT 0`. Deixar o default trabalhar transforma "não
   avaliável" em "zero vítimas" — a lição escrita da #154. São inseridas a
   `NULL` explícito, e o `ON CONFLICT` volta a pôr a `NULL`.
3. **Sentinelas contadas, nunca herdadas.** A RENAEST publica
   `codigo_ibge = 0` (2 700 linhas) e a RENAVAM publica UFs "Sem Informação"
   (17 359 linhas), "Não Identificado" e "Não se Aplica". Um sentinela que
   chegasse à base seria criminalidade sem lugar nenhum — o defeito da #164.
4. **`validated_by` distingue origem.** O de-para passa a
   `validated_by='fonte_renaest'` (derivado da fonte, sem validação humana),
   em vez de `NULL` ou `auto_seed`. E a semente `auto_seed` — a auto-junção do
   IBGE que nunca viu RENAEST — é removida depois da carga, com a contagem
   registada. Foi removida exatamente 1 vez: 5 573 linhas.
5. **Contrato de colunas parcial.** Para o RENAEST exigem-se seis colunas
   específicas; uma coluna a mais não aborta, uma em falta sim. Um contrato
   exacto sobre um ficheiro de 2,7 GB seria brittle sem ganho.
6. **Relatório de órfãos.** 111 173 linhas de 22 690 877 (0,49%) caem em 33
   pares (UF, município) que a malha não reconhece. A contagem não é accionável;
   o relatório nomeia o par e diz quantas linhas perdeu.

---

## 4. Defeito encontrado de passagem

`Job::Base::log_info` interpolava `$self->{job_name}`. O `Mojo::Base` só preenche
os atributos por omissão quando o **acessor** é chamado, e `log_info` lia o hash
directly — o resultado era `[info] [] ...` em todos os jobs de ingestão, sem
nome de job. Corrigido para `$self->job_name`.

---

## 5. Estado final e custos

- Testes: `t/05-tasks/transportes_loader.t`, 10 subtestes, sem rede e sem base.
  `brazilcrime_loader.t` e `ibge_loader.t` continuam a passar.
- Idempotência verificada: re-correr o de-para e os sinistros manteve 5 570 e
  30 647 linhas.
- Custos de execução real: RENAVAM 22,7 M linhas em ~4 min; RENAEST
  `Acidentes` completo (2,7 GB) é o passo pesado do job mensal.
- **Não** foi carregado o `Acidentes` completo: a validação usou uma amostra de
  98 411 linhas das 4,4 M do ficheiro. O caminho de código é o mesmo; falta
  medir a carga inteira.
- `fuzzy_match_renaest.py` (que a #155 queria) continua por correr: com
  `codigo_ibge` na fonte, o cruzamento por nome deixou de ser necessário para
  esta fonte. A #155 continua aberta.

---

## 6. O que ficou por fazer

1. Carga completa de `renaest_sinistro` (4,4 M acidentes agregados).
2. `clean.analytics_mobilidade_escola` continua a depender de `antt_od_municipio`
   e `isocrona_escolar`, ambas vazias (#168) — esta carga não a desbloqueia.
3. Aproximar as 33 grafias divergentes (de-para secundário por semelhança) ou
   aceitar a perda e registá-la. Hoje estão registadas em
   `renavam_orfaos.csv`.
4. Avaliar se `tipo_sinistro` e `classificacao` justificam uma change que
  QUEBRE o `UNIQUE` actual e volte ao grão por acidente.