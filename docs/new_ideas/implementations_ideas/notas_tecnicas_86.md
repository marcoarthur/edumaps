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

### 4.1 `Job::Base::log_info` sem nome de job

`Job::Base::log_info` interpolava `$self->{job_name}`. O `Mojo::Base` só preenche
os atributos por omissão quando o **acessor** é chamado, e `log_info` lia o hash
directly — o resultado era `[info] [] ...` em todos os jobs de ingestão, sem
nome de job. Corrigido para `$self->job_name`.

### 4.2 A cadeia de dependências do deploy estava partida em três pontos

O mais importante deste ciclo **não** foi o loader. Foi o que se descobriu ao
fazer o deploy e tentar correr o que se tinha validado localmente.

O `perl -c` no `backend.edumaps` morreu em
`Can't locate Text/CSV.pm in @INC`. A causa tinha três elos:

1. **`cpanfile` declarava só `Text::CSV_XS`.** São **distribuições distintas**:
   `Text::CSV_XS` instala `Text/CSV_XS.pm`. Sete módulos fazem
   `use Text::CSV` (`Ingestion/Job/{Base,ANTT,BrazilCrime,IBGE,Transportes}`,
   `Ingestion/Jobs`, `Roles/DB/Formats`) — e nenhum carregava.
2. **O deploy sobrescrevia o `cpanfile` versionado.** A task fazia
   `my $has_cpan = run qq{test -e cpanfile}`. O `run` devolve a **saída** do
   comando, e `test -e` não escreve nada quando o ficheiro existe — a variável
   ficava sempre vazia, o `unless` era sempre verdadeiro, e o "TEMPORARY HACK"
   copiava por cima o artefacto gerado pelo Dist::Zilla em build de imagem
   (Abr/2024). Uma correcção ao `cpanfile` **nunca** chegava ao
   `carton install`, que respondia `Complete!` sem instalar nada.
3. **Um segundo furo escondido atrás do primeiro.** `Ingestion/Jobs.pm` faz
   `use DateTime::Format::ISO8601`, declarado nem no `cpanfile` nem no
   `dist.ini`. Não foi apanhado pelo `AutoPrereqs` porque `Jobs.pm` não é
   carregado pelo serviço web. Ficava tapado porque o `require` de `Text::CSV`
   morria logo no topo do ficheiro.

Correção: `cpanfile` declara as duas; a task usa
`run qq{test -e cpanfile && echo yes}`. **Medido antes de mexer:** o
`cpanfile` versionado é um **superconjunto** do gerado (78 vs 66 módulos, zero
"só no gerado"), por isso respeitá-lo não perde dependência nenhuma — ganha as
12 que só ele declara.

Uma primeira tentativa de correção foi **errada** e vale registada: trocar o
`run` por `-e $cpanfile` no script Rex. O `-e` olha para o filesystem **local**,
onde `/opt/edumaps` não existe, e o hack voltou a correr. Só quando o `carton
install` passou a demorar 11 minutos em vez de segundos é que ficou claro que
passou a instalar alguma coisa.

**Consequência honesta:** os loaders dos PRs #173 (BrazilCrime) e #175 (IBGE)
foram validados com o Perl do perlbrew local, onde estas dependências
existem, e **nunca carregaram no ambiente deployado**. A validação local não
fez o que se pensava que fez.

### 4.3 Inventário das dependências (em vez de as descobrir uma a uma)

Depois de dois furos seguidos, o terceiro deploy foi feito contra um gate em vez
de contra a boa-fé. Duas passagens no host:

- **91 módulos** referenciados por `use`/`require` em `lib/` + `script/`,
  testados **um processo por módulo** (um `require $var` dentro de `eval` dá
  falsos negativos em runtime — foi o que produziu uma lista de 91 falhas,
  incluindo `Carp`, o que é absurdo e o sinal de que o *check* estava errado).
  Resultado: 89 resolvem, 1 falso positivo (`Minion::Task::Generator` é
  vendorizado em `lib/Minion/Task/Generator.pm`), 1 genuíno
  (`DateTime::Format::ISO8601`).
- **`perl -c` de todos os 234 módulos** de `lib/` no `carton` do host:
  **233 compilam**. O único que falha é
  `Model/Rank/SchoolDerived.pm`, que faz `use
  EduMaps::Model::Indicator::School::IdebAI` — um modelo que **não existe no
  repositório**. Falha também localmente e nada o referencia (código morto),
  por isso é anterior a este ciclo e fica por tratar.

Os 10 subtests de `transportes_loader.t` passam agora no host — que é a prova de
que o loader corre onde corre, e não só onde foi escrito.

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