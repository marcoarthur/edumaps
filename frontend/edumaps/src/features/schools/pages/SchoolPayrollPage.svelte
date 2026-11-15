<script>
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { getSchoolPayroll } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import SchoolPayrollTable from "../components/SchoolPayrollTable.svelte";

  let payrollData = $state([]);
  let loading = $state(true);
  let error = $state(null);
  let schoolName = $state("");
  // #422: 404 = não há folha desta escola (ausência, não erro)
  let semFolha = $state(false);
  let inep = $state(null);

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
    if (!cod_inep) {
      error = "Código INEP não informado na URL (?inep=XXXXXXXX).";
      loading = false;
      return;
    }

    loading = true;
    error = null;
    try {
      const data = await getSchoolPayroll(cod_inep, date || undefined);
      payrollData = data;
      if (data.length > 0) {
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
        Não há folha de pagamento desta escola para esta competência.
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
    <SchoolPayrollTable payrollData={payrollData} />
  {/if}
  <FonteDado tela="folha" class="pt-2" />
</div>
