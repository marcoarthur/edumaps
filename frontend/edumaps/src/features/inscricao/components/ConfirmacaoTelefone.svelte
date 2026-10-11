<!-- src/features/inscricao/components/ConfirmacaoTelefone.svelte -->
<script module>
  // Polling do estado da confirmação (issue #212): a cada 3s, por até 5 min.
  // Exportados para os testes (e sobrescrevíveis por props).
  export const POLL_INTERVALO_MS = 3000;
  export const POLL_DURACAO_MS = 5 * 60 * 1000;
</script>

<script>
  // Passo 2 da autoinscrição: "Confirme seu telefone". Exibido quando a resposta
  // do POST traz `confirmacao`. Oferece os canais disponíveis (Telegram por deep
  // link; WhatsApp por código de 6 dígitos) e consulta o estado periodicamente,
  // porque a confirmação pelo Telegram acontece fora desta página.
  import { onMount, onDestroy, untrack } from "svelte";
  import {
    estadoConfirmacao,
    enviarCodigoWhatsapp,
    verificarCodigoWhatsapp,
  } from "../api/canaisPublicApi.js";
  import { ApiError } from "@/shared/api/client.js";

  /**
   * @type {{
   *   confirmacao: {ref?: string, estado: string, expira_em?: string, canais?: Array<{canal: string, url?: string}>},
   *   intervaloPolling?: number,
   *   duracaoPolling?: number,
   * }}
   */
  let {
    confirmacao,
    intervaloPolling = POLL_INTERVALO_MS,
    duracaoPolling = POLL_DURACAO_MS,
  } = $props();

  // O passo é uma fotografia da resposta do POST: a ref não muda durante a vida
  // do componente (nova inscrição = novo componente).
  const inicial = untrack(() => confirmacao) ?? {};
  const ref = inicial.ref;
  const canais = inicial.canais ?? [];

  // pendente | confirmado | ja_confirmado | sem_canais | expirado | depois
  let fase = $state(
    inicial.estado === "confirmado"
      ? "ja_confirmado"
      : canais.length === 0
        ? "sem_canais"
        : "pendente",
  );
  let pollingEsgotado = $state(false);

  const telegram = canais.find((c) => c.canal === "telegram");
  const whatsapp = canais.find((c) => c.canal === "whatsapp");

  // ---------------------------------------------------------------- polling
  let timer = null;
  let ticks = 0;
  let consultando = false;

  function pararPolling() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  function iniciarPolling() {
    pararPolling();
    if (!ref) return;
    ticks = 0;
    pollingEsgotado = false;
    const maxTicks = Math.max(1, Math.floor(duracaoPolling / intervaloPolling));
    timer = setInterval(async () => {
      ticks += 1;
      if (ticks > maxTicks) {
        pararPolling();
        pollingEsgotado = true;
        return;
      }
      if (consultando) return;
      consultando = true;
      try {
        const res = await estadoConfirmacao(ref);
        if (fase === "pendente" && res?.estado === "confirmado") {
          fase = "confirmado";
          pararPolling();
        }
      } catch (err) {
        if (err instanceof ApiError && err.status === 404) {
          fase = "expirado";
          pararPolling();
        }
        // demais erros (rede, 5xx): tenta de novo no próximo tick
      } finally {
        consultando = false;
      }
    }, intervaloPolling);
  }

  function confirmarDepois() {
    pararPolling();
    fase = "depois";
  }

  // --------------------------------------------------------------- WhatsApp
  let waEnviado = $state(false);
  let waEnviando = $state(false);
  let waVerificando = $state(false);
  let waCodigo = $state("");
  let waErro = $state(null);
  let waInfo = $state(null);

  async function enviarCodigo() {
    waErro = null;
    waInfo = null;
    waEnviando = true;
    try {
      await enviarCodigoWhatsapp(ref);
      waEnviado = true;
      waCodigo = "";
      waInfo = "Enviamos um código de 6 dígitos para o seu WhatsApp.";
    } catch (err) {
      const status = err instanceof ApiError ? err.status : null;
      if (status === 404) {
        fase = "expirado";
        pararPolling();
      } else if (status === 409) {
        waErro = "O WhatsApp não está disponível agora. Tente outro canal ou confirme depois.";
      } else if (status === 429) {
        waErro = "Muitas tentativas. Aguarde alguns minutos para pedir outro código.";
      } else {
        waErro = "Não foi possível enviar o código. Verifique sua internet e tente de novo.";
      }
    } finally {
      waEnviando = false;
    }
  }

  async function verificarCodigo() {
    const codigo = waCodigo.replace(/\D/g, "");
    if (codigo.length !== 6) {
      waErro = "Digite os 6 dígitos do código.";
      return;
    }
    waErro = null;
    waInfo = null;
    waVerificando = true;
    try {
      const res = await verificarCodigoWhatsapp(ref, codigo);
      if (res?.estado === "confirmado") {
        fase = "confirmado";
        pararPolling();
      }
    } catch (err) {
      const status = err instanceof ApiError ? err.status : null;
      if (status === 400) {
        waErro = "Código inválido. Confira e tente de novo.";
      } else if (status === 410) {
        waErro = "O código expirou ou as tentativas acabaram. Peça um novo código.";
        waCodigo = "";
      } else {
        waErro = "Não foi possível verificar o código. Tente de novo.";
      }
    } finally {
      waVerificando = false;
    }
  }

  onMount(() => {
    if (fase === "pendente") iniciarPolling();
  });
  onDestroy(pararPolling);
</script>

{#if fase === "confirmado" || fase === "ja_confirmado"}
  <div
    class="rounded-card bg-white border border-green-200 shadow-card p-10 text-center space-y-3"
    data-testid="confirmacao-confirmada"
  >
    <div class="mx-auto w-14 h-14 rounded-full bg-green-50 flex items-center justify-center text-2xl">
      ✅
    </div>
    {#if fase === "confirmado"}
      <h1 class="text-lg font-bold text-gray-900">Telefone confirmado!</h1>
      <p class="text-sm text-gray-600">
        Sua inscrição está completa. Pode fechar esta página.
      </p>
    {:else}
      <h1 class="text-lg font-bold text-gray-900">Telefone já confirmado</h1>
      <p class="text-sm text-gray-600">
        Este telefone já foi confirmado nesta lista. Nada mais a fazer — pode fechar esta página.
      </p>
    {/if}
  </div>

{:else if fase === "sem_canais" || fase === "depois"}
  <div
    class="rounded-card bg-white border border-blue-200 shadow-card p-10 text-center space-y-3"
    data-testid="confirmacao-pendente-final"
  >
    <div class="mx-auto w-14 h-14 rounded-full bg-blue-50 flex items-center justify-center text-2xl">
      📝
    </div>
    <h1 class="text-lg font-bold text-gray-900">Inscrição registrada</h1>
    {#if fase === "sem_canais"}
      <p class="text-sm text-gray-600">
        Sua inscrição foi registrada; a escola vai confirmar seu telefone depois.
      </p>
    {:else}
      <p class="text-sm text-gray-600">
        Sua inscrição foi registrada como pendente. Seu telefone ainda precisa ser
        confirmado — a escola poderá pedir a confirmação depois.
      </p>
    {/if}
  </div>

{:else if fase === "expirado"}
  <div
    class="rounded-card bg-white border border-gray-200 shadow-card p-8 text-center space-y-3"
    data-testid="confirmacao-expirada"
  >
    <div class="mx-auto w-14 h-14 rounded-full bg-red-50 flex items-center justify-center text-2xl">
      ⌛
    </div>
    <h1 class="text-lg font-bold text-gray-900">Confirmação expirada</h1>
    <p class="text-sm text-gray-600">
      Este pedido de confirmação expirou. Sua inscrição foi registrada; para confirmar o
      telefone, inscreva-se de novo pelo QR code.
    </p>
  </div>

{:else}
  <div class="rounded-card bg-white border border-gray-200 shadow-card" data-testid="confirmacao-passo">
    <header class="px-6 py-5 border-b border-gray-100">
      <p class="text-[11px] text-blue-600 font-semibold uppercase tracking-wide">Passo 2 de 2</p>
      <h1 class="mt-1 text-lg font-bold text-gray-900 leading-snug">Confirme seu telefone</h1>
      <p class="mt-1 text-sm text-gray-600">
        Sua inscrição foi recebida. Para a escola ter certeza de que o número é seu,
        confirme pelo celular.
        {#if telegram}
          No Telegram, você compartilha <strong>apenas o seu número de telefone</strong> com o
          bot da escola.
        {/if}
        {#if whatsapp}
          Pelo WhatsApp, você recebe um código de 6 dígitos.
        {/if}
      </p>
    </header>

    <div class="px-6 py-5 space-y-5">
      {#if telegram}
        <a
          href={telegram.url}
          target="_blank"
          rel="noopener"
          class="flex items-center justify-center w-full h-11 rounded-md bg-sky-500 text-white text-sm font-semibold hover:bg-sky-600 transition-colors"
        >Confirmar pelo Telegram</a>
      {/if}

      {#if whatsapp}
        <section class="rounded-md border border-gray-200 p-4 space-y-3" data-testid="confirmacao-whatsapp">
          <h2 class="text-sm font-semibold text-gray-900">Receber código pelo WhatsApp</h2>
          {#if !waEnviado}
            <button
              type="button"
              onclick={enviarCodigo}
              disabled={waEnviando}
              class="w-full h-11 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700 disabled:opacity-50 transition-colors"
            >{waEnviando ? "Enviando…" : "Enviar código"}</button>
          {:else}
            <form
              onsubmit={(e) => { e.preventDefault(); verificarCodigo(); }}
              class="space-y-3"
            >
              <label class="block">
                <span class="block text-sm font-medium text-gray-700">Código de 6 dígitos</span>
                <input
                  bind:value={waCodigo}
                  type="text"
                  name="codigo"
                  inputmode="numeric"
                  autocomplete="one-time-code"
                  maxlength="6"
                  pattern="[0-9]*"
                  placeholder="000000"
                  class="mt-1 w-full h-11 px-3 rounded-md border border-gray-300 text-base tracking-[0.3em] text-center focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </label>
              <button
                type="submit"
                disabled={waVerificando}
                class="w-full h-11 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700 disabled:opacity-50 transition-colors"
              >{waVerificando ? "Verificando…" : "Verificar"}</button>
              <button
                type="button"
                onclick={enviarCodigo}
                disabled={waEnviando}
                class="w-full text-sm text-green-700 underline disabled:opacity-50"
              >{waEnviando ? "Enviando…" : "Reenviar código"}</button>
            </form>
          {/if}
          {#if waInfo}
            <p class="text-sm text-gray-600" role="status">{waInfo}</p>
          {/if}
          {#if waErro}
            <p class="text-sm text-red-600" role="alert">{waErro}</p>
          {/if}
        </section>
      {/if}

      {#if pollingEsgotado}
        <div class="rounded-md bg-amber-50 border border-amber-200 p-3 text-sm text-amber-800 space-y-2" data-testid="confirmacao-esgotada">
          <p>Ainda não recebemos a confirmação. Se já confirmou, verifique de novo.</p>
          <button
            type="button"
            onclick={iniciarPolling}
            class="text-sm font-medium underline"
          >Verificar novamente</button>
        </div>
      {:else}
        <p class="text-xs text-gray-500 text-center" aria-live="polite">
          Aguardando a confirmação… esta página atualiza sozinha.
        </p>
      {/if}

      <button
        type="button"
        onclick={confirmarDepois}
        class="w-full text-sm text-gray-600 underline"
      >Confirmar depois</button>
    </div>
  </div>
{/if}
