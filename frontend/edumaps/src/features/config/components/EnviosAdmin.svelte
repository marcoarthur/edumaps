<!--
  Painel "Envios por e-mail" do Painel de Configuração (issue #216, onda 2),
  exibido ao selecionar uma folha canais.envio.* (mesmo padrão do
  RetencaoStatus): limites vigentes, volume por escola (hoje / 30 dias,
  falhas, saídas, envios em curso, suspensão) e as ações Suspender (diálogo
  com motivo obrigatório, 1..500) e Reativar (com confirmação). Após cada
  ação a tabela é recarregada.
-->
<script>
  import { onMount } from "svelte";
  import { getEnviosAdmin, suspenderEnvios, reativarEnvios } from "../api/configApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import ConfirmDialog from "@/shared/ui/components/ConfirmDialog.svelte";

  const MOTIVO_MAX = 500;

  let dados = $state(null);
  let carregando = $state(true);
  let erroStatus = $state(null);
  let mensagem = $state(null); // { tipo: "ok" | "erro", texto }

  // diálogo: { acao: "suspender" | "reativar", escola }
  let dialogo = $state(null);
  let motivo = $state("");
  let ocupado = $state(false);
  let erroDialogo = $state(null);

  const ativo = (v) => v === true || v === 1 || v === "1" || v === "true";
  const data = (iso) => (iso ? new Date(iso).toLocaleString("pt-BR") : "—");
  const num = (v) => (v == null ? "—" : Number(v).toLocaleString("pt-BR"));
  const nomeEscola = (e) => e?.escola_nome || `Escola ${e?.cod_inep}`;

  async function carregar() {
    erroStatus = null;
    try {
      dados = await getEnviosAdmin();
    } catch (err) {
      erroStatus = err?.message ?? "Não foi possível carregar os envios.";
    } finally {
      carregando = false;
    }
  }

  function abrir(acao, escola) {
    dialogo = { acao, escola };
    motivo = "";
    erroDialogo = null;
    mensagem = null;
  }

  function fechar() {
    dialogo = null;
    erroDialogo = null;
  }

  async function confirmar() {
    if (!dialogo) return;
    const { acao, escola } = dialogo;
    const texto = motivo.trim();
    if (acao === "suspender" && (texto.length < 1 || texto.length > MOTIVO_MAX)) {
      erroDialogo = `Informe o motivo da suspensão (até ${MOTIVO_MAX} caracteres).`;
      return;
    }
    ocupado = true;
    erroDialogo = null;
    try {
      if (acao === "suspender") {
        await suspenderEnvios(escola.cod_inep, texto);
        mensagem = {
          tipo: "ok",
          texto: `Envios de ${nomeEscola(escola)} suspensos. Os envios em andamento foram parados.`,
        };
      } else {
        const res = await reativarEnvios(escola.cod_inep);
        const n = Number(res?.envios_retomados ?? 0);
        mensagem = {
          tipo: "ok",
          texto: `Envios de ${nomeEscola(escola)} reativados. ${n === 1 ? "1 envio retomado" : `${n} envios retomados`}.`,
        };
      }
      dialogo = null;
      await carregar();
    } catch (err) {
      const status = err instanceof ApiError ? err.status : null;
      if (acao === "suspender" && status === 409) {
        erroDialogo = "Esta escola já está suspensa.";
        await carregar();
      } else if (acao === "reativar" && status === 404) {
        erroDialogo = "Esta escola não tem suspensão ativa — talvez já tenha sido reativada.";
        await carregar();
      } else if (status === 400) {
        erroDialogo = err.message || "Dados inválidos.";
      } else {
        erroDialogo =
          acao === "suspender"
            ? `Não foi possível suspender: ${err?.message ?? "erro desconhecido"}`
            : `Não foi possível reativar: ${err?.message ?? "erro desconhecido"}`;
      }
    } finally {
      ocupado = false;
    }
  }

  onMount(carregar);
</script>

<section class="mt-6 pt-4 border-t border-gray-100" aria-labelledby="envios-admin">
  <div class="flex items-center justify-between gap-2">
    <h3 id="envios-admin" class="font-semibold text-gray-800">Envios por e-mail das escolas</h3>
    <button
      type="button"
      onclick={carregar}
      disabled={ocupado}
      class="text-xs text-indigo-700 hover:underline disabled:opacity-40"
    >
      Atualizar
    </button>
  </div>

  {#if carregando}
    <p class="text-sm text-gray-500 mt-2">Carregando envios…</p>
  {:else if erroStatus && !dados}
    <p class="text-sm text-red-600 mt-2" role="alert">{erroStatus}</p>
  {:else if dados}
    <dl class="mt-3 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
      <dt class="text-gray-500">Envios</dt>
      <dd class="text-gray-800" data-testid="env-enabled">{ativo(dados.limites?.enabled) ? "ativados" : "desativados"}</dd>
      <dt class="text-gray-500">Servidor de e-mail</dt>
      <dd class="text-gray-800" data-testid="env-smtp">
        {ativo(dados.limites?.smtp_disponivel) ? "disponível" : "indisponível"}
      </dd>
      <dt class="text-gray-500">Ritmo</dt>
      <dd class="text-gray-800" data-testid="env-ritmo">{num(dados.limites?.ritmo_por_minuto)} e-mails/min</dd>
      <dt class="text-gray-500">Cota diária por escola</dt>
      <dd class="text-gray-800" data-testid="env-cota">{num(dados.limites?.cota_diaria)} e-mails</dd>
      <dt class="text-gray-500">Máximo por envio</dt>
      <dd class="text-gray-800" data-testid="env-max">{num(dados.limites?.max_destinatarios)} destinatários</dd>
    </dl>

    {#if erroStatus}
      <p class="text-sm text-red-600 mt-2" role="alert">{erroStatus}</p>
    {/if}

    {#if mensagem}
      <p
        class="text-sm mt-3 {mensagem.tipo === 'erro' ? 'text-red-600' : 'text-green-700'}"
        role={mensagem.tipo === "erro" ? "alert" : "status"}
        data-testid="env-mensagem"
      >
        {mensagem.texto}
      </p>
    {/if}

    {#if (dados.escolas ?? []).length === 0}
      <p class="mt-3 text-sm text-gray-500" data-testid="env-vazio">
        Nenhuma escola enviou e-mails nos últimos 30 dias.
      </p>
    {:else}
      <div class="mt-3 overflow-x-auto">
        <table class="w-full text-sm" data-testid="env-tabela">
          <caption class="sr-only">Volume de envios por escola nos últimos 30 dias</caption>
          <thead class="bg-gray-50 text-gray-500 text-xs uppercase">
            <tr>
              <th scope="col" class="text-left font-medium px-3 py-2">Escola</th>
              <th scope="col" class="text-right font-medium px-3 py-2">Hoje</th>
              <th scope="col" class="text-right font-medium px-3 py-2">30 dias</th>
              <th scope="col" class="text-right font-medium px-3 py-2">Falhas</th>
              <th scope="col" class="text-right font-medium px-3 py-2">Saídas</th>
              <th scope="col" class="text-right font-medium px-3 py-2">Em curso</th>
              <th scope="col" class="text-left font-medium px-3 py-2">Suspensão</th>
              <th scope="col" class="px-3 py-2"><span class="sr-only">Ações</span></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each dados.escolas as e (e.cod_inep)}
              <tr data-testid="env-escola">
                <td class="px-3 py-2">
                  <span class="block text-gray-900">{nomeEscola(e)}</span>
                  <span class="block text-[11px] text-gray-500">INEP {e.cod_inep}</span>
                </td>
                <td class="px-3 py-2 text-right tabular-nums">{num(e.enviados_hoje)}</td>
                <td class="px-3 py-2 text-right tabular-nums">{num(e.enviados_30d)}</td>
                <td class="px-3 py-2 text-right tabular-nums">{num(e.falhas_30d)}</td>
                <td class="px-3 py-2 text-right tabular-nums">{num(e.optouts_30d)}</td>
                <td class="px-3 py-2 text-right tabular-nums">{num(e.envios_em_curso)}</td>
                <td class="px-3 py-2 text-xs" data-testid="env-suspensao">
                  {#if e.suspensao}
                    <span class="inline-block rounded-full bg-red-100 text-red-700 px-2 py-0.5 text-[10px] font-semibold uppercase">suspensa</span>
                    <span class="block text-gray-700 mt-0.5">{e.suspensao.motivo}</span>
                    <span class="block text-gray-500">desde {data(e.suspensao.suspenso_em)}</span>
                  {:else}
                    <span class="text-gray-400">—</span>
                  {/if}
                </td>
                <td class="px-3 py-2 text-right">
                  {#if e.suspensao}
                    <button
                      type="button"
                      aria-label={`Reativar envios de ${nomeEscola(e)}`}
                      onclick={() => abrir("reativar", e)}
                      class="px-2 py-1 rounded text-xs text-indigo-700 hover:bg-indigo-50"
                    >Reativar</button>
                  {:else}
                    <button
                      type="button"
                      aria-label={`Suspender envios de ${nomeEscola(e)}`}
                      onclick={() => abrir("suspender", e)}
                      class="px-2 py-1 rounded text-xs text-red-600 hover:bg-red-50"
                    >Suspender</button>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  {/if}
</section>

{#if dialogo?.acao === "suspender"}
  <ConfirmDialog
    titulo="Suspender envios"
    descricao={`${nomeEscola(dialogo.escola)} não poderá disparar e-mails, e os envios agendados ou em andamento ficam parados até a reativação.`}
    confirmarRotulo="Suspender"
    perigo
    {ocupado}
    erro={erroDialogo}
    onConfirmar={confirmar}
    onCancelar={fechar}
    testid="suspender-envios-dialog"
  >
    <label class="block text-sm text-gray-700">
      Motivo (obrigatório)
      <textarea
        bind:value={motivo}
        rows="3"
        maxlength={MOTIVO_MAX}
        required
        aria-required="true"
        placeholder="Ex.: muitas falhas de entrega"
        class="mt-1 w-full px-3 py-2 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
      ></textarea>
      <span class="block text-[11px] text-gray-400 text-right">{motivo.length}/{MOTIVO_MAX}</span>
    </label>
  </ConfirmDialog>
{:else if dialogo?.acao === "reativar"}
  <ConfirmDialog
    titulo="Reativar envios"
    descricao={`${nomeEscola(dialogo.escola)} volta a poder enviar e-mails, e os envios suspensos são retomados.`}
    confirmarRotulo="Reativar"
    {ocupado}
    erro={erroDialogo}
    onConfirmar={confirmar}
    onCancelar={fechar}
    testid="reativar-envios-dialog"
  />
{/if}
