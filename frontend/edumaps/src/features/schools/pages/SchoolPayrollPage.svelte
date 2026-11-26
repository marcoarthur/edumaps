<script>
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { getSchoolPayroll, getSecretariaPayroll } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import SchoolPayrollTable from "../components/SchoolPayrollTable.svelte";

  let payrollData = $state([]);
  let loading = $state(true);
  let error = $state(null);
  let schoolName = $state("");
  // #422: 404 = não há folha desta escola (ausência, não erro)
  let semFolha = $state(false);
  let inep = $state(null);
  // #585 (QE-01 da P2): a folha do total da Secretaria (sem escola informada)
  let secretaria = $state(false);
  // Lista grande (a Secretaria de Cuiabá passa de 12 mil linhas por mês):
  // filtro por nome e 100 linhas por página.
  const POR_PAGINA = 100;
  let filtro = $state("");
  let pagina = $state(0);
  // #598 (QB-02 da P2): filtro pela situação da linha (a do mês) e pela marca
  // "abaixo do piso no ano" (a regra da contagem da rede, calculada no backend)
  let situacao = $state("");
  let soAbaixo = $state(false);
  const sitDe = (p) => (p.situacao === "Efetivo" ? "efetivo" : p.situacao === "Temporário" ? "temporario" : "outros");
  const situacoes = $derived(new Set(payrollData.map(sitDe)));
  // pessoas (CPF mascarado e nome), não linhas: há quem tenha dois pagamentos no mês
  const marcados = $derived(new Set(payrollData.filter((p) => p.abaixo_piso_ano).map((p) => `${p.cpf}|${p.nome_profissional}`)).size);
  const temPiso = $derived(payrollData.some((p) => p.base_40h_ano != null));
  const temFiltros = $derived(payrollData.length > POR_PAGINA || marcados > 0 || situacoes.size > 1);
  const filtrados = $derived(
    payrollData.filter((p) =>
      (!filtro.trim() || (p.nome_profissional ?? "").toLowerCase().includes(filtro.trim().toLowerCase()))
      && (!situacao || sitDe(p) === situacao)
      && (!soAbaixo || p.abaixo_piso_ano)),
  );
  const paginas = $derived(Math.max(1, Math.ceil(filtrados.length / POR_PAGINA)));
  const visiveis = $derived(filtrados.slice(pagina * POR_PAGINA, (pagina + 1) * POR_PAGINA));
  // #536 (QO-02 da P5): letras que já chegaram perdidas no arquivo do SIOPE
  // aparecem como "?" no nome.
  const nomesIlegiveis = $derived(payrollData.filter((p) => (p.nome_profissional ?? "").includes("?")).length);

  // Função para obter parâmetro da query string
  function getQueryParam(param) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(param);
  }

  async function loadPayroll() {
    const cod_inep = getQueryParam("inep");
    inep = cod_inep;
    semFolha = false;
    const date = getQueryParam("date");
    secretaria = getQueryParam("secretaria") === "1";
    filtro = "";
    pagina = 0;
    if (!cod_inep) {
      error = "Código INEP não informado na URL (?inep=XXXXXXXX).";
      loading = false;
      return;
    }

    loading = true;
    error = null;
    try {
      const data = secretaria
        ? await getSecretariaPayroll(cod_inep, date || undefined)
        : await getSchoolPayroll(cod_inep, date || undefined);
      payrollData = data;
      if (secretaria) {
        schoolName = "total da Secretaria (sem escola)";
      } else if (data.length > 0) {
        schoolName = data[0].escola || `Escola ${cod_inep}`;
      } else {
        schoolName = `Escola ${cod_inep}`;
      }
    } catch (err) {
      payrollData = [];
      if (err instanceof ApiError) {
        if (err.status === 404) {
          semFolha = true;
        } else {
          error = err.message;
        }
      } else {
        error = "Erro inesperado ao carregar os dados.";
      }
    } finally {
      loading = false;
    }
  }

  // Carrega ao montar e também quando a URL mudar (ex: navegação)
  $effect(() => {
    loadPayroll();
  });
</script>

<!-- Template idêntico ao anterior -->
<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">
      {#if loading}
        Carregando folha de pagamento...
      {:else if semFolha}
        Folha de pagamento
      {:else if error}
        Erro ao carregar
      {:else}
        Folha de Pagamento – {schoolName}
      {/if}
    </h1>
    <p class="text-gray-600 text-sm mt-1">
      {#if !loading && !error && payrollData.length > 0}
        {payrollData.length} profissional(is) listado(s)
      {:else if !loading && !error && !semFolha && payrollData.length === 0}
        Nenhum profissional encontrado
      {/if}
    </p>
  </header>

  {#if loading}
    <div class="flex justify-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-700"></div>
    </div>
  {:else if semFolha}
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-6 space-y-2">
      <p class="text-sm text-gray-700">
        {secretaria ? "Não há folha no total da Secretaria do município neste mês." : "Não há folha de pagamento desta escola para este mês."}
      </p>
      <p class="text-sm text-gray-600">
        O
        <a class="text-brand-700 underline" href={`/escola/financeiro?inep=${inep}`}>painel financeiro</a>
        diz por quê e de quais municípios há folha.
      </p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-800 p-4 rounded-md">
      <p class="font-medium">Erro</p>
      <p class="text-sm">{error}</p>
    </div>
  {:else}
    {#if nomesIlegiveis > 0}
      <p class="text-xs text-gray-600" data-testid="nota-nome-ilegivel">
        {nomesIlegiveis === 1 ? "Um nome tem" : `${nomesIlegiveis} nomes têm`} "?" no lugar de uma letra: ela já veio
        ilegível no arquivo do SIOPE e não pôde ser recuperada de outro mês do mesmo profissional.
      </p>
    {/if}
    {#if secretaria}
      <p class="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-4 py-3" role="note" data-testid="aviso-folha-secretaria">
        Estas pessoas foram declaradas ao SIOPE no total da Secretaria, sem escola informada: o SIOPE não diz em que
        unidade cada uma trabalha. Pode haver pagamentos parciais (férias, complementos, rescisões).
      </p>
    {/if}
    {#if marcados > 0}
      <p class="text-sm text-gray-700" data-testid="nota-piso-folha">
        {marcados.toLocaleString("pt-BR")} {marcados === 1 ? "profissional do magistério fica" : "profissionais do magistério ficam"} abaixo do
        piso no ano nesta lista: a base por 40 horas no mês típico, em toda a folha do município (escolas e Secretaria),
        entre quem recebeu 3 meses ou mais, a mesma regra da contagem do painel. Não é a verificação legal do piso
        (complementos, jornada, licenças, reajuste pago com atraso).
      </p>
    {/if}
    {#if temFiltros}
      <div class="flex flex-wrap items-center gap-3 text-sm" data-testid="paginacao-folha">
        <label class="text-gray-600" for="filtro-nome">Buscar pelo nome</label>
        <input id="filtro-nome" type="search" bind:value={filtro} oninput={() => (pagina = 0)}
          class="border border-gray-300 rounded-md px-2 py-1 text-sm" />
        <label class="text-gray-600" for="filtro-situacao">Situação</label>
        <select id="filtro-situacao" bind:value={situacao} onchange={() => (pagina = 0)} data-testid="filtro-situacao"
          class="border border-gray-300 rounded-md px-2 py-1 text-sm">
          <option value="">todas</option>
          <option value="efetivo">efetivo</option>
          <option value="temporario">temporário</option>
          <option value="outros">outras</option>
        </select>
        {#if marcados > 0}
          <label class="inline-flex items-center gap-1 text-gray-700">
            <input type="checkbox" bind:checked={soAbaixo} onchange={() => (pagina = 0)} data-testid="filtro-abaixo-piso" />
            só abaixo do piso no ano
          </label>
        {/if}
        <span class="text-gray-600">{filtrados.length.toLocaleString("pt-BR")} {filtrados.length === 1 ? "registro" : "registros"} · página {pagina + 1} de {paginas}</span>
        <button type="button" class="px-2 py-1 border rounded-md disabled:opacity-50" disabled={pagina === 0} onclick={() => (pagina -= 1)}>← Anterior</button>
        <button type="button" class="px-2 py-1 border rounded-md disabled:opacity-50" disabled={pagina >= paginas - 1} onclick={() => (pagina += 1)}>Próxima →</button>
      </div>
    {/if}
    <SchoolPayrollTable payrollData={visiveis} mostrarPiso={temPiso} />
  {/if}
  <FonteDado tela="folha" class="pt-2" />
</div>
