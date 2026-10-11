<!-- src/features/admin/pages/AdminTelemetryPage.svelte -->
<script>
  // Painel de Administração — fluxo de acesso (telemetria de sessão). Exige
  // sessão de gestor com access_role = 'admin'. Os KPIs vêm de
  // GET /api/admin/telemetry/overview e refletem os eventos já persistidos
  // (flush ~30s do EventLogger): o painel é near-real-time e se atualiza sozinho.
  import { onMount } from "svelte";
  import { getTelemetryOverview } from "../api/telemetryApi.js";
  import { fetchMe, logoutGestor } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";
  import { LOGIN_CARDS } from "../constants/windows.js";
  import TelemetryWindows from "../components/TelemetryWindows.svelte";
  import TelemetryStatCard from "../components/TelemetryStatCard.svelte";
  import TelemetryRoutesTable from "../components/TelemetryRoutesTable.svelte";
  import TelemetryTimeseries from "../components/TelemetryTimeseries.svelte";

  const REFRESH_MS = 30000;

  let carregando = $state(true);
  let atualizando = $state(false);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);

  let data = $state(null);
  let janela = $state("24h");
  let atualizadoEm = $state(null);

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    if (err instanceof ApiError && err.status === 403) {
      semPermissao = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregar(j = janela) {
    atualizando = true;
    try {
      data = await getTelemetryOverview(j);
      error = null;
      atualizadoEm = new Date();
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a telemetria.");
      if (msg) error = msg;
    } finally {
      atualizando = false;
    }
  }

  function selecionarJanela(j) {
    if (j === janela) return;
    janela = j;
    carregar(j);
  }

  function verificarAdmin() {
    return fetchMe().then((me) => {
      if (me.access_role !== "admin") {
        semPermissao = true;
        carregando = false;
        return;
      }
      return carregar().finally(() => {
        carregando = false;
      });
    });
  }

  onMount(() => {
    if (restaurarSessao()) {
      verificarAdmin().catch((err) => {
        carregando = false;
        if (err instanceof ApiError && err.status === 401) precisaLogin = true;
        else error = err?.message ?? "Não foi possível carregar a telemetria.";
      });
    } else {
      precisaLogin = true;
      carregando = false;
    }

    const timer = setInterval(() => {
      if (!precisaLogin && !semPermissao && !atualizando) carregar();
    }, REFRESH_MS);
    return () => clearInterval(timer);
  });

  function onLogin() {
    restaurarSessao();
    carregando = true;
    semPermissao = false;
    precisaLogin = false;
    verificarAdmin().catch(() => {
      carregando = false;
    });
  }

  function sair() {
    logoutGestor().finally(() => {
      clearSessaoToken();
      precisaLogin = true;
    });
  }
</script>

<div class="space-y-5">
  {#if !precisaLogin && !semPermissao}
    <header class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Painel de Administração</h1>
        <p class="text-sm text-gray-600 mt-1">
          Fluxo de acesso e uso da plataforma (telemetria de sessão), em tempo quase real.
        </p>
      </div>
      <div class="flex items-center gap-3">
        {#if atualizadoEm}
          <span class="text-xs text-gray-500">
            Atualizado às {atualizadoEm.toLocaleTimeString("pt-BR")}
          </span>
        {/if}
        <button
          type="button"
          onclick={() => carregar()}
          disabled={atualizando}
          class="px-4 py-2 bg-brand-700 text-white text-sm font-medium rounded-md hover:bg-brand-800 disabled:opacity-50"
        >
          {atualizando ? "Atualizando…" : "Atualizar agora"}
        </button>
        <button
          type="button"
          onclick={sair}
          class="px-4 py-2 border border-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-100"
        >
          Sair
        </button>
      </div>
    </header>
  {/if}

  {#if carregando && !data}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando telemetria…</p>
    </div>
  {:else if precisaLogin}
    <GestorLoginCard
      onLogin={onLogin}
      titulo="Entrar como administrador"
      mensagem="Entre para acessar o painel de administração."
      descricao="Use o e-mail e a senha de um gestor com perfil de administração."
    />
  {:else if semPermissao}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      Esta área é restrita a administradores da instalação.
    </div>
  {:else if error && !data}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">{error}</div>
  {:else if data}
    {#if error}
      <div class="bg-amber-50 border border-amber-200 text-amber-800 text-sm rounded-md p-3">
        {error}
      </div>
    {/if}

    <section class="space-y-2">
      <h2 class="text-sm font-semibold text-gray-700">Logins de gestores</h2>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {#each LOGIN_CARDS as c (c.key)}
          <TelemetryStatCard
            label={c.label}
            value={data.logins[c.key] ?? 0}
            tone="brand"
            hint="gestores distintos"
          />
        {/each}
      </div>
    </section>

    <section class="space-y-2">
      <div class="flex items-center justify-between flex-wrap gap-2">
        <h2 class="text-sm font-semibold text-gray-700">Atividade na janela</h2>
        <TelemetryWindows value={janela} onSelect={selecionarJanela} />
      </div>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
        <TelemetryStatCard label="Sessões ativas" value={data.sessions.active} />
        <TelemetryStatCard label="Logadas" value={data.sessions.logged} tone="positive" />
        <TelemetryStatCard label="Anônimas" value={data.sessions.anonymous} tone="muted" />
        <TelemetryStatCard label="Buscas" value={data.searches} />
        <TelemetryStatCard label="Eventos" value={data.events} />
      </div>
    </section>

    <TelemetryTimeseries series={data.series} granularity={data.granularity} />

    <TelemetryRoutesTable routes={data.top_routes} />
  {/if}
</div>
