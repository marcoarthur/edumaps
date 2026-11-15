<script>
  // src/features/schools/components/panel/FinanceAusencia.svelte
  //
  // #422: sem folha para a escola, dizer POR QUE e ONDE há folha. Ausência
  // não é erro nem zero (#154). A busca no SIOPE só é oferecida ao gestor da
  // escola logado (card acima, na página); aqui só se diz que existe.
  let {
    motivo = null,
    rede = null,
    cobertura = null,
    gestorDaEscola = false,
  } = $props();

  const TEXTOS = {
    escola_inexistente: "Não encontramos esta escola no Censo Escolar.",
    nao_municipal:
      "A folha vem do SIOPE, que traz só a remuneração da rede municipal. Esta escola não é da rede municipal, então não há folha dela aqui.",
    escola_sem_folha:
      "O município tem folha carregada, mas o SIOPE não traz profissionais desta escola nem um total da Secretaria de Educação.",
    municipio_sem_carga: "Ainda não há folha deste município na plataforma.",
  };

  const texto = $derived(TEXTOS[motivo] ?? "Sem dados de folha de pagamento para esta escola.");
  const lista = $derived(cobertura?.lista ?? []);

  function periodo(item) {
    if (!item.ano_inicial) return "";
    return item.ano_inicial === item.ano_final
      ? `${item.ano_inicial}`
      : `${item.ano_inicial}–${item.ano_final}`;
  }

  function nome(item) {
    if (!item.municipio) return `município ${item.cod_municipio}`;
    return item.uf ? `${item.municipio} (${item.uf})` : item.municipio;
  }

  function detalhe(item) {
    return item.escolas > 0
      ? `${item.escolas} escola(s) com folha própria`
      : "só o total da Secretaria (o SIOPE não detalha por escola)";
  }
</script>

<section
  class="bg-white border border-gray-200 rounded-card shadow-card p-6 space-y-3"
  aria-label="Sem folha de pagamento"
>
  <h2 class="text-base font-semibold text-gray-900">Sem folha de pagamento para esta escola</h2>
  <p class="text-sm text-gray-700">{texto}</p>
  {#if rede && motivo === "nao_municipal"}
    <p class="text-xs text-gray-500">Rede desta escola: {rede}.</p>
  {/if}

  {#if motivo === "municipio_sem_carga" && !gestorDaEscola}
    <p class="text-sm text-gray-600">
      O gestor da escola, com login, pode pedir a busca desses dados no SIOPE.
    </p>
  {/if}

  {#if lista.length > 0}
    <div class="text-sm text-gray-600">
      <p>
        Hoje há folha de pagamento de {lista.length}
        {lista.length === 1 ? "município" : "municípios"}:
      </p>
      <ul class="list-disc pl-5 mt-1 space-y-0.5">
        {#each lista as item (item.cod_municipio)}
          <li>{nome(item)}, {periodo(item)}: {detalhe(item)}</li>
        {/each}
      </ul>
    </div>
  {:else if cobertura}
    <p class="text-sm text-gray-600">Ainda não há folha de nenhum município na plataforma.</p>
  {/if}
</section>
