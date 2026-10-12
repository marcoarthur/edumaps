<!-- src/features/gestor/components/envios/EnvioDetalhe.svelte -->
<script>
  // Detalhe de um envio por e-mail (issue #216): estado, contadores ao vivo,
  // destinatários mascarados (paginados, filtro por estado) e "Cancelar".
  // Enquanto o envio está agendado/enviando, recarrega a cada 5 s; o polling
  // para quando o estado muda ou o componente sai da tela.
  import { onMount } from "svelte";
  import {
    getEnvio,
    listDestinatarios,
    cancelarEnvio,
  } from "../../api/gestorEnviosApi.js";
  import {
    ESTADOS_AO_VIVO,
    ESTADOS_CANCELAVEIS,
    ESTADOS_DESTINATARIO,
    rotuloDestinatario,
    rotuloOperacao,
    mensagemErroEnvio,
    formatarDataHora,
  } from "../../constants/envios.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import ConfirmDialog from "@/shared/ui/components/ConfirmDialog.svelte";
  import EnvioSelo from "./EnvioSelo.svelte";

  const POLLING_MS = 5000;
  const POR_PAGINA = 20;

  /**
   * @type {{
   *   inep: string|number,
   *   envioId: number,
   *   onVoltar?: () => void,
   *   onAtualizado?: (envio: object) => void,
   *   onSessaoExpirada?: () => void,
   * }}
   */
  let {
    inep,
    envioId,
    onVoltar = () => {},
    onAtualizado = () => {},
    onSessaoExpirada = () => {},
  } = $props();

  let envio = $state(null);
  let carregando = $state(true);
  let erro = $state(null);

  let destinatarios = $state({ items: [], total: 0, page: 1, per_page: POR_PAGINA });
  let filtro = $state("");
  let pagina = $state(1);
  let destCarregando = $state(false);

  let cancelando = $state(false);
  let cancelandoOcupado = $state(false);
  let erroCancelar = $state(null);

  const aoVivo = $derived(Boolean(envio && ESTADOS_AO_VIVO.has(envio.status)));
  const totalPaginas = $derived(
    Math.max(1, Math.ceil((destinatarios.total ?? 0) / (destinatarios.per_page || POR_PAGINA))),
  );

  function tratarErro(err, padrao) {
    if (err instanceof ApiError && err.status === 401) {
      onSessaoExpirada();
      return null;
    }
    return mensagemErroEnvio(err, padrao);
  }

  async function carregarEnvio() {
    try {
      envio = await getEnvio(inep, envioId);
      onAtualizado(envio);
      erro = null;
    } catch (err) {
      const m = tratarErro(err, "Não foi possível carregar o envio.");
      if (m) erro = m;
    }
  }

  async function carregarDestinatarios() {
    destCarregando = true;
    try {
      destinatarios = await listDestinatarios(inep, envioId, {
        status: filtro || undefined,
        page: pagina,
        per_page: POR_PAGINA,
      });
    } catch (err) {
      const m = tratarErro(err, "Não foi possível carregar os destinatários.");
      if (m) addToast(m, "error");
    } finally {
      destCarregando = false;
    }
  }

  async function recarregar() {
    await Promise.all([carregarEnvio(), carregarDestinatarios()]);
  }

  function mudarFiltro(valor) {
    filtro = valor;
    pagina = 1;
    carregarDestinatarios();
  }

  function irPagina(p) {
    pagina = p;
    carregarDestinatarios();
  }

  async function confirmarCancelar() {
    cancelandoOcupado = true;
    erroCancelar = null;
    try {
      envio = await cancelarEnvio(inep, envioId);
      onAtualizado(envio);
      cancelando = false;
      addToast("Envio cancelado. Quem ainda não recebeu não vai receber.", "success");
      await carregarDestinatarios();
    } catch (err) {
      const m = tratarErro(err, "Não foi possível cancelar o envio.");
      if (m) erroCancelar = m;
      else cancelando = false;
    } finally {
      cancelandoOcupado = false;
    }
  }

  // polling: só enquanto agendado/enviando; o cleanup para ao mudar o estado
  // ou ao desmontar
  $effect(() => {
    if (!aoVivo) return;
    const timer = setInterval(recarregar, POLLING_MS);
    return () => clearInterval(timer);
  });

  onMount(async () => {
    await recarregar();
    carregando = false;
  });

  const CONTADORES = [
    ["destinatarios", "Destinatários"],
    ["enviados", "Enviados"],
    ["pendentes", "Pendentes"],
    ["falhas", "Falhas"],
    ["ignorados", "Ignorados"],
    ["optouts", "Saídas"],
    ["cancelados", "Cancelados"],
  ];
</script>

<section class="space-y-4" data-testid="envio-detalhe">
  <div class="flex items-center justify-between gap-2">
    <button
      type="button"
      onclick={onVoltar}
      class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
    >← Voltar aos envios</button>
    {#if envio && ESTADOS_CANCELAVEIS.has(envio.status)}
      <button
        type="button"
        onclick={() => { erroCancelar = null; cancelando = true; }}
        class="px-3 py-1.5 rounded-md bg-red-600 text-white text-xs font-semibold hover:bg-red-700"
      >Cancelar envio</button>
    {/if}
  </div>

  {#if carregando && !envio}
    <p class="text-sm text-gray-500">Carregando envio…</p>
  {:else if erro && !envio}
    <p class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4" role="alert">{erro}</p>
  {:else if envio}
    <div class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-3">
      <div class="flex flex-wrap items-start justify-between gap-2">
        <div class="min-w-0">
          <h2 class="text-base font-semibold text-gray-900">{envio.assunto}</h2>
          <p class="text-xs text-gray-500">
            {rotuloOperacao(envio.operacao)} · para
            {envio.alvo?.nome ?? "alvo excluído"}
            ({envio.alvo?.tipo === "segmento" ? "lista dinâmica" : "lista"})
          </p>
        </div>
        <div class="flex items-center gap-2">
          {#if aoVivo}
            <span class="text-[11px] text-indigo-600" data-testid="ao-vivo">atualizando…</span>
          {/if}
          <EnvioSelo status={envio.status} />
        </div>
      </div>

      <dl class="grid grid-cols-2 sm:grid-cols-4 gap-3" data-testid="envio-contadores">
        {#each CONTADORES as [chave, rotulo] (chave)}
          <div class="rounded-md bg-gray-50 p-2">
            <dt class="text-[11px] text-gray-500">{rotulo}</dt>
            <dd class="text-lg font-semibold text-gray-900" data-testid={`contador-${chave}`}>
              {envio.contadores?.[chave] ?? 0}
            </dd>
          </div>
        {/each}
      </dl>

      <dl class="grid sm:grid-cols-2 gap-x-4 gap-y-1 text-xs text-gray-600">
        {#if envio.agendado_para}
          <div><dt class="inline">Agendado para:</dt> <dd class="inline">{formatarDataHora(envio.agendado_para)}</dd></div>
        {/if}
        {#if envio.iniciado_em}
          <div><dt class="inline">Iniciado em:</dt> <dd class="inline">{formatarDataHora(envio.iniciado_em)}</dd></div>
        {/if}
        {#if envio.concluido_em}
          <div><dt class="inline">Concluído em:</dt> <dd class="inline">{formatarDataHora(envio.concluido_em)}</dd></div>
        {/if}
        {#if envio.cancelado_em}
          <div><dt class="inline">Cancelado em:</dt> <dd class="inline">{formatarDataHora(envio.cancelado_em)}</dd></div>
        {/if}
        <div><dt class="inline">Criado em:</dt> <dd class="inline">{formatarDataHora(envio.created_at)}</dd></div>
      </dl>
      {#if envio.status === "pausado_cota"}
        <p class="text-xs text-amber-800 bg-amber-50 rounded p-2">
          A cota de hoje acabou. O envio continua automaticamente amanhã.
        </p>
      {:else if envio.status === "suspenso"}
        <p class="text-xs text-red-700 bg-red-50 rounded p-2">
          Os envios da escola foram suspensos pela administração da plataforma.
        </p>
      {/if}
    </div>

    <div class="space-y-2">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h3 class="text-sm font-semibold text-gray-900">Destinatários ({destinatarios.total})</h3>
        <label class="flex items-center gap-2 text-xs text-gray-600">
          Estado
          <select
            value={filtro}
            onchange={(e) => mudarFiltro(e.currentTarget.value)}
            aria-label="Filtrar destinatários por estado"
            class="h-8 px-2 rounded-md border border-gray-300 text-xs bg-white"
          >
            {#each ESTADOS_DESTINATARIO as f (f.valor)}
              <option value={f.valor}>{f.rotulo}</option>
            {/each}
          </select>
        </label>
      </div>
      <div class="rounded-card bg-white border border-gray-200 shadow-card" data-testid="destinatarios-tabela">
        {#if destCarregando && destinatarios.items.length === 0}
          <p class="p-4 text-sm text-gray-500">Carregando destinatários…</p>
        {:else if destinatarios.items.length === 0}
          <p class="p-4 text-sm text-gray-400">
            {envio.status === "rascunho" ? "Os destinatários aparecem depois do disparo." : "Nenhum destinatário neste estado."}
          </p>
        {:else}
          <table class="w-full text-sm">
            <thead class="bg-gray-50 text-gray-500 text-xs uppercase">
              <tr>
                <th class="text-left font-medium px-4 py-2">Nome</th>
                <th class="text-left font-medium px-4 py-2">E-mail</th>
                <th class="text-left font-medium px-4 py-2">Estado</th>
                <th class="text-left font-medium px-4 py-2 hidden sm:table-cell">Quando</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each destinatarios.items as d (d.id)}
                <tr data-testid="destinatario-row">
                  <td class="px-4 py-2 text-gray-900">{d.nome ?? "—"}</td>
                  <td class="px-4 py-2 text-gray-600 font-mono text-xs">{d.email ?? "—"}</td>
                  <td class="px-4 py-2 text-xs">
                    {rotuloDestinatario(d.status)}
                    {#if d.erro}<span class="block text-red-600">{d.erro}</span>{/if}
                  </td>
                  <td class="px-4 py-2 text-xs text-gray-500 hidden sm:table-cell">{formatarDataHora(d.processado_em)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
      {#if totalPaginas > 1}
        <nav class="flex items-center justify-end gap-2 text-xs" aria-label="Páginas de destinatários">
          <button
            type="button"
            disabled={pagina <= 1}
            onclick={() => irPagina(pagina - 1)}
            class="px-2 py-1 rounded border border-gray-300 disabled:opacity-40"
          >Anterior</button>
          <span>Página {pagina} de {totalPaginas}</span>
          <button
            type="button"
            disabled={pagina >= totalPaginas}
            onclick={() => irPagina(pagina + 1)}
            class="px-2 py-1 rounded border border-gray-300 disabled:opacity-40"
          >Próxima</button>
        </nav>
      {/if}
    </div>
  {/if}
</section>

{#if cancelando}
  <ConfirmDialog
    titulo="Cancelar envio"
    descricao="Quem ainda não recebeu o e-mail não vai receber. Quem já recebeu não é afetado. Não pode ser desfeito."
    confirmarRotulo="Cancelar envio"
    cancelarRotulo="Voltar"
    perigo
    ocupado={cancelandoOcupado}
    erro={erroCancelar}
    onConfirmar={confirmarCancelar}
    onCancelar={() => (cancelando = false)}
    testid="cancelar-envio-dialog"
  />
{/if}
