<script>
  // src/features/schools/components/panel/FolhaPorFonte.svelte
  // #553 (QS-01 da P5): quanto da folha do ano foi pago com o Fundeb (a
  // parcela de 70% e a de 30%) e com outras fontes, como o município declara
  // ao SIOPE em cada pagamento. Não é a verificação do mínimo legal: essa
  // conta usa a receita do Fundeb, que não está na plataforma.
  import { linhasPorFonte, formatBRL } from "../../utils/transformFinanceData.js";

  /** @type {{ porFonte: object|null, titulo?: string, comFundeb?: boolean }} */
  let { porFonte = null, titulo = "", comFundeb = false } = $props();

  const linhas = $derived(linhasPorFonte(porFonte));
  const pct = (v) => v.toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
</script>

{#if linhas.length > 0}
  <section class="bg-white border border-gray-200 rounded-card shadow-card p-5" data-testid="folha-por-fonte">
    <h2 class="text-base font-bold text-gray-900 mb-1">Por fonte de recurso{titulo}</h2>
    <p class="text-xs text-gray-500 mb-3">
      De onde saiu o pagamento, como o município declara ao SIOPE em cada salário.
    </p>
    <ul class="flex flex-col gap-3">
      {#each linhas as l (l.id)}
        <li class="flex items-center gap-3" data-testid="fonte-{l.id}">
          <div class="grow">
            <p class="text-sm text-gray-800">{l.rotulo}</p>
            <div class="h-2 bg-gray-100 rounded mt-1" aria-hidden="true">
              <div class="h-2 bg-blue-600 rounded" style="width: {Math.min(100, Math.max(0, l.pct))}%"></div>
            </div>
          </div>
          <span class="text-xs text-gray-500 w-14 text-right">{pct(l.pct)}%</span>
          <span class="text-sm font-medium text-gray-900 whitespace-nowrap w-36 text-right">{formatBRL(l.valor)}</span>
        </li>
      {/each}
    </ul>
    <p class="text-xs text-gray-500 mt-3" data-testid="aviso-minimo-legal">
      {#if comFundeb}
        Não é a verificação do mínimo de 70% exigido em lei; a parte da receita
        do Fundeb está no bloco "A folha e o Fundeb".
      {:else}
        Não é a verificação do mínimo de 70% exigido em lei: essa conta usa a
        receita do Fundeb do município, que só aparece no painel da rede.
      {/if}
    </p>
  </section>
{/if}
