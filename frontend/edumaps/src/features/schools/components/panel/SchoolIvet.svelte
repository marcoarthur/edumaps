<script>
  // src/features/schools/components/panel/SchoolIvet.svelte
  //
  // Card do IVET (Índice de Vulnerabilidade de acesso) no painel da escola —
  // issue #296, PR 3. Consome GET /api/school/:cod_inep/ivet (última medição
  // vigente em analytics.ivet_escola).
  //
  // Regras de exibição:
  // - Ausência ≠ 0 (#154): `ivet`/bloco nulo vira "não calculado", nunca 0.
  // - LGPD: quando `publicavel` é false, os valores não são exibidos — só o
  //   aviso de que a medição existe mas não é publicável para esta escola.
  import { IVET_BLOCOS } from "../../constants/ivet.js";

  /**
   * @typedef {Object} Props
   * @property {Object|null} [ivet] - payload de getSchoolIvet()
   * @property {boolean} [loading]
   */

  /** @type {Props} */
  let { ivet = null, loading = false } = $props();

  const fmt = (v) => (v == null ? null : Number(v).toFixed(3));

  // Blocos com valor calculado (para o grid) — a ausência fica como null.
  let blocos = $derived(
    IVET_BLOCOS.map((b) => ({ ...b, valor: ivet?.blocos?.[b.chave] ?? null })),
  );

  let semMedicao = $derived(!loading && ivet == null);
  let naoPublicavel = $derived(ivet != null && ivet.publicavel === false);
</script>

<section
  class="flex flex-col gap-4 bg-white border border-gray-200 rounded-md p-4"
  aria-label="IVET — vulnerabilidade de acesso"
>
  <header class="flex flex-wrap items-baseline justify-between gap-2">
    <div>
      <h3 class="m-0 font-sans text-base font-bold text-gray-900">
        Vulnerabilidade de acesso
      </h3>
      <p class="m-0 text-xs text-gray-500">
        Barreiras de acesso à escola (transporte, distância, segurança).
      </p>
    </div>
    {#if ivet?.dt_snapshot}
      <span class="text-[11px] font-mono text-gray-400" title="Snapshot da medição">
        {ivet.formula} · {ivet.dt_snapshot}
      </span>
    {/if}
  </header>

  {#if loading}
    <p class="text-sm text-gray-500 m-0">Carregando índice…</p>
  {:else if semMedicao}
    <p class="text-sm text-gray-500 m-0">
      Esta escola ainda não teve o índice de acesso calculado.
    </p>
  {:else if naoPublicavel}
    <div class="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-md p-3">
      <span class="text-amber-600 text-lg leading-none" aria-hidden="true">⚠</span>
      <p class="m-0 text-sm text-amber-800">
        O índice foi medido, mas <strong>não é publicável</strong> para esta escola
        (amostra insuficiente ou dado sensível). Os valores não são exibidos.
      </p>
    </div>
  {:else}
    <!-- Selo do índice geral — elemento de assinatura do painel -->
    <div class="flex items-center gap-4">
      <div
        class="flex-none w-20 h-20 rounded-full border-2 border-amber-500 flex flex-col items-center justify-center font-display text-amber-600"
        title="IVET: quanto maior, mais vulnerável o acesso"
      >
        <span class="text-2xl font-bold leading-none">{fmt(ivet.ivet) ?? "—"}</span>
        <span class="text-[9px] font-mono mt-0.5">IVET</span>
      </div>
      <p class="m-0 text-sm text-gray-600">
        Índice de <strong>0</strong> (sem barreira) a <strong>1</strong> (barreira máxima).
        {
          ivet.raio_m
            ? `Composto pela área de influência de ${ivet.raio_m} m.`
            : ""
        }
      </p>
    </div>

    <!-- Blocos A–G -->
    <ul class="grid grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-2 m-0 p-0 list-none">
      {#each blocos as b (b.chave)}
        <li class="flex items-center justify-between gap-2 bg-gray-50 border border-gray-100 rounded px-3 py-2">
          <span class="flex items-center gap-2 min-w-0">
            <span class="flex-none w-5 h-5 rounded-full bg-gray-200 text-gray-700 text-[10px] font-mono flex items-center justify-center">
              {b.sigla}
            </span>
            <span class="text-xs text-gray-700 truncate" title={b.rotulo}>{b.rotulo}</span>
          </span>
          {#if b.valor == null}
            <span class="text-xs text-gray-400 italic" title="Bloco não calculado">n/d</span>
          {:else}
            <span class="text-sm font-mono text-gray-900">{fmt(b.valor)}</span>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</section>
