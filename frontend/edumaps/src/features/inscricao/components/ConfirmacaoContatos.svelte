<!-- src/features/inscricao/components/ConfirmacaoContatos.svelte -->
<script module>
  // Polling do estado da confirmação (issue #212): a cada 3s, por até 5 min.
  // Exportados para os testes (e sobrescrevíveis por props).
  export const POLL_INTERVALO_MS = 3000;
  export const POLL_DURACAO_MS = 5 * 60 * 1000;
</script>

<script>
  // Passo 2 da autoinscrição: "Confirme seu telefone / e-mail / contatos".
  // Exibido quando a resposta do POST traz `confirmacao`. Mostra, por contato
  // (`contatos`), o estado e os canais aplicáveis: Telegram (deep link) e
  // WhatsApp (código) para o telefone; código por e-mail para o e-mail
  // (issue #214). O estado `parcial` mantém o passo aberto para o contato que
  // falta; o polling segue até o estado geral ficar `confirmado`, porque a
  // confirmação pelo Telegram acontece fora desta página.
  import { onMount, onDestroy, untrack } from "svelte";
  import {
    estadoConfirmacao,
    enviarCodigoWhatsapp,
    verificarCodigoWhatsapp,
    enviarCodigoEmail,
    verificarCodigoEmail,
  } from "../api/canaisPublicApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import LinkExclusao from "./LinkExclusao.svelte";

  /**
   * @type {{
   *   confirmacao: {ref?: string, estado: string, expira_em?: string, canais?: Array<{canal: string, url?: string}>,
   *     contatos?: {telefone?: {estado: string, via?: string|null}, email?: {estado: string, via?: string|null}}},
   *   intervaloPolling?: number,
   *   duracaoPolling?: number,
   *   exclusaoUrl?: string|null,
   * }}
   */
  let {
    confirmacao,
    intervaloPolling = POLL_INTERVALO_MS,
    duracaoPolling = POLL_DURACAO_MS,
    exclusaoUrl = null,
  } = $props();

  // O passo é uma fotografia da resposta do POST: a ref e os canais não mudam
  // durante a vida do componente (nova inscrição = novo componente).
  const inicial = untrack(() => confirmacao) ?? {};
  const ref = inicial.ref;
  const canais = inicial.canais ?? [];

  const telegram = canais.find((c) => c.canal === "telegram");
  const whatsapp = canais.find((c) => c.canal === "whatsapp");
  const canalEmail = canais.find((c) => c.canal === "email");
  const temCanalTelefone = Boolean(telegram || whatsapp);

  // Sem `contatos` (resposta no formato da #212), deduz pelos canais: telefone
  // se há canal de telefone (ou nenhum canal), e-mail se há canal de e-mail.
  function deduzirContatos(c) {
    if (c.contatos && Object.keys(c.contatos).length > 0) return c.contatos;
    const estado = c.estado === "confirmado" ? "confirmado" : "pendente";
    const out = {};
    if (temCanalTelefone || !canalEmail) out.telefone = { estado, via: null };
    if (canalEmail) out.email = { estado, via: null };
    return out;
  }

  const contatosIniciais = deduzirContatos(inicial);
  let contatos = $state(contatosIniciais);

  // os contatos da inscrição não mudam; só o estado de cada um
  const temTelefone = Boolean(contatosIniciais.telefone);
  const temEmail = Boolean(contatosIniciais.email);
  const telefonePendente = $derived(Boolean(contatos.telefone) && contatos.telefone.estado !== "confirmado");
  const emailPendente = $derived(Boolean(contatos.email) && contatos.email.estado !== "confirmado");

  // Textos conforme os contatos da inscrição.
  const T =
    temTelefone && temEmail
      ? {
          titulo: "Confirme seus contatos",
          ok: "Contatos confirmados!",
          ja: "Contatos já confirmados",
          jaTexto: "Seus contatos já foram confirmados nesta lista.",
          alvo: "seus contatos",
          falta: "Seus contatos ainda precisam ser confirmados",
        }
      : temEmail
        ? {
            titulo: "Confirme seu e-mail",
            ok: "E-mail confirmado!",
            ja: "E-mail já confirmado",
            jaTexto: "Este e-mail já foi confirmado nesta lista.",
            alvo: "seu e-mail",
            falta: "Seu e-mail ainda precisa ser confirmado",
          }
        : {
            titulo: "Confirme seu telefone",
            ok: "Telefone confirmado!",
            ja: "Telefone já confirmado",
            jaTexto: "Este telefone já foi confirmado nesta lista.",
            alvo: "seu telefone",
            falta: "Seu telefone ainda precisa ser confirmado",
          };

  const algumCanalUtil = () =>
    (telefonePendente && temCanalTelefone) || (emailPendente && Boolean(canalEmail));

  // pendente (inclui parcial) | confirmado | ja_confirmado | sem_canais | expirado | depois
  let fase = $state(
    inicial.estado === "confirmado"
      ? "ja_confirmado"
      : canais.length === 0 || !algumCanalUtil()
        ? "sem_canais"
        : "pendente",
  );
  let pollingEsgotado = $state(false);

  // Aplica uma resposta {estado, contatos?} do backend.
  function aplicar(res) {
    if (res?.contatos && Object.keys(res.contatos).length > 0) {
      contatos = { ...contatos, ...res.contatos };
    }
    if (res?.estado === "confirmado") {
      fase = "confirmado";
      pararPolling();
    }
  }

  function marcarContato(tipo, via) {
    if (!contatos[tipo]) return;
    contatos = { ...contatos, [tipo]: { estado: "confirmado", via } };
  }

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
        if (fase === "pendente") aplicar(res);
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

  function refExpirada() {
    fase = "expirado";
    pararPolling();
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
        refExpirada();
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
      if (res?.estado !== "confirmado" && !res?.contatos) marcarContato("telefone", "whatsapp");
      aplicar(res);
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

  // ----------------------------------------------------------------- e-mail
  let emEnviado = $state(false);
  let emEnviando = $state(false);
  let emVerificando = $state(false);
  let emCodigo = $state("");
  let emErro = $state(null);
  let emInfo = $state(null);

  async function enviarEmail() {
    emErro = null;
    emInfo = null;
    emEnviando = true;
    try {
      await enviarCodigoEmail(ref);
      emEnviado = true;
      emCodigo = "";
      emInfo = "Enviamos um código de 6 dígitos para o seu e-mail. Confira também a caixa de spam.";
    } catch (err) {
      const status = err instanceof ApiError ? err.status : null;
      if (status === 404) {
        refExpirada();
      } else if (status === 409) {
        emErro = "A confirmação por e-mail não está disponível agora. Tente outro canal ou confirme depois.";
      } else if (status === 429) {
        emErro = "Muitas tentativas. Aguarde alguns minutos para pedir outro código.";
      } else if (status === 502) {
        emErro = "Não conseguimos enviar o e-mail agora. Tente de novo em instantes.";
      } else {
        emErro = "Não foi possível enviar o código. Verifique sua internet e tente de novo.";
      }
    } finally {
      emEnviando = false;
    }
  }

  async function verificarEmail() {
    const codigo = emCodigo.replace(/\D/g, "");
    if (codigo.length !== 6) {
      emErro = "Digite os 6 dígitos do código.";
      return;
    }
    emErro = null;
    emInfo = null;
    emVerificando = true;
    try {
      const res = await verificarCodigoEmail(ref, codigo);
      if (res?.estado !== "confirmado" && !res?.contatos) marcarContato("email", "email");
      aplicar(res);
    } catch (err) {
      const status = err instanceof ApiError ? err.status : null;
      if (status === 400) {
        emErro = "Código inválido. Confira e tente de novo.";
      } else if (status === 410) {
        emErro = "O código expirou ou as tentativas acabaram. Peça um novo código.";
        emCodigo = "";
      } else {
        emErro = "Não foi possível verificar o código. Tente de novo.";
      }
    } finally {
      emVerificando = false;
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
      <h1 class="text-lg font-bold text-gray-900">{T.ok}</h1>
      <p class="text-sm text-gray-600">
        Sua inscrição está completa. Pode fechar esta página.
      </p>
    {:else}
      <h1 class="text-lg font-bold text-gray-900">{T.ja}</h1>
      <p class="text-sm text-gray-600">
        {T.jaTexto} Nada mais a fazer — pode fechar esta página.
      </p>
    {/if}
    <LinkExclusao url={exclusaoUrl} />
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
        Sua inscrição foi registrada; a escola vai confirmar {T.alvo} depois.
      </p>
    {:else}
      <p class="text-sm text-gray-600">
        Sua inscrição foi registrada como pendente. {T.falta} — a escola poderá pedir a
        confirmação depois.
      </p>
    {/if}
    <LinkExclusao url={exclusaoUrl} />
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
      Este pedido de confirmação expirou. Sua inscrição foi registrada; para confirmar
      {T.alvo}, inscreva-se de novo pelo QR code.
    </p>
    <LinkExclusao url={exclusaoUrl} />
  </div>

{:else}
  <div class="rounded-card bg-white border border-gray-200 shadow-card" data-testid="confirmacao-passo">
    <header class="px-6 py-5 border-b border-gray-100">
      <p class="text-[11px] text-blue-600 font-semibold uppercase tracking-wide">Passo 2 de 2</p>
      <h1 class="mt-1 text-lg font-bold text-gray-900 leading-snug">{T.titulo}</h1>
      <p class="mt-1 text-sm text-gray-600">
        Sua inscrição foi recebida. Para a escola ter certeza de que o contato é seu,
        confirme pelo celular{temEmail ? " ou pelo e-mail" : ""}.
        {#if telegram && telefonePendente}
          No Telegram, você compartilha <strong>apenas o seu número de telefone</strong> com o
          bot da escola.
        {/if}
        {#if whatsapp && telefonePendente}
          Pelo WhatsApp, você recebe um código de 6 dígitos.
        {/if}
      </p>
      {#if temTelefone && temEmail}
        <ul class="mt-3 space-y-1 text-sm" data-testid="confirmacao-contatos">
          {#each [["telefone", "Telefone"], ["email", "E-mail"]] as [tipo, rotulo] (tipo)}
            {@const ok = contatos[tipo]?.estado === "confirmado"}
            <li class="flex items-center justify-between" data-testid={`contato-${tipo}`}>
              <span class="text-gray-700">{rotulo}</span>
              <span class={ok ? "text-green-700 font-semibold" : "text-amber-700 font-semibold"}>
                {ok ? "✓ confirmado" : "pendente"}
              </span>
            </li>
          {/each}
        </ul>
      {/if}
    </header>

    <div class="px-6 py-5 space-y-5">
      {#if telefonePendente}
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

        {#if !temCanalTelefone}
          <p class="text-sm text-gray-600">A escola vai confirmar seu telefone depois.</p>
        {/if}
      {/if}

      {#if emailPendente}
        {#if canalEmail}
          <section class="rounded-md border border-gray-200 p-4 space-y-3" data-testid="confirmacao-email">
            <h2 class="text-sm font-semibold text-gray-900">Receber código por e-mail</h2>
            {#if !emEnviado}
              <button
                type="button"
                onclick={enviarEmail}
                disabled={emEnviando}
                class="w-full h-11 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 disabled:opacity-50 transition-colors"
              >{emEnviando ? "Enviando…" : "Enviar código por e-mail"}</button>
            {:else}
              <form
                onsubmit={(e) => { e.preventDefault(); verificarEmail(); }}
                class="space-y-3"
              >
                <label class="block">
                  <span class="block text-sm font-medium text-gray-700">Código do e-mail (6 dígitos)</span>
                  <input
                    bind:value={emCodigo}
                    type="text"
                    name="codigo_email"
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
                  disabled={emVerificando}
                  class="w-full h-11 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 disabled:opacity-50 transition-colors"
                >{emVerificando ? "Verificando…" : "Verificar código do e-mail"}</button>
                <button
                  type="button"
                  onclick={enviarEmail}
                  disabled={emEnviando}
                  class="w-full text-sm text-indigo-700 underline disabled:opacity-50"
                >{emEnviando ? "Enviando…" : "Reenviar código por e-mail"}</button>
              </form>
            {/if}
            {#if emInfo}
              <p class="text-sm text-gray-600" role="status">{emInfo}</p>
            {/if}
            {#if emErro}
              <p class="text-sm text-red-600" role="alert">{emErro}</p>
            {/if}
          </section>
        {:else}
          <p class="text-sm text-gray-600">A escola vai confirmar seu e-mail depois.</p>
        {/if}
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
