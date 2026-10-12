<!-- src/features/privacidade/pages/ExclusaoPage.svelte -->
<script>
  // Página pública de exclusão a pedido do titular (rota
  // /privacidade/exclusao/:token, issue #214). Sem conta: o token pessoal
  // recebido na inscrição é a capability. Mostra escola e lista, explica o que
  // será removido e só exclui com a confirmação explícita (POST
  // {confirmar:true}, idempotente). noindex.
  import { onMount } from "svelte";
  import { getExclusao, confirmarExclusao } from "@/features/inscricao/api/canaisPublicApi.js";
  import { ApiError } from "@/shared/api/client.js";

  /** @type {{token: string}} */
  let { token } = $props();

  // carregando | pronto | ja_excluido | concluido | invalido | erro
  let estado = $state("carregando");
  let info = $state(null);
  let enviando = $state(false);
  let aviso = $state(null); // erro do POST (429 ou falha) — a página continua utilizável

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

  async function carregar() {
    estado = "carregando";
    aviso = null;
    if (!token) {
      estado = "invalido";
      return;
    }
    try {
      info = await getExclusao(token);
      estado = info?.ja_excluido ? "ja_excluido" : "pronto";
    } catch (err) {
      estado = err instanceof ApiError && err.status === 404 ? "invalido" : "erro";
    }
  }

  async function confirmar() {
    enviando = true;
    aviso = null;
    try {
      const res = await confirmarExclusao(token);
      estado = res?.ja_excluido ? "ja_excluido" : "concluido";
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) estado = "invalido";
      else if (err instanceof ApiError && err.status === 429) {
        aviso = "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo.";
      } else {
        aviso = "Não foi possível concluir agora. Verifique sua internet e tente de novo.";
      }
    } finally {
      enviando = false;
    }
  }

  onMount(() => {
    aplicarNoindex();
    carregar();
  });
</script>

<div class="min-h-[70vh] flex items-start justify-center px-4 py-10 bg-gray-50">
  <div class="w-full max-w-md space-y-4">
    {#if estado === "carregando"}
      <div class="rounded-card bg-white border border-gray-200 shadow-card p-10 text-center">
        <p class="text-gray-500">Carregando…</p>
      </div>

    {:else if estado === "invalido"}
      <div
        class="rounded-card bg-white border border-gray-200 shadow-card p-8 text-center space-y-3"
        data-testid="exclusao-invalido"
      >
        <h1 class="text-lg font-bold text-gray-900">Link inválido</h1>
        <p class="text-sm text-gray-600">
          Não encontramos este link de exclusão. Confira se ele foi copiado por inteiro ou
          peça a remoção dos seus dados diretamente à escola.
        </p>
        <a href="/privacidade" class="inline-block text-sm text-blue-700 underline">Política de privacidade</a>
      </div>

    {:else if estado === "erro"}
      <div
        class="rounded-card bg-white border border-red-200 shadow-card p-8 text-center space-y-3"
        data-testid="exclusao-erro"
      >
        <h1 class="text-lg font-bold text-gray-900">Não foi possível abrir</h1>
        <p class="text-sm text-gray-600" role="alert">
          Houve uma falha ao carregar o pedido de exclusão. Verifique sua internet e tente de novo.
        </p>
        <button
          type="button"
          onclick={carregar}
          class="px-4 h-10 rounded-md border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >Tentar de novo</button>
      </div>

    {:else if estado === "ja_excluido" || estado === "concluido"}
      <div
        class="rounded-card bg-white border border-green-200 shadow-card p-8 text-center space-y-3"
        data-testid={estado === "concluido" ? "exclusao-concluida" : "exclusao-ja-excluida"}
      >
        <h1 class="text-lg font-bold text-gray-900">
          {estado === "concluido" ? "Seus dados foram removidos" : "Seus dados já foram removidos"}
        </h1>
        <p class="text-sm text-gray-600">
          {#if info?.escola_nome}A escola <strong>{info.escola_nome}</strong> não guarda mais{:else}A escola não guarda mais{/if}
          seu nome, telefone ou e-mail. Fica apenas um registro, sem dados pessoais, de que
          houve uma inscrição e a exclusão.
        </p>
        <p class="text-xs text-gray-500">
          Se você se inscrever de novo no futuro, será um cadastro novo.
        </p>
      </div>

    {:else}
      <div
        class="rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-4"
        data-testid="exclusao-pronto"
      >
        <header class="space-y-1">
          <h1 class="text-xl font-bold text-gray-900">Remover meus dados</h1>
          <p class="text-sm text-gray-600" data-testid="exclusao-origem">
            <strong>{info?.escola_nome}</strong>
            {#if info?.lista_nome}<span class="block text-gray-500">Lista: {info.lista_nome}</span>{/if}
          </p>
        </header>

        <div class="text-sm text-gray-700 space-y-2">
          <p>Ao confirmar, a escola apaga:</p>
          <ul class="list-disc pl-5 space-y-0.5">
            <li>seu <strong>nome</strong>, <strong>telefone</strong> e <strong>e-mail</strong>;</li>
            <li>sua inscrição em <strong>todas as listas desta escola</strong>, não só nesta;</li>
            <li>os códigos de confirmação pendentes e as mensagens enviadas a você.</li>
          </ul>
          <p class="text-gray-600">
            Fica apenas um registro, <strong>sem dados pessoais</strong>, de que houve uma inscrição
            e a exclusão. A remoção não pode ser desfeita.
          </p>
        </div>

        {#if aviso}
          <p class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-3" role="alert">
            {aviso}
          </p>
        {/if}

        <button
          type="button"
          onclick={confirmar}
          disabled={enviando}
          class="w-full h-11 rounded-md bg-red-600 text-white text-sm font-semibold hover:bg-red-700 disabled:opacity-50"
        >{enviando ? "Removendo…" : "Confirmar e remover meus dados"}</button>
        <p class="text-xs text-gray-500 text-center">
          Mudou de ideia? Basta fechar esta página.
        </p>
      </div>
    {/if}
  </div>
</div>
