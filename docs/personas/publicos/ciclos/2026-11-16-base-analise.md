# Ciclo 2026-11-16: porte no ranking e base de análise

- **Período:** 2026-11-16.
- **História:** #439 (PRs #442 e #443), achados RV-05 e RV-02 da
  [reavaliação P4/P6](../avaliacoes/2026-11-15-analises-publicas-reavaliacao.md).
- **Avaliação:** sem rodada nova; os vereditos da reavaliação ficam. Nenhum
  achado da reavaliação fica aberto: uma rodada nova da P4 diria se a ressalva
  cai.
- **Engenharia:** nota técnica 207.

## Resumo

- O ranking de redes mostra a população do município e filtra pelo porte
  (classes de tamanho do IBGE). Com o filtro, a comparação é só entre redes de
  cidades do mesmo tamanho.
- A **base de análise** (`/base-analise`, sem login) entrega uma planilha por
  escola de uma UF com os indicadores escolhidos, a versão dos dados e um
  dicionário com a fonte de cada coluna.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a base do próprio
município, com a escola ao lado das outras, ajuda a montar uma apresentação.
A tela do gestor não muda.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:**
- comparar a rede com redes de cidades do mesmo tamanho é a comparação justa
  que o secretário pede;
- a equipe técnica baixa a base da rede (rede municipal, município) em vez de
  juntar o Censo e o IDEB à mão.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Impacto pequeno:** a base filtra a
rede privada de uma UF, mas a dor central (#429) continua.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria com ressalvas (mantido até nova rodada). **Resolvido:**
- RV-02: a base multi-indicador existe, com o IDEB por etapa ao lado do Censo,
  sem o desvio pelo agrupamento;
- RV-05: o porte do município no ranking.

Com o RV-01, RV-03 e RV-04 já resolvidos, nenhum achado da reavaliação fica
aberto. **Fica fora:** base nacional, séries e API, que são a oferta da
assinatura de dados.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto indireto:** uma
planilha citável (versão e fontes no arquivo) para anexar a um processo.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:**
- a base com a versão e o dicionário é o material de uma matéria de dados;
- o porte evita comparar a capital com uma cidade de 5 mil habitantes.

## O que este ciclo ensinou

- Exportar é escolher a fonte certa. A tabela que o agrupamento usa parecia
  pronta, mas é refeita a cada execução e mistura as etapas do IDEB.
- O dado publicado tem as suas escalas. A aprovação está em %, e o comentário
  antigo da coluna dizia de 0 a 1. A validação com dado real pegou a
  diferença antes do arquivo sair.
