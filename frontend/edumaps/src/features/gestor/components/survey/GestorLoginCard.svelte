<!-- src/features/gestor/components/survey/GestorLoginCard.svelte -->
<script>
  // Cartão de login do gestor (fase 2). Aparece antes dos resultados quando
  // ainda não há sessão válida (401). Devolve em onLogin o token/gestor.
  import { loginGestor } from "../../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { LIMITS } from "../../constants/pesquisas.js";

  /** @type {{onLogin: (sessao:object) => void, mensagem?: string|null, titulo?: string, descricao?: string}} */
  let {
    onLogin,
    mensagem = null,
    titulo = "Entrar para ver resultados",
    descricao = "Use o e-mail e a senha cadastrados ao montar a pesquisa.",
  } = $props();

  let email = $state("");
  let senha = $state("");
  let erro = $state(null);
  let carregando = $state(false);

  function valido() {
    return /^\S+@\S+\.\S+$/.test(email.trim()) && senha.length >= LIMITS.SENHA_MIN;
  }

  async function entrar() {
    if (!valido()) {
      erro = "Informe e-mail e senha válidos.";
      return;
    }
    carregando = true;
    erro = null;
    try {
      const sessao = await loginGestor({ email: email.trim(), senha });
      senha = "";
      onLogin(sessao);
    } catch (err) {
      erro =
        err instanceof ApiError
          ? err.message
          : "Não foi possível entrar. Tente de novo.";
    } finally {
      carregando = false;
    }
  }
</script>

<div class="rounded-card bg-white border border-gray-200 shadow-card p-6 max-w-md mx-auto">
  <header class="mb-4">
    <h2 class="text-lg font-bold text-gray-900">{titulo}</h2>
    <p class="mt-1 text-sm text-gray-600">{descricao}</p>
  </header>

  {#if mensagem}
    <p class="mb-3 text-sm text-red-600" role="alert">{mensagem}</p>
  {/if}

  <form onsubmit={(e) => { e.preventDefault(); entrar(); }} class="space-y-4">
    <label class="block">
      <span class="block text-sm font-medium text-gray-700">E-mail</span>
      <input
        type="email"
        bind:value={email}
        placeholder="voce@escola.gov.br"
        class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
    </label>
    <label class="block">
      <span class="block text-sm font-medium text-gray-700">Senha</span>
      <input
        type="password"
        bind:value={senha}
        autocomplete="current-password"
        placeholder="Sua senha"
        class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
    </label>

    {#if erro}
      <p class="text-sm text-red-600" role="alert">{erro}</p>
    {/if}

    <button
      type="submit"
      disabled={carregando}
      class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
    >
      {carregando ? "Entrando…" : "Entrar"}
    </button>
  </form>
</div>