<!-- src/features/inscricao/pages/InscricaoPublicaPage.svelte -->
<script>
  // Página pública de autoinscrição (rota /inscricao/:token). Abre pelo QR code,
  // sem conta: o token na URL é a capability. Mobile-first. noindex (não deve
  // ser indexada). O backend é a autoridade; aqui só espelhamos a validação.
  import { onMount } from "svelte";
  import { getInscricaoPublica, enviarInscricao } from "../api/canaisPublicApi.js";
  import { ApiError } from "@/shared/api/client.js";

  /** @type {{token: string, politicaUrl?: string}} */
  let { token, politicaUrl = "/privacidade" } = $props();

  let form = $state(null);
  let loading = $state(true);
  let indisponivel = $state(false);
  let erro = $state(null);

  let enviado = $state(false);
  let duplicado = $state(false);
  let enviando = $state(false);

  let nome = $state("");
  let telefone = $state("");
  let consentimento = $state(false);
  let _hp = $state(""); // honeypot: escondido, deve ficar vazio
  let erroValidacao = $state(null);

  const digitos = (s) => String(s ?? "").replace(/\D/g, "");

  function aplicarNoindex() {
    if (typeof document === "undefined") return;
    let meta = document.querySelector('meta[name="robots"]');
    if (!meta) {
      meta = document.createElement("meta");
      meta.setAttribute("name", "robots");
      document.head.appendChild(meta);
    }
    meta.setAttribute("content", "noindex, nofollow");
  }

  function validar() {
    const n = nome.trim();
    if (!n) return "Informe seu nome.";
    if (n.length > 120) return "O nome está muito longo.";
    if (digitos(telefone).length < 8) return "Informe um telefone com DDD.";
    if (!consentimento) return "É necessário concordar com o uso dos dados.";
    return null;
  }

  async function submit() {
    const msg = validar();
    if (msg) {
      erroValidacao = msg;
      return;
    }
    erroValidacao = null;
    enviando = true;
    try {
      const res = await enviarInscricao(token, {
        nome: nome.trim(),
        telefone: telefone.trim(),
        consentimento: true,
        _hp,
      });
      if (res?.duplicado) duplicado = true;
      else enviado = true;
    } catch (err) {
      if (err instanceof ApiError && (err.status === 404 || err.status === 410)) {
        indisponivel = true;
      } else if (err instanceof ApiError && err.status === 429) {
        erroValidacao = err.message || "Muitas tentativas. Aguarde um instante.";
      } else if (err instanceof ApiError && err.status === 400) {
        erroValidacao = err.message || "Confira os dados e tente de novo.";
      } else {
        erro = "Não foi possível conectar. Verifique sua internet e tente de novo.";
      }
    } finally {
      enviando = false;
    }
  }

  onMount(() => {
    aplicarNoindex();
    if (!token) {
      indisponivel = true;
      loading = false;
      return;
    }
    getInscricaoPublica(token)
      .then((d) => {
        form = d;
      })
      .catch((err) => {
        if (err instanceof ApiError && (err.status === 404 || err.status === 410)) {
          indisponivel = true;
        } else {
          erro = "Não foi possível abrir o formulário. Verifique o link.";
        }
      })
      .finally(() => {
        loading = false;
      });
  });
</script>

<div class="min-h-[70vh] flex items-start justify-center px-4 py-10 bg-gray-50">
  <div class="w-full max-w-md space-y-4">
    {#if loading}
      <div class="rounded-card bg-white border border-gray-200 shadow-card p-10 text-center">
        <p class="text-gray-500">Carregando formulário…</p>
      </div>

    {:else if indisponivel}
      <div
        class="rounded-card bg-white border border-gray-200 shadow-card p-8 text-center space-y-3"
        data-testid="inscricao-indisponivel"
      >
        <div class="mx-auto w-14 h-14 rounded-full bg-red-50 flex items-center justify-center text-2xl">
          😕
        </div>
        <h1 class="text-lg font-bold text-gray-900">Link indisponível</h1>
        <p class="text-sm text-gray-600">
          Este QR code expirou ou foi revogado. Peça um novo link ao gestor da escola.
        </p>
      </div>

    {:else if enviado}
      <div
        class="rounded-card bg-white border border-green-200 shadow-card p-10 text-center space-y-3"
        data-testid="inscricao-sucesso"
      >
        <div class="mx-auto w-14 h-14 rounded-full bg-green-50 flex items-center justify-center text-2xl">
          ✅
        </div>
        <h1 class="text-lg font-bold text-gray-900">Inscrição confirmada!</h1>
        <p class="text-sm text-gray-600">
          Você entrou na lista. A escola poderá entrar em contato. Pode fechar esta página.
        </p>
      </div>

    {:else if duplicado}
      <div
        class="rounded-card bg-white border border-blue-200 shadow-card p-10 text-center space-y-3"
        data-testid="inscricao-ja-cadastrada"
      >
        <div class="mx-auto w-14 h-14 rounded-full bg-blue-50 flex items-center justify-center text-2xl">
          👍
        </div>
        <h1 class="text-lg font-bold text-gray-900">Você já está na lista</h1>
        <p class="text-sm text-gray-600">
          Seu telefone já estava cadastrado. Nada foi duplicado — pode fechar esta página.
        </p>
      </div>

    {:else if erro}
      <div
        class="rounded-card bg-white border border-red-200 shadow-card p-8 text-center space-y-3"
        data-testid="inscricao-erro"
      >
        <div class="mx-auto w-14 h-14 rounded-full bg-red-50 flex items-center justify-center text-2xl">
          📶
        </div>
        <h1 class="text-lg font-bold text-gray-900">Não foi possível conectar</h1>
        <p class="text-sm text-gray-600" role="alert">{erro}</p>
        <button
          type="button"
          onclick={() => window.location.reload()}
          class="px-4 h-10 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
        >Tentar de novo</button>
      </div>

    {:else}
      <div class="rounded-card bg-white border border-gray-200 shadow-card">
        <header class="px-6 py-5 border-b border-gray-100">
          <p class="text-[11px] text-blue-600 font-semibold uppercase tracking-wide">
            Inscrição · {form?.escola_nome ?? ""}
          </p>
          <h1 class="mt-1 text-lg font-bold text-gray-900 leading-snug">
            {form?.lista_nome}
          </h1>
          <p class="mt-1 text-sm text-gray-600">
            Deixe seu nome e telefone para a escola falar com você.
          </p>
        </header>

        <form
          onsubmit={(e) => { e.preventDefault(); submit(); }}
          class="px-6 py-5 space-y-5"
        >
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Nome *</span>
            <input
              bind:value={nome}
              type="text"
              name="nome"
              autocomplete="name"
              maxlength="120"
              placeholder="Seu nome completo"
              class="mt-1 w-full h-11 px-3 rounded-md border border-gray-300 text-base focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>

          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Telefone *</span>
            <input
              bind:value={telefone}
              type="tel"
              name="telefone"
              inputmode="numeric"
              autocomplete="tel"
              placeholder="(00) 00000-0000"
              class="mt-1 w-full h-11 px-3 rounded-md border border-gray-300 text-base focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>

          <!-- honeypot anti-bot: invisível; humano deixa vazio -->
          <div class="absolute -left-[9999px] top-auto h-px w-px overflow-hidden" aria-hidden="true">
            <label>
              Não preencha
              <input bind:value={_hp} name="_hp" tabindex="-1" autocomplete="off" />
            </label>
          </div>

          <label class="flex items-start gap-2 text-sm text-gray-700 cursor-pointer">
            <input
              type="checkbox"
              bind:checked={consentimento}
              class="mt-0.5 accent-blue-600"
            />
            <span>
              Autorizo a escola a guardar meu nome e telefone para contato, conforme a
              <a href={politicaUrl} class="text-blue-600 underline">política de privacidade</a>.
            </span>
          </label>

          {#if erroValidacao}
            <p class="text-sm text-red-600" role="alert">{erroValidacao}</p>
          {/if}

          <button
            type="submit"
            disabled={enviando}
            class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            {enviando ? "Enviando…" : "Inscrever-me"}
          </button>
        </form>
      </div>

      <p class="text-center text-[11px] text-gray-400">
        EduMaps · seus dados ficam restritos à escola
      </p>
    {/if}
  </div>
</div>
