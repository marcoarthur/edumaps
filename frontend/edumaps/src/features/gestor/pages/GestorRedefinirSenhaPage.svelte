<!-- src/features/gestor/pages/GestorRedefinirSenhaPage.svelte -->
<script>
  // Redefinir a senha pelo link do e-mail (#336): /gestor/redefinir-senha#<token>.
  // O token vem depois do "#" — não vai ao servidor no carregamento da página
  // nem aparece em logs ou no Referer — e é apagado da barra de endereço assim
  // que lido. Ao concluir, todas as sessões do gestor foram encerradas.
  import { onMount } from "svelte";
  import { redefinirSenha } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { LIMITS } from "../constants/pesquisas.js";

  let token = $state(null);
  let senha = $state("");
  let confirma = $state("");
  let erro = $state(null);
  let salvando = $state(false);
  let pronto = $state(false);

  onMount(() => {
    const t = window.location.hash.replace(/^#/, "");
    token = /^[A-Za-z0-9_-]{43}$/.test(t) ? t : null;
    // tira o token da barra de endereço (e do histórico do navegador)
    window.history.replaceState({}, "", window.location.pathname);
  });

  async function salvar() {
    if (senha.length < LIMITS.SENHA_MIN) {
      erro = `A senha deve ter ao menos ${LIMITS.SENHA_MIN} caracteres.`;
      return;
    }
    if (senha !== confirma) {
      erro = "As duas senhas não são iguais.";
      return;
    }
    salvando = true;
    erro = null;
    try {
      await redefinirSenha({ token, senha });
      senha = "";
      confirma = "";
      pronto = true;
    } catch (err) {
      erro = err instanceof ApiError ? err.message : "Não foi possível salvar a senha. Tente de novo.";
    } finally {
      salvando = false;
    }
  }
</script>

<div class="max-w-md mx-auto space-y-4">
  <div class="rounded-card bg-white border border-gray-200 shadow-card p-6">
    <header class="mb-4">
      <h1 class="text-lg font-bold text-gray-900">Criar senha nova</h1>
    </header>

    {#if pronto}
      <div class="rounded-md bg-green-50 border border-green-200 text-green-900 text-sm p-4" role="status">
        <p class="font-semibold">Senha alterada.</p>
        <p class="mt-1">Por segurança, você saiu de todos os aparelhos. Entre de novo com a senha nova.</p>
      </div>
      <a
        href="/gestor"
        class="mt-4 block w-full h-11 leading-[2.75rem] text-center rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
      >Entrar</a>
    {:else if !token}
      <div class="rounded-md bg-amber-50 border border-amber-200 text-amber-900 text-sm p-4" role="alert">
        Este link está incompleto. Abra de novo o link do e-mail ou peça um novo.
      </div>
      <a href="/gestor/esqueci-senha" class="mt-4 inline-block text-sm text-blue-700 hover:underline">Pedir um link novo</a>
    {:else}
      <form onsubmit={(e) => { e.preventDefault(); salvar(); }} class="space-y-4">
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Senha nova</span>
          <input
            type="password"
            bind:value={senha}
            autocomplete="new-password"
            minlength={LIMITS.SENHA_MIN}
            maxlength={LIMITS.SENHA_MAX}
            placeholder="Mínimo {LIMITS.SENHA_MIN} caracteres"
            class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Repita a senha nova</span>
          <input
            type="password"
            bind:value={confirma}
            autocomplete="new-password"
            maxlength={LIMITS.SENHA_MAX}
            class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        {#if erro}
          <p class="text-sm text-red-600" role="alert">{erro}</p>
        {/if}
        <button
          type="submit"
          disabled={salvando}
          class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
        >
          {salvando ? "Salvando…" : "Salvar senha nova"}
        </button>
      </form>
      {#if erro && /não vale mais/.test(erro)}
        <a href="/gestor/esqueci-senha" class="mt-3 inline-block text-sm text-blue-700 hover:underline">Pedir um link novo</a>
      {/if}
    {/if}
  </div>
</div>
