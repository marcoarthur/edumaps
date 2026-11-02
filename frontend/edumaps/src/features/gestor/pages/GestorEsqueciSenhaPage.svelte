<!-- src/features/gestor/pages/GestorEsqueciSenhaPage.svelte -->
<script>
  // "Esqueci minha senha" (#336): pede o link por e-mail. A resposta é sempre
  // a mesma, exista a conta ou não — a tela só repete a mensagem do servidor.
  import { pedirRedefinicaoSenha } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";

  let email = $state("");
  let erro = $state(null);
  let enviando = $state(false);
  let mensagem = $state(null);

  async function pedir() {
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      erro = "Informe um e-mail válido.";
      return;
    }
    enviando = true;
    erro = null;
    try {
      const r = await pedirRedefinicaoSenha(email.trim());
      mensagem = r?.mensagem ?? "Pedido recebido.";
    } catch (err) {
      erro = err instanceof ApiError ? err.message : "Não foi possível enviar o pedido. Tente de novo.";
    } finally {
      enviando = false;
    }
  }
</script>

<div class="max-w-md mx-auto space-y-4">
  <div class="rounded-card bg-white border border-gray-200 shadow-card p-6">
    <header class="mb-4">
      <h1 class="text-lg font-bold text-gray-900">Esqueci minha senha</h1>
      <p class="mt-1 text-sm text-gray-600">
        Informe o e-mail da sua conta de gestor. Enviamos um link para você criar uma senha nova.
      </p>
    </header>

    {#if mensagem}
      <div class="rounded-md bg-blue-50 border border-blue-200 text-blue-900 text-sm p-4" role="status">
        <p>{mensagem}</p>
        <p class="mt-2 text-xs text-blue-800">O link vale por 30 minutos e só pode ser usado uma vez.</p>
      </div>
    {:else}
      <form novalidate onsubmit={(e) => { e.preventDefault(); pedir(); }} class="space-y-4">
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">E-mail</span>
          <input
            type="email"
            bind:value={email}
            autocomplete="email"
            placeholder="voce@escola.gov.br"
            class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        {#if erro}
          <p class="text-sm text-red-600" role="alert">{erro}</p>
        {/if}
        <button
          type="submit"
          disabled={enviando}
          class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
        >
          {enviando ? "Enviando…" : "Enviar link"}
        </button>
      </form>
    {/if}
  </div>
  <p class="text-center text-sm">
    <a href="/gestor" class="text-blue-700 hover:underline">← Voltar para Entrar</a>
  </p>
</div>
