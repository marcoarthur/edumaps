<!-- src/features/config/components/ConfigEditor.svelte -->
<!--
  Editor da folha selecionada no Painel de Configuração. Tipos: text, number,
  select, boolean e secret (mascarado: só mostra "definida/não definida" e
  permite trocar/salvar; nunca exibe o valor em claro).
-->
<script>
  import { onMount } from "svelte";

  let { item, onSalvar, onValidar, salvando = false } = $props();

  let valor = $state("");
  let erro = $state(null);
  let validado = $state(null);

  function preencher() {
    validado = null;
    erro = null;
    if (item?.type === "secret") {
      valor = "";
      return;
    }
    const v = item?.value;
    if (item?.type === "boolean") {
      valor = v === 1 || v === true ? "true" : v === 0 || v === false ? "false" : "";
    } else if (v !== undefined && v !== null && typeof v !== "object") {
      valor = String(v);
    } else {
      valor = "";
    }
  }

  onMount(preencher);

  async function aoMudar(e) {
    valor = e.currentTarget.value;
    erro = null;
    validado = null;
  }

  async function validar() {
    erro = null;
    validado = null;
    try {
      const res = await onValidar(item.key, valor);
      validado = res?.ok ? "Válido." : null;
    } catch (err) {
      erro = err?.message ?? "Validação falhou.";
    }
  }

  async function salvar() {
    erro = null;
    try {
      await onSalvar(item.key, valor);
    } catch (err) {
      erro = err?.message ?? "Não foi possível salvar.";
    }
  }
</script>

{#if !item}
  <div class="text-center py-16 text-gray-400">
    <p class="text-lg">Selecione uma configuração</p>
    <p class="text-sm mt-1">Escolha um item na árvore ao lado (Integrações → Assistente do Censo → Chaves).</p>
  </div>
{:else}
  <div>
    <header class="pb-3 border-b border-gray-100">
      <div class="flex items-center gap-2">
        <h2 class="text-lg font-bold text-gray-900">{item.label}</h2>
        {#if item.description}
          <span
            class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-gray-200 text-gray-500 text-xs font-bold"
            title={item.description}
            aria-label={`Sobre ${item.label}: ${item.description}`}
          >
            ?
          </span>
        {/if}
      </div>
      {#if item.description}
        <p class="text-sm text-gray-600 mt-1">{item.description}</p>
      {/if}
    </header>

    {#if !item.enabled}
      <div class="mt-4 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-700">
        Esta configuração ainda está em construção e não entra em vigor.
      </div>
    {/if}

    <div class="mt-4 space-y-3">
      {#if item.type === "secret"}
        <div>
          <p class="text-sm font-medium text-gray-700 mb-1">
            {item.value?.set ? "Chave atualmente definida" : "Chave ainda não definida"}
          </p>
          <p class="text-xs text-gray-400 mb-2">
            Nunca exibimos o valor: a chave fica guardada cifrada e só o provedor a utiliza.
          </p>
          <input
            type="password"
            value={valor}
            oninput={aoMudar}
            placeholder={item.value?.set ? "Nova chave (deixe em branco para manter)" : "Cole a chave secreta…"}
            autocomplete="new-password"
            class="w-full h-10 px-3 rounded-md border {erro ? 'border-red-300' : 'border-gray-300'} text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          {#if item.example}
            <p class="text-xs text-gray-400 mt-1">Ex.: {item.example}</p>
          {/if}
        </div>
      {:else if item.type === "select"}
        <div>
          <p class="text-sm font-medium text-gray-700 mb-1">Valor atual: {item.value ?? "—"}</p>
          <select
            value={valor}
            onchange={aoMudar}
            class="w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Selecione…</option>
            {#each item.options ?? [] as opt}
              <option value={opt}>{opt}</option>
            {/each}
          </select>
        </div>
      {:else if item.type === "boolean"}
        <div>
          <p class="text-sm font-medium text-gray-700 mb-1">Valor atual: {item.value == null ? "—" : item.value ? "ativado" : "desativado"}</p>
          <select
            value={valor}
            onchange={aoMudar}
            class="w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Selecione…</option>
            <option value="true">Ativado</option>
            <option value="false">Desativado</option>
          </select>
        </div>
      {:else}
        <div>
          <p class="text-sm font-medium text-gray-700 mb-1">
            Valor atual: {item.type === "number" ? (item.value ?? "—") : item.value ?? "—"}
          </p>
          <input
            type={item.type === "number" ? "number" : "text"}
            value={valor}
            oninput={aoMudar}
            placeholder={item.example ?? ""}
            class="w-full h-10 px-3 rounded-md border {erro ? 'border-red-300' : 'border-gray-300'} text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      {/if}

      {#if (validado ?? erro ?? null)}
        <p class="text-sm {erro ? 'text-red-600' : 'text-green-700'}" role="alert">
          {erro ?? validado}
        </p>
      {/if}

      <div class="flex items-center gap-2 pt-1">
        <button
          type="button"
          onclick={salvar}
          disabled={salvando || !item.enabled}
          class="px-4 h-10 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-40 transition-colors"
        >
          {salvando ? "Salvando…" : "Salvar"}
        </button>
        {#if onValidar && item.enabled}
          <button
            type="button"
            onclick={validar}
            class="px-4 h-10 rounded-md border border-gray-300 text-gray-700 text-sm font-medium hover:bg-gray-50 transition-colors"
          >
            Validar
          </button>
        {/if}
      </div>
    </div>
  </div>
{/if}