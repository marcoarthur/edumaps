<!-- src/features/privacidade/pages/SairPage.svelte -->
<script>
  // Página pública de saída dos envios por e-mail (rota /privacidade/sair/:token,
  // issue #216). Sem conta: o token do rodapé do e-mail é a capability. Mostra
  // escola e lista, explica o que acontece (deixa de receber e-mails DESTA
  // lista; os dados continuam com a escola) e só registra a saída com a
  // confirmação explícita (POST {confirmar:true}, idempotente). Orienta a
  // remoção completa dos dados. noindex.
  import { onMount } from "svelte";
  import { getSaida, confirmarSaida } from "@/features/inscricao/api/canaisPublicApi.js";
  import { ApiError } from "@/shared/api/client.js";

  /** @type {{token: string}} */
  let { token } = $props();

  // carregando | pronto | ja_saiu | concluido | invalido | erro
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
      info = await getSaida(token);
      estado = info?.ja_saiu ? "ja_saiu" : "pronto";
    } catch (err) {
      estado = err instanceof ApiError && err.status === 404 ? "invalido" : "erro";
    }
  }

  async function confirmar() {
    enviando = true;
    aviso = null;
    try {
      const res = await confirmarSaida(token);
      estado = res?.ja_saiu ? "ja_saiu" : "concluido";
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

{#snippet remocaoCompleta()}
  <div class="rounded-md bg-gray-50 border border-gray-200 p-3 text-xs text-gray-600 space-y-1 text-left" data-testid="sair-remocao">
    <p class="font-semibold text-gray-700">Quer que a escola apague seus dados?</p>
    <p>
      Sair dos envios não apaga seu nome nem seus contatos. Para a remoção completa, use o
      link pessoal que você recebeu ao se inscrever ou peça diretamente à escola.
    </p>
    <a href="/privacidade" class="inline-block text-blue-700 underline">Política de privacidade</a>
  </div>
{/snippet}

<div class="min-h-[70vh] flex items-start justify-center px-4 py-10 bg-gray-50">
  <div class="w-full max-w-md space-y-4">
    {#if estado === "carregando"}
      <div class="rounded-card bg-white border border-gray-200 shadow-card p-10 text-center">
        <p class="text-gray-500">Carregando…</p>
      </div>

    {:else if estado === "invalido"}
      <div
        class="rounded-card bg-white border border-gray-200 shadow-card p-8 text-center space-y-3"
        data-testid="sair-invalido"
      >
        <h1 class="text-lg font-bold text-gray-900">Link inválido</h1>
        <p class="text-sm text-gray-600">
          Não encontramos este link de saída. Confira se ele foi copiado por inteiro ou
          peça à escola para não receber mais os e-mails.
        </p>
        <a href="/privacidade" class="inline-block text-sm text-blue-700 underline">Política de privacidade</a>
      </div>

    {:else if estado === "erro"}
      <div
        class="rounded-card bg-white border border-red-200 shadow-card p-8 text-center space-y-3"
        data-testid="sair-erro"
      >
        <h1 class="text-lg font-bold text-gray-900">Não foi possível abrir</h1>
        <p class="text-sm text-gray-600" role="alert">
          Houve uma falha ao carregar o pedido de saída. Verifique sua internet e tente de novo.
        </p>
        <button
          type="button"
          onclick={carregar}
          class="px-4 h-10 rounded-md border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >Tentar de novo</button>
      </div>

    {:else if estado === "ja_saiu" || estado === "concluido"}
      <div
        class="rounded-card bg-white border border-green-200 shadow-card p-8 text-center space-y-3"
        data-testid={estado === "concluido" ? "sair-concluido" : "sair-ja-saiu"}
      >
        <h1 class="text-lg font-bold text-gray-900">
          {estado === "concluido" ? "Pronto, você saiu dos envios" : "Você já tinha saído dos envios"}
        </h1>
        <p class="text-sm text-gray-600">
          Você não vai mais receber e-mails da lista
          {#if info?.lista_nome}<strong>{info.lista_nome}</strong>{/if}{#if info?.escola_nome}{" "}da
            escola <strong>{info.escola_nome}</strong>{/if}.
        </p>
        <p class="text-xs text-gray-500">
          Se você se inscrever de novo nesta lista, voltará a receber os e-mails.
        </p>
        {@render remocaoCompleta()}
      </div>

    {:else}
      <div
        class="rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-4"
        data-testid="sair-pronto"
      >
        <header class="space-y-1">
          <h1 class="text-xl font-bold text-gray-900">Sair dos envios por e-mail</h1>
          <p class="text-sm text-gray-600" data-testid="sair-origem">
            <strong>{info?.escola_nome}</strong>
            {#if info?.lista_nome}<span class="block text-gray-500">Lista: {info.lista_nome}</span>{/if}
          </p>
        </header>

        <div class="text-sm text-gray-700 space-y-2">
          <p>
            Ao confirmar, você deixa de receber e-mails <strong>desta lista</strong>. Seus dados
            continuam com a escola.
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
          class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50"
        >{enviando ? "Registrando…" : "Não quero mais receber"}</button>
        <p class="text-xs text-gray-500 text-center">
          Mudou de ideia? Basta fechar esta página.
        </p>

        {@render remocaoCompleta()}
      </div>
    {/if}
  </div>
</div>
