<!-- src/features/config/components/RetencaoStatus.svelte -->
<!--
  Painel "Retenção (LGPD)" do Painel de Configuração (issue #214), exibido ao
  selecionar uma folha canais.retencao.*: prazos vigentes, última execução
  (data e contagens por regra), se a limpeza diária está agendada e o botão
  "Executar agora" (execução avulsa, 202; não reagenda). Após executar, o
  status é recarregado.
-->
<script>
  import { onMount } from "svelte";
  import { getRetencaoStatus, executarRetencao } from "../api/configApi.js";

  let status = $state(null);
  let carregando = $state(true);
  let erroStatus = $state(null);
  let ocupado = $state(false);
  let mensagem = $state(null); // { tipo: "ok" | "erro", texto }

  const ativo = (v) => v === true || v === 1 || v === "1" || v === "true";
  const plural = (n, um, varios) => (n == null ? "—" : `${n} ${Number(n) === 1 ? um : varios}`);
  const data = (iso) => (iso ? new Date(iso).toLocaleString("pt-BR") : "—");

  // contagem por regra: número, ou objeto {contatos, inscricoes, ...} somado
  function contagem(v) {
    if (v == null) return 0;
    if (typeof v === "object") return Object.values(v).reduce((a, n) => a + (Number(n) || 0), 0);
    return Number(v) || 0;
  }

  async function carregarStatus() {
    erroStatus = null;
    try {
      status = await getRetencaoStatus();
    } catch (err) {
      erroStatus = err?.message ?? "Não foi possível carregar o status da retenção.";
    } finally {
      carregando = false;
    }
  }

  async function executar() {
    ocupado = true;
    mensagem = null;
    try {
      const res = await executarRetencao();
      mensagem = {
        tipo: "ok",
        texto: `Execução enfileirada${res?.job_id ? ` (job ${res.job_id})` : ""}. Atualize o status em instantes para ver o resultado.`,
      };
    } catch (err) {
      mensagem = { tipo: "erro", texto: `Falha ao executar a retenção: ${err?.message ?? "erro desconhecido"}` };
    } finally {
      await carregarStatus();
      ocupado = false;
    }
  }

  onMount(carregarStatus);
</script>

<section class="mt-6 pt-4 border-t border-gray-100" aria-labelledby="retencao-status">
  <div class="flex items-center justify-between gap-2">
    <h3 id="retencao-status" class="font-semibold text-gray-800">Retenção dos dados das listas</h3>
    <button
      type="button"
      onclick={carregarStatus}
      disabled={ocupado}
      class="text-xs text-indigo-700 hover:underline disabled:opacity-40"
    >
      Atualizar status
    </button>
  </div>

  {#if carregando}
    <p class="text-sm text-gray-500 mt-2">Carregando status da retenção…</p>
  {:else if erroStatus && !status}
    <p class="text-sm text-red-600 mt-2" role="alert">{erroStatus}</p>
  {:else if status}
    <dl class="mt-3 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
      <dt class="text-gray-500">Retenção</dt>
      <dd class="text-gray-800" data-testid="ret-enabled">{ativo(status.enabled) ? "ativada" : "desativada"}</dd>
      <dt class="text-gray-500">Agendamento</dt>
      <dd class="text-gray-800" data-testid="ret-agendado">
        {ativo(status.agendado) ? "agendada (diária)" : "não agendada"}
      </dd>
      <dt class="text-gray-500">Metadados técnicos</dt>
      <dd class="text-gray-800" data-testid="ret-metadados-dias">{plural(status.metadados_dias, "dia", "dias")}</dd>
      <dt class="text-gray-500">Nunca confirmados</dt>
      <dd class="text-gray-800" data-testid="ret-pendentes-dias">{plural(status.pendentes_dias, "dia", "dias")}</dd>
      <dt class="text-gray-500">Listas desativadas</dt>
      <dd class="text-gray-800" data-testid="ret-listas-meses">{plural(status.listas_inativas_meses, "mês", "meses")}</dd>
    </dl>

    <div class="mt-3 rounded-md border border-gray-200 bg-gray-50 p-3 text-sm" data-testid="ret-ultima">
      {#if status.ultima_execucao}
        <p class="text-gray-700">
          Última execução: <strong data-testid="ret-ultima-em">{data(status.ultima_execucao.em)}</strong>
        </p>
        <ul class="mt-1 text-gray-600 space-y-0.5">
          <li data-testid="ret-ultima-metadados">Metadados apagados: {contagem(status.ultima_execucao.metadados)}</li>
          <li data-testid="ret-ultima-pendentes">Nunca confirmados removidos: {contagem(status.ultima_execucao.pendentes)}</li>
          <li data-testid="ret-ultima-listas">Membros de listas desativadas removidos: {contagem(status.ultima_execucao.listas_inativas)}</li>
        </ul>
      {:else}
        <p class="text-gray-500">A retenção ainda não foi executada.</p>
      {/if}
    </div>

    {#if erroStatus}
      <p class="text-sm text-red-600 mt-2" role="alert">{erroStatus}</p>
    {/if}

    <div class="flex flex-wrap items-center gap-2 mt-3">
      <button
        type="button"
        onclick={executar}
        disabled={ocupado}
        class="px-3 h-9 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 disabled:opacity-40"
      >
        Executar agora
      </button>
      <span class="text-xs text-gray-500">Execução avulsa; não altera o agendamento diário.</span>
    </div>

    {#if mensagem}
      <p
        class="text-sm mt-2 {mensagem.tipo === 'erro' ? 'text-red-600' : 'text-green-700'}"
        role={mensagem.tipo === "erro" ? "alert" : "status"}
        data-testid="ret-mensagem"
      >
        {mensagem.texto}
      </p>
    {/if}
  {/if}
</section>
