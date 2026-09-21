<!-- src/features/gestor/pages/GestorAcessoPage.svelte -->
<script>
  // Acesso do gestor: ponto de entrada para login e cadastro, sem checagem de
  // propriedade (o usuário informa a escola). Após entrar/cadastrar, vai para
  // o painel do gestor. Reusa os endpoints existentes de /perfil e /login.
  import { onMount } from "svelte";
  import { upsertGestor, loginGestor, fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

  const params = new URLSearchParams(window.location.search);
  const inepInicial = params.get("inep") ?? "";

  let modo = $state(params.get("modo") === "cadastro" ? "cadastrar" : "entrar");
  let carregando = $state(true);
  let gestorLogado = $state(null);

  let cadastro = $state({
    cod_inep: inepInicial,
    nome: "",
    email: "",
    senha: "",
    telefone: "",
    cargo: "",
  });
  let erro = $state(null);
  let salvando = $state(false);

  async function verificarSessao() {
    carregando = true;
    restaurarSessao();
    try {
      gestorLogado = await fetchMe();
    } catch {
      gestorLogado = null;
    } finally {
      carregando = false;
    }
  }

  function irParaPainel(inep) {
    window.location.href = inep ? `/gestor/painel?inep=${inep}` : "/gestor/painel";
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    irParaPainel(sessao.gestor?.cod_inep);
  }

  async function cadastrar() {
    erro = null;
    const { cod_inep, nome, email, senha } = cadastro;
    if (!/^\d{8}$/.test(cod_inep.trim())) {
      erro = "Informe o código INEP da escola (8 dígitos).";
      return;
    }
    if (nome.trim().length < 2) {
      erro = "Informe o seu nome.";
      return;
    }
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      erro = "Informe um e-mail válido.";
      return;
    }
    if (senha.length < 6) {
      erro = "A senha deve ter ao menos 6 caracteres.";
      return;
    }

    salvando = true;
    try {
      await upsertGestor({
        cod_inep: cod_inep.trim(),
        nome: nome.trim(),
        email: email.trim(),
        senha,
        telefone: cadastro.telefone.trim() || undefined,
        cargo: cadastro.cargo.trim() || undefined,
      });
      // auto-login após o cadastro (fluxo natural: cadastrou → entra no painel)
      try {
        const sessao = await loginGestor({ email: email.trim(), senha });
        setSessaoToken(sessao.token);
      } catch {
        // se o login automático falhar, o painel pedirá login
      }
      addToast("Cadastro realizado. Bem-vindo(a)!", "success");
      irParaPainel(cod_inep.trim());
    } catch (err) {
      erro = err instanceof ApiError ? err.message : "Não foi possível concluir o cadastro.";
    } finally {
      salvando = false;
    }
  }

  async function sair() {
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      gestorLogado = null;
      modo = "entrar";
    }
  }

  onMount(verificarSessao);
</script>

<div class="space-y-6 max-w-xl mx-auto">
  <header class="text-center space-y-2 py-4">
    <h1 class="text-2xl font-bold text-gray-900">Área do gestor</h1>
    <p class="text-sm text-gray-600">
      Entre ou cadastre-se para gerir pesquisas, reuniões, inventário e relações da sua escola.
    </p>
  </header>

  {#if carregando}
    <div class="text-center py-10"><p class="text-gray-500">Carregando…</p></div>
  {:else if gestorLogado}
    <div class="rounded-card bg-white border border-gray-200 shadow-card p-6 text-center space-y-3">
      <p class="text-sm text-gray-600">Você já está logado como</p>
      <p class="text-lg font-semibold text-gray-900">{gestorLogado.nome}</p>
      <p class="text-xs text-gray-500">Escola {gestorLogado.cod_inep} · {gestorLogado.email}</p>
      <div class="flex justify-center gap-2 pt-1">
        <button
          type="button"
          onclick={() => irParaPainel(gestorLogado.cod_inep)}
          class="px-5 py-2 rounded-md bg-brand-700 text-white text-sm font-semibold hover:bg-brand-600 transition-colors"
        >Ir para o painel</button>
        <button
          type="button"
          onclick={sair}
          class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
        >Sair</button>
      </div>
    </div>
  {:else}
    <nav class="flex gap-1" aria-label="Acesso do gestor">
      <button
        type="button"
        onclick={() => (modo = "entrar")}
        class={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${modo === "entrar" ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"}`}
      >Já tenho conta</button>
      <button
        type="button"
        onclick={() => (modo = "cadastrar")}
        class={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${modo === "cadastrar" ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"}`}
      >Criar conta</button>
    </nav>

    {#if modo === "entrar"}
      <GestorLoginCard
        onLogin={onLogin}
        titulo="Entrar"
        descricao="Use o e-mail e a senha do seu cadastro."
      />
    {:else}
      <div class="rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-4">
        <header>
          <h2 class="text-lg font-bold text-gray-900">Cadastrar como gestor</h2>
          <p class="mt-1 text-sm text-gray-600">
            Informe a escola e seus dados. Não verificamos a titularidade neste momento.
          </p>
        </header>

        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Código INEP da escola</span>
          <input
            bind:value={cadastro.cod_inep}
            inputmode="numeric"
            placeholder="8 dígitos"
            class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Seu nome</span>
          <input bind:value={cadastro.nome} placeholder="Seu nome completo" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">E-mail</span>
          <input type="email" bind:value={cadastro.email} placeholder="voce@escola.gov.br" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Senha</span>
          <input type="password" bind:value={cadastro.senha} autocomplete="new-password" placeholder="Mínimo 6 caracteres" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </label>
        <div class="grid gap-3 sm:grid-cols-2">
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Telefone (opcional)</span>
            <input bind:value={cadastro.telefone} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </label>
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Cargo (opcional)</span>
            <input bind:value={cadastro.cargo} placeholder="Diretor(a), coordenador(a)…" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </label>
        </div>

        {#if erro}
          <p class="text-sm text-red-600" role="alert">{erro}</p>
        {/if}

        <button
          type="button"
          onclick={cadastrar}
          disabled={salvando}
          class="w-full h-11 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700 disabled:opacity-50 transition-colors"
        >{salvando ? "Cadastrando…" : "Cadastrar e entrar"}</button>
      </div>
    {/if}
  {/if}
</div>
