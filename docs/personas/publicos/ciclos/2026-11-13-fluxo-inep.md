# Ciclo 2026-11-13: rendimento e distorção do INEP nas metas

- **Período:** 2026-11-13 (implementação em modo automático, validação e
  merge no mesmo dia).
- **História:** #376, parte do épico #368. PR #412.
- **Avaliação:** não houve rodada das personas neste ciclo. Os vereditos
  abaixo seguem os do ciclo anterior, sem nova avaliação.
- **Engenharia:** nota técnica 195.

## Resumo

As metas dos planos ganharam **12 indicadores oficiais de fluxo escolar** do
INEP, por escola e por etapa (anos iniciais, anos finais e ensino médio):

- aprovação;
- reprovação;
- abandono;
- distorção idade-série.

A meta "reduzir o abandono" ou "aumentar a aprovação" passa a ter linha de
base e histórico oficiais, como já tinham as metas do IDEB. O valor se
atualiza sozinho, pela tarefa diária. Quando a escola não tem a etapa, ou o
INEP não publicou a taxa, a tela mostra "sem dado", nunca 0.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**O que mudou para ela:** as metas de fluxo, as mais comuns num plano de
gestão depois do IDEB, deixam de ser manuais. A base sugerida vem do INEP, e o
andamento se mede com o número oficial do ano seguinte. A sugestão de
indicador deixou de confundir "taxa de frequência" com "taxa de aprovação".

**Pendente:** o INEP publica as taxas uma vez por ano. A meta do ano corrente
só ganha medição oficial quando sair o Censo seguinte. A ajuda diz isso.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**O que mudou para ele:** as metas de abandono e de distorção das escolas
passam a ter o mesmo indicador oficial. Por isso entram na comparação da rede
lado a lado, como as do IDEB.

**Pendente:** o vínculo por diretoria regional (P2-RD-04) segue no backlog.

## P3 — Rede privada (mantenedor)

**Sem impacto direto neste ciclo.** As taxas cobrem também as escolas
privadas, mas o plano de gestão e o painel de rede ainda não atendem a rede
privada.

## P4 — Academia (pesquisadora)

**Sem impacto direto neste ciclo.** As taxas entram no banco, mas só são
mostradas nas metas dos planos, sem exportação nem análise aberta.

## P5 — Órgãos de controle e conselhos

**Sem impacto direto neste ciclo.** Indiretamente, o documento da rede passa
a mostrar metas de fluxo com fonte oficial.

## P6 — Terceiro setor e jornalismo de dados

**Sem impacto direto neste ciclo.** Nada novo ficou público.

## O que este ciclo ensinou

- Uma fonte oficial nova entrou sem tela nova. Bastou o catálogo de
  indicadores e a tarefa diária que já existiam.
- A regra "ausência não é zero" valeu já na carga: uma etapa só com "--" na
  planilha não vira linha.
