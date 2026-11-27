<script>
  // src/features/schools/components/panel/FolhaFundeb.svelte
  // #611 (QE-02 da P2): a folha e o Fundeb no painel da rede. Quanto da
  // receita do Fundeb do município foi pago na remuneração pela parcela de
  // 70% e quanto a adequação ao piso somaria. Não é a verificação legal.
  import { textosFolhaFundeb } from "../../utils/redeFolha.js";
  import { dataBR } from "@/features/fontes/utils.js";

  /** @type {{ fundeb: object|null, ano?: number|null }} */
  let { fundeb = null, ano = null } = $props();

  const textos = $derived(textosFolhaFundeb(fundeb, ano));
</script>

{#if textos.length}
  <section class="bg-white border border-gray-200 rounded-card shadow-card p-5" data-testid="folha-fundeb">
    <h2 class="text-base font-bold text-gray-900 mb-2">A folha e o Fundeb</h2>
    {#each textos as t, i (i)}
      <p class="text-sm text-gray-800 mb-2" data-testid="folha-fundeb-{i}">{t}</p>
    {/each}
    <p class="text-xs text-gray-500 mt-1" data-testid="folha-fundeb-aviso">
      Não é a verificação do mínimo de 70% exigido em lei: ela usa a despesa
      liquidada e uma base que não conta toda a complementação da União (como a
      VAAR). A remuneração é a que o município declara ao SIOPE. Receita:
      {fundeb.fonte}{#if fundeb.carregado_em}, carregada em {dataBR(fundeb.carregado_em)}{/if}.
    </p>
  </section>
{/if}
