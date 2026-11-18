# Reavaliação: P4 e a evolução da escola (2026-11-17)

Décima sexta rodada da P4 (academia), em modo autônomo (delegação do
developer até 7h de 18/11), depois da entrega da décima quinta rodada:

| Entrega | O quê |
|---|---|
| #484 | IDEB e SAEB do perfil comparados na mesma etapa; IDEB de cada etapa da escola (RN-01, RN-02) |

- **Avaliou:** só a P4.
- **Material:** a seção "Evolução" do perfil da escola
  (`/api/school/:inep/evolution`), a ajuda do perfil e o banco local, só
  leitura.
- **O trabalho que ela faria:** acompanhar a série do IDEB e do SAEB de
  escolas de Salvador, de 2005 a 2023, para um estudo de trajetória.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **O perfil novo** (RN-01 e RN-02 resolvidos): o IDEB comparado na mesma
   etapa, e a tabela "IDEB em cada etapa".
2. **A série do IDEB** sai por etapa, como deve.
3. **A série do SAEB** (nota média, matemática e português) não diz a etapa.
   - Ela vem de `clean.inep_notas_desagregadas`, uma linha por escola e ano,
     sem etapa. Em 2023, as 41.301 linhas batem uma a uma com as notas dos
     **anos iniciais** da planilha do IDEB.
   - A tela mostra "Nota média (SAEB)" como se fosse a da escola.
   - **18.533 escolas** só de anos finais ou ensino médio ficam **sem**
     série do SAEB, embora a planilha do IDEB traga as notas delas por
     etapa (o colégio estadual da rodada anterior tem matemática dos anos
     finais de 2005 a 2023).
   - **32.544 escolas** com anos iniciais e outra etapa veem a série dos
     anos iniciais sem saber que é só dela (RM-01).
4. **A variação.**
   - O ▲/▼ é a diferença entre a primeira e a última edição.
   - Numa série de uma edição só, a tela mostra "▲ 0.0", que lê como
     "estável" quando não há variação nenhuma para medir. São 17.217 séries
     do IDEB com uma edição (RM-02).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem a série do SAEB | o IDEB por etapa serve à trajetória; a série do SAEB é só dos anos iniciais, sem dizer, e falta para 18 mil escolas (RM-01) |

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RM-01 | atrapalha | **A série do SAEB da evolução é só dos anos iniciais e não diz isso.** Pedido: a série do SAEB por etapa, a partir das notas da planilha do IDEB (`ideb_notas_escolas`), como a do IDEB. | 41.301 de 41.301 linhas de 2023 = anos iniciais; 18.533 escolas sem série; 32.544 com a série de uma etapa só | P4, P1 |
| RM-02 | detalhe | **Série de uma edição mostra "▲ 0.0".** Pedido: sem variação quando há uma edição só. | 17.217 séries do IDEB | P1, P4 |

## Encaminhamento

Modo autônomo: abri a issue **#485** (RM-01 e RM-02 juntas) e sigo para a
implementação, com aviso pelo Telegram.

## Andamento

- 2026-11-17: #485 (PR #486) mergeado em modo autônomo: RM-01 e RM-02
  resolvidos (SAEB da evolução por etapa, da planilha do IDEB; sem variação
  com uma edição). Fechamento em
  [`../ciclos/2026-11-17-evolucao-saeb-etapa.md`](../ciclos/2026-11-17-evolucao-saeb-etapa.md).
  Nenhum achado aberto.
