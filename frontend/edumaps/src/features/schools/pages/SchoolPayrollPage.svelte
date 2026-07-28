<script>
  import { getSchoolPayroll } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import SchoolPayrollTable from "../components/SchoolPayrollTable.svelte";

  let payrollData = $state([]);
  let loading = $state(true);
  let error = $state(null);
  let schoolName = $state("");

  // Função para obter parâmetro da query string
  function getQueryParam(param) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(param);
  }

  async function loadPayroll() {
    const cod_inep = getQueryParam("inep");
    if (!cod_inep) {
      error = "Código INEP não informado na URL (?inep=XXXXXXXX).";
      loading = false;
      return;
    }

    loading = true;
    error = null;
    try {
      const data = await getSchoolPayroll(cod_inep);
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
          error = "Nenhum registro de pagamento encontrado para esta escola.";
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
      {:else if error}
        Erro ao carregar
      {:else}
        Folha de Pagamento – {schoolName}
      {/if}
    </h1>
    <p class="text-gray-600 text-sm mt-1">
      {#if !loading && !error && payrollData.length > 0}
        {payrollData.length} profissional(is) listado(s)
      {:else if !loading && !error && payrollData.length === 0}
        Nenhum profissional encontrado
      {/if}
    </p>
  </header>

  {#if loading}
    <div class="flex justify-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-700"></div>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-800 p-4 rounded-md">
      <p class="font-medium">Erro</p>
      <p class="text-sm">{error}</p>
    </div>
  {:else}
    <SchoolPayrollTable payrollData={payrollData} />
  {/if}
</div>
