<script>
  // src/features/network-compare/components/NetworkAtendimentoInfantil.svelte
  //
  // #533 (QP-01 da P2): taxa de atendimento da creche e da pré-escola, a
  // meta 1 do PNE, com a população na idade do Censo Demográfico.
  import {
    buildAtendimentoInfantil,
    formatInt,
    formatPercent,
  } from "../utils/transformNetworkData.js";

  let { networks = [] } = $props();

  const atendimento = $derived(buildAtendimentoInfantil(networks));
  const linhas = $derived(
    atendimento
      ? [
          { ...atendimento.creche, id: "creche", rotulo: "Creche", idade: "0 a 3 anos", meta: "50%" },
          { ...atendimento.pre, id: "pre", rotulo: "Pré-escola", idade: "4 e 5 anos", meta: "100%" },
        ]
      : [],
  );
  const temTeto = $derived(linhas.some((l) => l.teto !== null));
</script>

{#if atendimento}
  <section
    class="bg-white border border-gray-200 rounded-card shadow-card p-6"
    data-testid="atendimento-infantil"
  >
    <!-- #549 (QJ-01 da P5): a conta pelo nome, e que não é o indicador oficial -->
    <h2 class="text-lg font-semibold text-gray-900">Matrículas na educação infantil por criança da idade</h2>
    <p class="text-sm text-gray-600 mt-1">
      <strong>Taxa bruta de matrícula:</strong> matrículas na etapa (de qualquer idade e de qualquer município) sobre as
      crianças da idade que moram no município, comparada à meta 1 do PNE (a creche para metade das crianças de 0 a 3 anos
      e a pré-escola para todas as de 4 e 5).
      <span data-testid="aviso-oficial">Não é o indicador oficial da meta 1 do PNE, que mede o percentual das crianças da idade que frequentam creche ou escola, em pesquisa domiciliar: os números podem diferir.</span>
    </p>

    <div class="overflow-x-auto mt-4">
      <table class="min-w-full text-sm">
        <thead>
          <tr class="text-left text-gray-500 border-b border-gray-200">
            <th class="py-2 pr-4 font-medium">Etapa</th>
            <th class="py-2 pr-4 font-medium text-right">Crianças na idade</th>
            <th class="py-2 pr-4 font-medium text-right">Todas as redes</th>
            <th class="py-2 pr-4 font-medium text-right">{atendimento.redeLocal}</th>
            {#if temTeto}
              <th class="py-2 pr-4 font-medium text-right">{atendimento.redeLocal} + conveniadas (teto)</th>
            {/if}
            <th class="py-2 font-medium text-right">Meta do PNE</th>
            <th class="py-2 pl-4 font-medium text-right">Vagas que faltam (estimativa)</th>
          </tr>
        </thead>
        <tbody>
          {#each linhas as l (l.id)}
            <tr class="border-b border-gray-100" data-testid="atendimento-{l.id}">
              <td class="py-2 pr-4 text-gray-800">{l.rotulo} <span class="text-gray-500">({l.idade})</span></td>
              <td class="py-2 pr-4 text-right tabular-nums">{formatInt(l.populacao)}</td>
              <td class="py-2 pr-4 text-right tabular-nums font-medium">{formatPercent(l.todas)}</td>
              <td class="py-2 pr-4 text-right tabular-nums">{formatPercent(l.municipal)}</td>
              {#if temTeto}
                <td class="py-2 pr-4 text-right tabular-nums">{l.teto === null ? "—" : formatPercent(l.teto)}</td>
              {/if}
              <td class="py-2 text-right tabular-nums text-gray-500">{l.meta}</td>
              <td class="py-2 pl-4 text-right tabular-nums font-medium" data-testid="vagas-{l.id}">
                {l.vagas > 0 ? formatInt(l.vagas) : "—"}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <p class="text-xs text-gray-500 mt-3" data-testid="atendimento-nota">
      Crianças contadas no Censo Demográfico {atendimento.ano ?? ""} (IBGE), matrículas do Censo
      Escolar mais recente. A taxa pode passar de 100%: entram crianças de outros municípios e
      fora da idade, e a população mudou desde o Censo. As vagas que faltam são uma estimativa por esta conta: a meta sobre essas crianças menos as
      matrículas de todas as redes; "—" quando a meta já foi atingida.
    </p>
  </section>
{/if}
