<!-- src/features/gestor/components/relatorios/SecaoTabela.svelte -->
<script>
  // Seção de tabela (#219): tabela acessível (caption + th scope) com os
  // formatos do contrato; colunas numéricas alinhadas à direita.
  // Fase 2: `recolhida: true` põe a tabela num <details> fechado ("Ver
  // detalhes técnicos"); linha com `_destaque: true` sai realçada, com
  // "(sua escola)" para leitores de tela. Chaves iniciadas por "_" nunca são
  // colunas.
  import { formatarValor, ehNumerico } from "../../utils/relatorioFormatos.js";

  /** @type {{secao: {id: string, titulo?: string, colunas?: Array<object>, linhas?: Array<object>, nota?: string}}} */
  let { secao } = $props();

  const colunas = $derived((secao.colunas ?? []).filter((c) => !String(c?.id ?? "").startsWith("_")));
  const linhas = $derived(secao.linhas ?? []);
  // Tabelas longas (ex.: as ~1.100 escolas da capital paulista) rolam dentro
  // da própria caixa, com o cabeçalho fixo, em vez de esticar a página.
  const LIMITE_LINHAS_SEM_ROLAGEM = 25;
  const longa = $derived(linhas.length > LIMITE_LINHAS_SEM_ROLAGEM);
</script>

{#snippet tabela()}
  <div
    class="overflow-x-auto bg-white border border-gray-200 rounded-card shadow-card print:shadow-none print:overflow-visible {longa
      ? 'max-h-[36rem] overflow-y-auto print:max-h-none'
      : 'print:break-inside-avoid'}"
    data-longa={longa ? "true" : undefined}
  >
    <table class="min-w-full text-sm">
      <caption class="text-left text-lg font-semibold text-gray-900 px-4 pt-3 pb-2">
        {secao.titulo ?? "Tabela"}
      </caption>
      <thead class="bg-gray-50 text-gray-600" class:sticky={longa} class:top-0={longa}>
        <tr>
          {#each colunas as col (col.id)}
            <th
              scope="col"
              class="font-medium px-4 py-2"
              class:text-right={ehNumerico(col.formato)}
              class:text-left={!ehNumerico(col.formato)}
            >{col.rotulo ?? col.id}</th>
          {/each}
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-100">
        {#each linhas as linha, i (i)}
          <tr
            class:bg-amber-50={linha?._destaque === true}
            class:font-semibold={linha?._destaque === true}
            data-destaque={linha?._destaque === true ? "true" : undefined}
          >
            {#each colunas as col, j (col.id)}
              {#if j === 0}
                <th scope="row" class="font-medium text-gray-900 px-4 py-2" class:text-right={ehNumerico(col.formato)} class:text-left={!ehNumerico(col.formato)}>
                  {formatarValor(linha[col.id], col.formato)}{#if linha?._destaque === true}{" "}<span class="sr-only">(sua escola)</span><span aria-hidden="true" class="ml-1 text-xs font-medium text-amber-800">★ sua escola</span>{/if}
                </th>
              {:else}
                <td class="px-4 py-2 text-gray-700" class:text-right={ehNumerico(col.formato)}>
                  {formatarValor(linha[col.id], col.formato)}
                </td>
              {/if}
            {/each}
          </tr>
        {:else}
          <tr><td class="px-4 py-4 text-center text-gray-500" colspan={colunas.length || 1}>Sem dados para este recorte.</td></tr>
        {/each}
      </tbody>
    </table>
  </div>
  {#if secao.nota}
    <p class="text-xs text-gray-500">{secao.nota}</p>
  {/if}
{/snippet}

<section class="space-y-2" data-testid="secao-tabela" data-recolhida={secao.recolhida === true ? "true" : undefined}>
  {#if secao.recolhida === true}
    <details class="space-y-2" data-testid="tabela-recolhida">
      <summary class="cursor-pointer text-sm text-blue-700 hover:underline print:hidden">
        Ver detalhes técnicos{#if secao.titulo}{": "}<span class="font-medium">{secao.titulo}</span>{/if}
      </summary>
      <div class="mt-2 space-y-2">{@render tabela()}</div>
    </details>
  {:else}
    {@render tabela()}
  {/if}
</section>
