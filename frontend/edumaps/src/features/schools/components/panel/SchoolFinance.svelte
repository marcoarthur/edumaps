<script>
  // src/features/schools/components/panel/SchoolFinance.svelte
  import { centroRosca } from "@/shared/ui/components/charts/centroRosca.js";
  import LineChart from "@/shared/ui/components/charts/LineChart.svelte";
  import DonutChart from "@/shared/ui/components/charts/DonutChart.svelte";
  import Icon from "../icons/Icon.svelte";
  import FolhaPorFonte from "./FolhaPorFonte.svelte";
  import { urlPisoPagina } from "../../api/pisoApi.js";   // #601
  import { textoMotivoRede, textoPartesRede } from "../../utils/redeFolha.js";   // #610
  import { listaMeses, faixasMeses, textoSalarioRede, textoPisoRede, textoQuebraAno, textoSalarioEscola, dataBR } from "@/features/fontes/utils.js";
  import { router } from "@/app/router.svelte.js";
  import {
    buildCostRows,
    buildProfessionalsRows,
    buildCategoryBuckets,
    buildCategoryRows,
    buildPeriodOptions,
    summarize,
    periodoTexto,
    formatBRL,
    formatBRLCompact,
    formatInt,
  } from "../../utils/transformFinanceData.js";

  /**
   * @typedef {Object} Props
   * @property {string|number} inep
   * @property {{ nome?: string }|null} [escola]
   * @property {number} [totalProfissionais] profissionais distintos no ano (pessoa = CPF mascarado + nome, #491)
   * @property {number|null} [ano] ano (exercício) mostrado (#491)
   * @property {{ mes_inicial, mes_final, meses }|null} [periodo] meses do ano com folha
   * @property {Array<{ ano, mes, mes_num, total_salario, total_profissionais }>} [series]
   * @property {Array<{ categoria, tipo, total_salario, total_profissionais }>} [categorias]
   * @property {{ fundeb_70, fundeb_30, outras, total, nao_informado }|null} [porFonte] folha do ano por fonte de recurso (#553)
   * @property {{ folha_ano, folha_por_mes, censo: { docentes, ano }|null, municipio: { magisterio, so_secretaria, avisar }|null }|null} [docentes] folha e Censo lado a lado (#567)
   * @property {string|null} [cargaFolha] data da carga registrada do município e ano (#576)
   * @property {{ pessoas, total, base, carga_comum }|null} [salarioRede] o salário do magistério da rede inteira no ano (#571)
   * @property {Array<{ mes, nome, registros, categorias, registros_habitual, categorias_habitual }>} [mesesIncompletos] meses do ano com a folha do município pela metade (#557)
   */

  /** @type {Props} */
  let { inep, escola = null, totalProfissionais = 0, origem = "escola", rede = null, series = [], categorias = [], ano = null, periodo = null, porFonte = null, mesesIncompletos = [], mesesSecretaria = [], docentes = null, salarioRede = null, municipioIbge = null, cargaFolha = null, salarioEscola = null } = $props();

  // #491 (RJ-02): o rótulo diz o ano e os meses ("em 2025 (jan a dez)").
  const noAno = $derived(ano ? ` em ${ano}${periodo ? ` (${periodoTexto(periodo)})` : ""}` : " (período)");
  const temDezembro = $derived(series.some((s) => Number(s.mes_num) === 12));

  // Quando a escola não tem folha própria (origem='rede'), todo o painel é o da
  // REDE MUNICIPAL inteira (#610: escolas e Secretaria), nunca o da unidade.
  const ehRede = $derived(origem === "rede");
  const escopo = $derived(ehRede ? "rede municipal" : "escola");
  const escopoTitulo = $derived(ehRede ? "Rede municipal (escolas e Secretaria)" : "");
  // #610 (QE-01 da P2): por que é o painel da rede, conforme o ano
  const motivoRede = $derived(textoMotivoRede(rede, ano));
  const partesRede = $derived(textoPartesRede(rede));

  // #557: só os meses incompletos que estão na série mostrada (a escola pode
  // não ter folha num mês incompleto do município).
  const incompletos = $derived(
    mesesIncompletos.filter((m) => series.some((s) => Number(s.mes_num) === Number(m.mes))),
  );

  // #558: "De março a agosto" / "Em janeiro e fevereiro" / "Em junho"
  const quandoSecretaria = $derived.by(() => {
    const t = faixasMeses(mesesSecretaria);
    return t.startsWith("de ") ? `D${t.slice(1)}` : `Em ${t}`;
  });

  // #568 (P1-FL-02): quem está em mais de uma categoria conta em cada uma.
  const somaCategorias = $derived(buckets.reduce((n, b) => n + (Number(b.total_profissionais) || 0), 0));

  // #610: no painel da rede, a linha da parte da Secretaria ao lado do total
  const costRows = $derived(ehRede && series.some((s) => Number(s.total_secretaria) > 0)
    ? [...buildCostRows(series), ...series.map((r) => ({ ...buildCostRows([r])[0], group: "Total da Secretaria (sem escola)", value: Number(r.total_secretaria) || 0 }))]
    : buildCostRows(series));
  const professionalRows = $derived(buildProfessionalsRows(series));
  const buckets = $derived(buildCategoryBuckets(categorias));
  const categoryRows = $derived(buildCategoryRows(buckets));
  const periodOptions = $derived(buildPeriodOptions(series));
  const stats = $derived(summarize(series));

  let selectedPeriod = $state("");
  $effect(() => {
    // Mantém a competência mais recente como padrão do dropdown.
    if (!selectedPeriod && periodOptions.length > 0) {
      selectedPeriod = periodOptions[0].value;
    }
  });

  const costOptions = $derived({
    title: `Custo total mensal${ehRede ? " — rede municipal" : ""}`,
    axes: {
      left: { mapsTo: "value", title: "R$" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Mês" },
    },
    data: { groupMapsTo: "group" },
    legend: { enabled: ehRede },
    curve: "curveMonotoneX",
    points: { enabled: true },
  });

  const professionalOptions = $derived({
    title: `Profissionais por mês${ehRede ? " — rede municipal" : ""}`,
    axes: {
      left: { mapsTo: "value", title: "Profissionais" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Mês" },
    },
    data: { groupMapsTo: "group" },
    legend: { enabled: false },
    curve: "curveMonotoneX",
    points: { enabled: true },
  });

  const categoryColorScale = $derived(
    Object.fromEntries(buckets.map((b) => [b.bucket.label, b.bucket.color])),
  );

  const categoryOptions = $derived({
    title: `Custo por categoria${ehRede ? " — rede municipal" : ""}`,
    donut: { center: centroRosca("Total", stats.totalCusto, formatBRLCompact) },
    data: { groupMapsTo: "group" },
    color: { scale: categoryColorScale },
    legend: { position: "bottom" },
  });

  function verFolhaCompleta() {
    if (!selectedPeriod) return;
    // #610 (QE-01 da P2): no painel da rede, a folha da rede inteira no mês
    router.navigate(`/escola/payroll?inep=${inep}&date=${selectedPeriod}${ehRede ? "&rede=1" : ""}`);
  }

  function verFolhaSecretaria() {
    if (!selectedPeriod) return;
    router.navigate(`/escola/payroll?inep=${inep}&date=${selectedPeriod}&secretaria=1`);
  }
</script>

<div class="space-y-6">
  {#if ehRede}
    <div class="rounded-md bg-amber-50 border border-amber-300 text-amber-900 text-sm p-4">
      <p class="font-semibold">Painel da rede municipal — não desta escola</p>
      <p class="mt-1" data-testid="motivo-rede">{motivoRede}</p>
    </div>
  {/if}

  <!-- Totais -->
  <section class="grid grid-cols-1 sm:grid-cols-3 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-4">
      <p class="text-xs text-gray-500">
        Custo total{noAno}{#if ehRede} · {escopoTitulo}{/if}
      </p>
      <p class="text-xl font-bold text-gray-900 mt-1">
        {formatBRL(stats.totalCusto)}
      </p>
      {#if temDezembro}
        <p class="text-xs text-gray-400 mt-0.5" data-testid="nota-13">Dezembro inclui o 13º salário.</p>
      {/if}
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-4">
      <p class="text-xs text-gray-500">
        Profissionais{ano ? ` em ${ano}` : " (total)"}{#if ehRede} · {escopoTitulo}{/if}
      </p>
      <p class="text-xl font-bold text-gray-900 mt-1">
        {formatInt(totalProfissionais)}
      </p>
      <p class="text-xs text-gray-400 mt-0.5">
        No último mês ({stats.lastPeriod ? stats.lastPeriod.toLowerCase() : "—"}): {formatInt(stats.lastProfessionals)}
      </p>
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-4">
      <p class="text-xs text-gray-500">Meses com folha</p>
      <p class="text-xl font-bold text-gray-900 mt-1">{stats.mesCount}</p>
    </div>
  </section>

  {#if ehRede && partesRede}
    <!-- #610: de onde vem o total da rede -->
    <p class="text-sm text-gray-700" data-testid="partes-rede">{partesRede}</p>
  {/if}

  {#if !ehRede && mesesSecretaria.length}
    <!-- #558 (QT-02 da P2): meses em que o município declarou só o total da Secretaria -->
    <p class="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-4 py-3" role="note" data-testid="aviso-meses-secretaria">
      {quandoSecretaria}{ano ? ` de ${ano}` : ""},
      o município declarou a folha só no total da Secretaria, sem separar as escolas:
      {mesesSecretaria.length === 1 ? "nesse mês" : "nesses meses"} a folha desta escola não aparece, e o custo do ano fica abaixo do real.
    </p>
  {/if}

  {#if incompletos.length}
    <!-- #557 (QT-01 da P2): mês com a folha do município pela metade -->
    <p class="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-4 py-3" role="note" data-testid="aviso-meses-incompletos">
      {listaMeses(incompletos).replace(/^./, (c) => c.toUpperCase())}{ano ? ` de ${ano}` : ""}
      {incompletos.length === 1 ? "tem" : "têm"} bem menos profissionais declarados que os outros meses do município
      ({incompletos.map((m) => `${m.nome}: ${m.registros.toLocaleString("pt-BR")} registros em ${m.categorias} ${m.categorias === 1 ? "categoria" : "categorias"}, contra ${m.registros_habitual.toLocaleString("pt-BR")} em ${m.categorias_habitual} num mês típico`).join("; ")}).
      {#if cargaFolha}
        A planilha do SIOPE baixada em {dataBR(cargaFolha)} traz {incompletos.length === 1 ? "este mês" : "estes meses"} assim: a falta está na fonte, e não na carga.
      {:else}
        Pode ser a declaração do município ao SIOPE ou a carga.
      {/if}
      {incompletos.length === 1 ? "Nesse mês" : "Nesses meses"}, o custo e os profissionais ficam abaixo do real, e o total do ano também.
    </p>
  {/if}

  {#if salarioRede?.pessoas}
    <!-- #571 (QI-01 da P3): o salário do magistério da rede inteira, com a Secretaria -->
    <p class="text-sm text-gray-700 bg-white border border-gray-200 rounded-card shadow-card px-4 py-3" data-testid="salario-rede">
      <strong>Magistério na rede municipal{ano ? ` em ${ano}` : ""}:</strong> {textoSalarioRede(salarioRede)}.
      <span class="text-xs text-gray-500">Toda a folha do município, nas escolas e no total da Secretaria; sem conversão para 40 horas.</span>
      {#if !ehRede && salarioEscola?.pessoas}
        <!-- #589 (P1-FL-03): a escola na mesma conta da rede -->
        <span class="block mt-1" data-testid="salario-escola"><strong>Nesta escola{ano ? ` em ${ano}` : ""}:</strong> {textoSalarioEscola(salarioEscola, salarioRede)}.</span>
      {/if}
      {#if textoQuebraAno(salarioRede.comparacao_ano_anterior, ano)}
        <!-- #604 (QD-02 da P2): a folha do ano não se compara à do anterior -->
        <span class="block text-xs text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-2 py-1 mt-1" role="note" data-testid="quebra-ano">{textoQuebraAno(salarioRede.comparacao_ano_anterior, ano)}</span>
      {/if}
      {#if ehRede && textoPisoRede(salarioRede, ano)}
        <!-- #575 (QH-01 da P5): só no painel da Secretaria (A1) -->
        <span class="block text-xs text-gray-700 mt-1" data-testid="piso-rede">{textoPisoRede(salarioRede, ano)}</span>
        {#if municipioIbge && salarioRede.abaixo_piso > 0}
          <!-- #601 (QC-01 da P2): a lista do ano, pessoa a pessoa, com CSV -->
          <a class="block text-xs text-blue-700 hover:underline mt-1" href={urlPisoPagina(municipioIbge, ano)} data-testid="link-lista-piso">Ver a lista do ano, pessoa a pessoa (com CSV) →</a>
        {/if}
      {/if}
    </p>
  {/if}

  <!-- Séries temporais -->
  <section class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      {#if costRows.length > 0}
        <LineChart data={costRows} options={costOptions} height="300px" />
      {:else}
        <p class="text-sm text-gray-500">Sem dados de custo.</p>
      {/if}
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      {#if professionalRows.length > 0}
        <LineChart
          data={professionalRows}
          options={professionalOptions}
          height="300px"
        />
      {:else}
        <p class="text-sm text-gray-500">Sem dados de profissionais.</p>
      {/if}
    </div>
  </section>

  <!-- Custo por categoria -->
  {#if buckets.length > 0}
    <section class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
        <DonutChart data={categoryRows} options={categoryOptions} height="300px" />
      </div>

      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
        <h2 class="text-base font-bold text-gray-900 mb-3">
          Categorias profissionais{#if ehRede} — rede municipal{/if}
        </h2>
        <ul class="flex flex-col gap-3">
          {#each buckets as b (b.bucket.id)}
            {@const share = stats.totalCusto > 0
              ? Math.round((b.total_salario / stats.totalCusto) * 100)
              : 0}
            <li class="flex items-center gap-3">
              <Icon name={b.bucket.icon} size={26} active />
              <div class="grow">
                <p class="text-sm text-gray-800">{b.bucket.label}</p>
                <p class="text-xs text-gray-500">
                  {formatInt(b.total_profissionais)} profissional(is) · {share}%
                </p>
              </div>
              <span class="text-sm font-medium text-gray-900 whitespace-nowrap">
                {formatBRL(b.total_salario)}
              </span>
            </li>
          {/each}
        </ul>
        {#if somaCategorias > totalProfissionais && totalProfissionais > 0}
          <p class="text-xs text-gray-500 mt-2" data-testid="nota-soma-categorias">
            Quem está em mais de uma categoria conta em cada uma: a soma ({formatInt(somaCategorias)}) passa do
            total de profissionais ({formatInt(totalProfissionais)}).
          </p>
        {/if}
        {#if docentes && !ehRede}
          <!-- #567 (P1-FL-01): os docentes do Censo ao lado da folha -->
          <div class="mt-4 pt-3 border-t border-gray-100 text-sm text-gray-700" data-testid="docentes-folha-censo">
            <p>
              <strong>Docentes na folha:</strong> {formatInt(docentes.folha_ano)}{ano ? ` em ${ano}` : ""}{#if docentes.folha_por_mes != null}{` (${docentes.folha_por_mes.toLocaleString("pt-BR")} por mês, em média)`}{/if}.
              {#if docentes.censo}
                <strong>No Censo Escolar {docentes.censo.ano}:</strong> {formatInt(docentes.censo.docentes)}.
              {/if}
            </p>
            <p class="text-xs text-gray-500 mt-1">
              Os números podem diferir: o professor pode ser pago no total da Secretaria, por outra rede ou por outra
              fonte; a folha conta quem esteve na escola só parte do ano e quem está nela sem dar aula; o Censo conta os
              docentes de um dia de maio.
            </p>
            {#if docentes.municipio?.avisar}
              <p class="text-xs text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-3 py-2 mt-2" role="note" data-testid="aviso-so-secretaria">
                {ano ? `Em ${ano}, ` : ""}{formatInt(docentes.municipio.so_secretaria)} dos {formatInt(docentes.municipio.magisterio)}
                profissionais do magistério do município aparecem só no total da Secretaria, sem escola: parte dos
                professores desta escola pode estar lá.
              </p>
            {/if}
          </div>
        {/if}
      </div>
    </section>
  {/if}

  <!-- #553: por fonte de recurso (Fundeb 70%, 30%, outras) -->
  <FolhaPorFonte {porFonte} titulo={`${noAno}${ehRede ? " · rede municipal" : ""}`} />

  <!-- Folha completa (detalhes por competência) -->
  <section
    class="bg-white border border-gray-200 rounded-card shadow-card p-5 flex flex-wrap items-end gap-3"
  >
    <div>
      <label for="competencia" class="block text-sm text-gray-600 mb-1">
        Ver folha completa (detalhes){#if ehRede} — rede municipal{/if}
      </label>
      <select
        id="competencia"
        bind:value={selectedPeriod}
        class="border border-gray-300 rounded-md px-3 py-2 text-sm"
      >
        {#each periodOptions as p}
          <option value={p.value}>{p.label}</option>
        {/each}
      </select>
    </div>
    <button
      type="button"
      onclick={verFolhaCompleta}
      disabled={!selectedPeriod}
      class="px-4 py-2 bg-blue-700 text-white text-sm font-medium rounded-md hover:bg-blue-800 transition-colors disabled:opacity-50"
    >
      Ver folha completa →
    </button>
    {#if !ehRede && docentes?.municipio?.so_secretaria > 0}
      <button type="button" onclick={verFolhaSecretaria} disabled={!selectedPeriod} data-testid="ver-folha-secretaria"
        class="px-4 py-2 border border-blue-700 text-blue-700 text-sm font-medium rounded-md hover:bg-blue-50 disabled:opacity-50">
        Ver a folha do total da Secretaria →
      </button>
    {/if}
    <p class="text-xs text-gray-400 basis-full">
      {#if ehRede}
        A folha detalhada lista as pessoas declaradas no total da Secretaria: o SIOPE não detalha por escola neste
        município, e não diz em que unidade cada uma trabalha.
      {:else}
        {escola?.nome ?? ""} — a folha lista os profissionais (nomes) apenas na
        página de detalhes.
      {/if}
    </p>
  </section>
</div>
