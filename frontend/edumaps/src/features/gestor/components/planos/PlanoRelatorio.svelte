<!-- src/features/gestor/components/planos/PlanoRelatorio.svelte -->
<script>
  // Relatório de acompanhamento do plano (#374, RF-009), pronto para imprimir
  // ou salvar em PDF (A4, mesmo padrão `relatorio-imprimivel` do Assistente de
  // Relatório). Só mostra o que veio do backend: escola, plano, período,
  // andamento por objetivo e por meta (fonte e ano de cada indicador oficial;
  // "Sem medição" em texto, nunca 0%), custo previsto por fonte de recurso
  // (#384), ações por situação, evidências e a data de emissão. O único nome possível é o responsável da ação (texto livre).
  import {
    PLANO_TIPO_LABEL,
    PLANO_SITUACAO_LABEL,
    META_ESTADO_LABEL,
    SENTIDOS,
    FONTE_RECURSO_LABEL,
    pct,
    fmtMoeda,
    fmtData,
    fmtNum,
  } from "../../constants/planos.js";

  /** @type {{ relatorio: object }} */
  let { relatorio } = $props();

  let plano = $derived(relatorio.plano);
  let escola = $derived(relatorio.escola ?? {});
  let grupos = $derived(relatorio.acoes_por_situacao ?? {});

  const GRUPOS = [
    { chave: "atrasadas", titulo: "Atrasadas" },
    { chave: "em_andamento", titulo: "Em andamento" },
    { chave: "nao_iniciadas", titulo: "Não iniciadas" },
    { chave: "concluidas", titulo: "Concluídas" },
    { chave: "canceladas", titulo: "Canceladas" },
  ];
  const SENTIDO = Object.fromEntries(SENTIDOS.map((s) => [s.valor, s.rotulo.split(" ")[0].toLowerCase()]));
  const TIPO_EVIDENCIA = { ata: "Ata de reunião", documento: "Documento", nota: "Nota" };
  const fonteRotulo = (f) => (f === "nao_informada" ? "Fonte não informada" : (FONTE_RECURSO_LABEL[f] ?? f));
  let custos = $derived(relatorio.custos ?? { por_fonte: [], total: 0, n_acoes_sem_custo: 0 });

  const emitidoEm = $derived.by(() => {
    const [d, h] = String(relatorio.emitido_em ?? "").split("T");
    return d ? `${fmtData(d)} às ${(h ?? "").slice(0, 5)}` : "—";
  });

  const andamento = (m) =>
    m.progresso !== null && m.progresso !== undefined ? pct(m.progresso) : (META_ESTADO_LABEL[m.estado] ?? "Sem medição");

  const fonteAno = (m) => {
    if (!m.indicador) return "Medição da escola";
    const ano = m.atual?.ano_ref;
    return `${m.indicador.fonte}${ano ? `, ${ano}` : ", sem valor da escola"}`;
  };

  const atualTexto = (m) =>
    m.atual ? `${fmtNum(m.atual.valor)} (${m.atual.ano_ref ?? fmtData(m.atual.data_ref)})` : "—";

  const evidencias = $derived(
    plano.objetivos.flatMap((o) => [
      ...o.metas.flatMap((m) => (m.evidencias ?? []).map((e) => ({ ...e, de: `Meta: ${m.descricao}` }))),
      ...o.acoes.flatMap((a) => (a.evidencias ?? []).map((e) => ({ ...e, de: `Ação: ${a.descricao}` }))),
    ]),
  );

  const evidenciaTexto = (e) =>
    e.tipo === "nota" ? e.texto : `${e.titulo ?? "Sem título"}${e.origem_removida ? " (origem removida)" : ""}`;

  const TH = "text-left font-semibold text-gray-700 px-2 py-1 border-b border-gray-300";
  const TD = "px-2 py-1 border-b border-gray-100 align-top";
</script>

<article class="relatorio-imprimivel space-y-6 text-sm text-gray-900" aria-labelledby="plano-relatorio-titulo" data-testid="plano-relatorio">
  <header class="space-y-1 border-b border-gray-300 pb-3">
    <p class="text-xs uppercase tracking-wide text-gray-500">Relatório de acompanhamento do plano</p>
    <h1 id="plano-relatorio-titulo" class="text-xl font-bold">{plano.titulo}</h1>
    <p>
      {escola.nome ?? "Escola"} · INEP {escola.cod_inep}
      {#if escola.municipio}{" · "}{escola.municipio}{#if escola.uf}/{escola.uf}{/if}{/if}
    </p>
    <p class="text-gray-700">
      {PLANO_TIPO_LABEL[plano.tipo] ?? plano.tipo} · período {fmtData(plano.inicio)} a {fmtData(plano.fim)} ·
      situação: {PLANO_SITUACAO_LABEL[plano.situacao] ?? plano.situacao}
    </p>
    <p class="text-xs text-gray-500">Emitido em {emitidoEm}</p>
  </header>

  <section aria-labelledby="rel-resumo" class="space-y-1 print:break-inside-avoid">
    <h2 id="rel-resumo" class="text-base font-semibold">Resumo</h2>
    <ul class="list-disc pl-5 space-y-0.5">
      <li>
        Andamento das metas:
        <strong>{plano.resumo.progresso?.valor !== null && plano.resumo.progresso?.valor !== undefined ? pct(plano.resumo.progresso.valor) : "sem metas medidas"}</strong>
        ({plano.resumo.progresso?.n_medidas ?? 0} de {plano.resumo.progresso?.n_metas ?? plano.resumo.n_metas} meta(s) medida(s))
      </li>
      <li>{plano.resumo.n_objetivos} objetivo(s), {plano.resumo.n_metas} meta(s), {plano.resumo.n_acoes} ação(ões)</li>
      <li>
        Ações: {grupos.concluidas?.length ?? 0} concluída(s), {grupos.em_andamento?.length ?? 0} em andamento,
        {grupos.atrasadas?.length ?? 0} atrasada(s), {grupos.nao_iniciadas?.length ?? 0} não iniciada(s),
        {grupos.canceladas?.length ?? 0} cancelada(s)
      </li>
      <li>{relatorio.n_evidencias ?? 0} evidência(s) registrada(s)</li>
    </ul>
    <p class="text-xs text-gray-500">
      O andamento é a média das metas que já têm medição. Meta sem medição não entra na conta e aparece como
      “Sem medição”, nunca como 0%.
    </p>
  </section>

  <section aria-labelledby="rel-custos" class="space-y-1 print:break-inside-avoid">
    <h2 id="rel-custos" class="text-base font-semibold">Custo previsto por fonte de recurso</h2>
    {#if custos.por_fonte.length}
      <table class="w-full max-w-md border-collapse text-xs">
        <thead>
          <tr>
            <th class={TH} scope="col">Fonte</th>
            <th class={`${TH} text-right`} scope="col">Ações</th>
            <th class={`${TH} text-right`} scope="col">Custo previsto</th>
          </tr>
        </thead>
        <tbody>
          {#each custos.por_fonte as c (c.fonte)}
            <tr>
              <td class={TD}>{fonteRotulo(c.fonte)}</td>
              <td class={`${TD} text-right`}>{c.n_acoes}</td>
              <td class={`${TD} text-right`}>{fmtMoeda(c.total)}</td>
            </tr>
          {/each}
          <tr class="font-semibold">
            <td class={TD}>Total</td>
            <td class={`${TD} text-right`}>{custos.por_fonte.reduce((s, c) => s + c.n_acoes, 0)}</td>
            <td class={`${TD} text-right`}>{fmtMoeda(custos.total)}</td>
          </tr>
        </tbody>
      </table>
    {:else}
      <p class="text-gray-500">Nenhuma ação com custo previsto informado.</p>
    {/if}
    <p class="text-xs text-gray-500">
      Soma das ações não canceladas com custo informado.
      {#if custos.n_acoes_sem_custo}{custos.n_acoes_sem_custo} ação(ões) sem custo informado (não entram como R$ 0).{/if}
    </p>
  </section>

  <section aria-labelledby="rel-metas" class="space-y-4">
    <h2 id="rel-metas" class="text-base font-semibold">Objetivos e metas</h2>
    {#each plano.objetivos as o (o.id)}
      <div class="space-y-1 print:break-inside-avoid">
        <h3 class="font-semibold">
          {o.titulo}
          <span class="font-normal text-gray-600">
            — {o.progresso?.valor !== null && o.progresso?.valor !== undefined ? pct(o.progresso.valor) : "sem metas medidas"}
            ({o.progresso?.n_medidas ?? 0} de {o.progresso?.n_metas ?? 0} medida(s))
          </span>
        </h3>
        {#if o.metas.length}
          <table class="w-full border-collapse text-xs">
            <thead>
              <tr>
                <th class={TH} scope="col">Meta</th>
                <th class={TH} scope="col">Fonte e ano</th>
                <th class={TH} scope="col">Base</th>
                <th class={TH} scope="col">Alvo</th>
                <th class={TH} scope="col">Atual</th>
                <th class={TH} scope="col">Andamento</th>
              </tr>
            </thead>
            <tbody>
              {#each o.metas as m (m.id)}
                <tr>
                  <td class={TD}>{m.descricao}<span class="text-gray-500">{" ("}{SENTIDO[m.sentido] ?? m.sentido}{#if m.unidade}{", "}{m.unidade}{/if})</span></td>
                  <td class={TD}>{fonteAno(m)}</td>
                  <td class={TD}>{fmtNum(m.linha_base)}</td>
                  <td class={TD}>{fmtNum(m.alvo)}</td>
                  <td class={TD}>{atualTexto(m)}</td>
                  <td class={TD}>{andamento(m)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="text-xs text-gray-500">Sem metas neste objetivo.</p>
        {/if}
      </div>
    {:else}
      <p class="text-gray-500">O plano ainda não tem objetivos.</p>
    {/each}
  </section>

  <section aria-labelledby="rel-acoes" class="space-y-3">
    <h2 id="rel-acoes" class="text-base font-semibold">Ações</h2>
    {#each GRUPOS as g (g.chave)}
      {#if grupos[g.chave]?.length}
        <div class="space-y-1 print:break-inside-avoid">
          <h3 class="font-semibold">{g.titulo} ({grupos[g.chave].length})</h3>
          <table class="w-full border-collapse text-xs">
            <thead>
              <tr>
                <th class={TH} scope="col">Ação</th>
                <th class={TH} scope="col">Objetivo</th>
                <th class={TH} scope="col">Responsável</th>
                <th class={TH} scope="col">Prazo</th>
                <th class={`${TH} text-right`} scope="col">Custo previsto</th>
                <th class={TH} scope="col">Fonte</th>
                <th class={TH} scope="col">Evidências</th>
              </tr>
            </thead>
            <tbody>
              {#each grupos[g.chave] as a (a.id)}
                <tr>
                  <td class={TD}>{a.descricao}</td>
                  <td class={TD}>{a.objetivo}</td>
                  <td class={TD}>{a.responsavel ?? "—"}</td>
                  <td class={TD}>{fmtData(a.prazo)}{#if a.situacao === "concluida" && a.concluida_em}{" (concluída em "}{fmtData(a.concluida_em)}){/if}</td>
                  <td class={`${TD} text-right`}>{fmtMoeda(a.custo_previsto)}</td>
                  <td class={TD}>{a.fonte_recurso ? FONTE_RECURSO_LABEL[a.fonte_recurso] : "—"}</td>
                  <td class={TD}>{a.evidencias?.length ?? 0}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    {/each}
    {#if !plano.resumo.n_acoes}<p class="text-gray-500">O plano ainda não tem ações.</p>{/if}
  </section>

  <section aria-labelledby="rel-evidencias" class="space-y-1">
    <h2 id="rel-evidencias" class="text-base font-semibold">Evidências</h2>
    {#if evidencias.length}
      <table class="w-full border-collapse text-xs">
        <thead>
          <tr>
            <th class={TH} scope="col">De</th>
            <th class={TH} scope="col">Tipo</th>
            <th class={TH} scope="col">Evidência</th>
          </tr>
        </thead>
        <tbody>
          {#each evidencias as e (e.id)}
            <tr>
              <td class={TD}>{e.de}</td>
              <td class={TD}>{TIPO_EVIDENCIA[e.tipo] ?? e.tipo}{#if e.tipo === "ata" && e.quando}{" ("}{fmtData(e.quando)}){/if}</td>
              <td class={TD}>{evidenciaTexto(e)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {:else}
      <p class="text-gray-500">Nenhuma evidência registrada.</p>
    {/if}
  </section>

  <footer class="border-t border-gray-300 pt-2 text-[11px] text-gray-500 space-y-0.5">
    <p>Valores oficiais com a fonte e o ano de cada indicador. Valores das metas manuais informados pela escola.</p>
    <p>Gerado pelo EduMaps em {emitidoEm}.</p>
  </footer>
</article>
