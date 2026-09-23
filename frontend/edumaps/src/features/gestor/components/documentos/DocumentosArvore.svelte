<!-- src/features/gestor/components/documentos/DocumentosArvore.svelte -->
<!--
  Explorador de documentos: pastas/subpastas indentadas (raiz + aninhadas),
  documentos dentro de cada pasta e ações contextuais (renomear, mover,
  tags, versões, histórico, excluir). Cada ação vira onAcao(tipo, payload)
  e o container (página) executa a API e atualiza o estado.
-->
<script>
  import { MIME_ROTULO, formatarTamanho } from "../../constants/documentos.js";
  import TagEditor from "./TagEditor.svelte";

  let {
    pastas = [],
    documentos = [],
    selecionada = null,
    onSelecionarPasta,
    onAcao,
  } = $props();

  // Pastas ficam abertas por padrão; o usuário recolhe as que quiser.
  let recolhidas = $state(new Set());
  let editor = $state(null);
  let novoNome = $state("");

  function rotuloMime(mime) {
    return MIME_ROTULO[mime] ?? (mime ? mime.split("/").pop().toUpperCase() : "ARQ");
  }

  function profundidadeDe(pai, cache = new Map()) {
    if (pai == null) return 0;
    if (cache.has(pai)) return cache.get(pai);
    const p = pastas.find((x) => x.id === pai);
    const d = p ? 1 + profundidadeDe(p.pasta_pai_id, cache) : 1;
    cache.set(pai, d);
    return d;
  }

  // Ordem de exibição: pastas (raiz → aninhadas, seguindo "abertas") e depois
  // os documentos de cada pasta/raiz. Indentação = profundidade.
  const nodes = $derived.by(() => {
    const out = [];
    const cache = new Map();
    const emitir = (pai, nivel) => {
      const filhas = pastas.filter((p) => (p.pasta_pai_id ?? null) === pai);
      for (const p of filhas) {
        out.push({ tipo: "pasta", id: p.id, nome: p.nome, pai, nivel, nivelReal: profundidadeDe(p.id, cache) });
        if (!recolhidas.has(p.id)) emitir(p.id, nivel + 1);
      }
      const docs = documentos.filter((d) => (d.pasta_id ?? null) === pai);
      for (const d of docs) {
        out.push({ tipo: "doc", id: d.id, doc: d, pai, nivel });
      }
    };
    emitir(null, 0);
    return out;
  });

  function alternar(pastaId) {
    const next = new Set(recolhidas);
    if (next.has(pastaId)) next.delete(pastaId);
    else next.add(pastaId);
    recolhidas = next;
  }

  function abrirEditor(modo, tipo, item) {
    if (editor && editor.tipo === tipo && editor.id === (item?.id ?? item)) {
      editor = null;
      return;
    }
    if (modo === "criar") {
      editor = { modo, tipo: "pasta", pai: item };
    } else if (modo === "tags") {
      editor = { modo, tipo, doc: item };
    } else {
      editor = { modo, tipo, id: item.id, nome: item.nome };
    }
  }

  function vazioEditorAberto(tipo, id) {
    return (
      editor &&
      editor.modo !== "tags" &&
      editor.modo !== "criar" &&
      editor.tipo === tipo &&
      editor.id === id
    );
  }

  function vazioCriarAberto(pai) {
    return editor && editor.modo === "criar" && editor.tipo === "pasta" && editor.pai === pai;
  }

  function opcoesDestino() {
    const opts = [{ value: "", label: "Raiz" }];
    const flat = (pai, prefixo, nivel) => {
      for (const p of pastas.filter((x) => (x.pasta_pai_id ?? null) === pai)) {
        opts.push({ value: String(p.id), label: `${prefixo}${p.nome}` });
        flat(p.id, `${prefixo}${p.nome} / `, nivel + 1);
      }
    };
    flat(null, "", 0);
    return opts;
  }

  let destino = $state("");
</script>

<div class="space-y-1">
  <div class="flex items-center justify-between px-1 pb-1 border-b border-gray-100">
    <span class="text-xs text-gray-500">
      {#if selecionada == null}Na raiz{/if}
    </span>
    <button
      type="button"
      onclick={() => abrirEditor("criar", "pasta", selecionada)}
      class="text-sm px-2 py-1 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
    >
      📁 Nova pasta {selecionada == null ? "na raiz" : "aqui"}
    </button>
  </div>

  {#if editor && editor.modo === "criar" && editor.pai === selecionada}
    <div class="pl-1 flex items-center gap-1.5">
      <input
        type="text"
        placeholder="Nome da pasta"
        bind:value={novoNome}
        data-criar-pasta
        class="flex-1 text-sm border border-gray-300 rounded-md px-2 py-1"
      />
      <button
        type="button"
        onclick={() => {
          onAcao("nova-pasta", { pai: selecionada, nome: novoNome.trim() });
          editor = null;
          novoNome = "";
        }}
        class="text-sm px-2 py-1 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
      >
        Criar
      </button>
      <button
        type="button"
        onclick={() => (editor = null)}
        class="text-sm px-2 py-1 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-100"
      >
        Cancelar
      </button>
    </div>
  {/if}

  {#each nodes as n (n.tipo + n.id)}
    {#if n.tipo === "pasta"}
      <div class="group" style="padding-left:{n.nivel * 18}px">
        <div
          class="flex items-center gap-1 rounded-md px-1.5 py-1 hover:bg-gray-100 {selecionada === n.id ? 'bg-indigo-50 ring-1 ring-indigo-200' : ''}"
        >
          <button
            type="button"
            aria-label={recolhidas.has(n.id) ? `Expandir pasta ${n.nome}` : `Recolher pasta ${n.nome}`}
            onclick={() => alternar(n.id)}
            class="w-4 text-gray-400 text-xs"
          >
            {recolhidas.has(n.id) ? "▸" : "▾"}
          </button>
          <button
            type="button"
            onclick={() => onSelecionarPasta(n.id)}
            class="text-sm text-left font-medium text-gray-800 hover:text-indigo-700"
          >
            📁 {n.nome}
          </button>
          <span class="flex gap-0.5 ml-auto opacity-0 group-hover:opacity-100 transition-opacity">
            <button type="button" aria-label={`Nova pasta em ${n.nome}`} onclick={() => abrirEditor("criar", "pasta", n.id)} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Nova subpasta">＋</button>
            <button type="button" aria-label={`Renomear pasta ${n.nome}`} onclick={() => abrirEditor("renomear", "pasta", n)} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Renomear">✏️</button>
            <button type="button" aria-label={`Mover pasta ${n.nome}`} onclick={() => abrirEditor("mover", "pasta", n)} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Mover">↔</button>
            <button type="button" aria-label={`Excluir pasta ${n.nome}`} onclick={() => onAcao("excluir-pasta", { id: n.id, nome: n.nome })} class="px-1 text-gray-400 hover:text-red-600 text-sm" title="Excluir">🗑</button>
          </span>
        </div>

        {#if vazioCriarAberto(n.id)}
          <div class="pl-6 pt-1 pb-1 flex items-center gap-1.5">
            <input
              type="text"
              placeholder="Nome da subpasta"
              bind:value={novoNome}
              data-criar-pasta
              class="flex-1 text-sm border border-gray-300 rounded-md px-2 py-1"
            />
            <button
              type="button"
              onclick={() => {
                onAcao("nova-pasta", { pai: n.id, nome: novoNome.trim() });
                editor = null;
                novoNome = "";
              }}
              class="text-sm px-2 py-1 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
            >
              Criar
            </button>
          </div>
        {/if}

        {#if vazioEditorAberto("pasta", n.id)}
          {#if editor.modo === "renomear"}
            <div class="pl-6 pt-1 pb-1 flex items-center gap-1.5">
              <input
                type="text"
                value={editor.nome}
                oninput={(e) => (editor.nome = e.currentTarget.value)}
                class="flex-1 text-sm border border-gray-300 rounded-md px-2 py-1"
              />
              <button
                type="button"
                onclick={() => {
                  onAcao("renomear-pasta", { id: n.id, nome: editor.nome });
                  editor = null;
                }}
                class="text-sm px-2 py-1 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
              >
                Salvar
              </button>
            </div>
          {:else if editor.modo === "mover"}
            <div class="pl-6 pt-1 pb-1 flex items-center gap-1.5">
              <select
                value={destino}
                onchange={(e) => (destino = e.currentTarget.value)}
                class="text-sm border border-gray-300 rounded-md px-2 py-1 flex-1"
              >
                {#each opcoesDestino() as o}
                  <option value={o.value}>{o.label}</option>
                {/each}
              </select>
              <button
                type="button"
                onclick={() => {
                  onAcao("mover-pasta", { id: n.id, novoPai: destino });
                  editor = null;
                }}
                class="text-sm px-2 py-1 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
              >
                Mover
              </button>
            </div>
          {/if}
        {/if}
      </div>
    {:else}
      <div class="group" style="padding-left:{n.nivel * 18}px">
        <div class="pl-6 flex items-center gap-1.5 rounded-md px-1.5 py-1 hover:bg-gray-50">
          <button
            type="button"
            aria-label={`Baixar ${n.doc.nome}`}
            onclick={() => onAcao("download-doc", { doc: n.doc })}
            class="text-sm text-gray-500 hover:text-indigo-600"
            title="Baixar versão atual"
          >
            📄
          </button>
          <span class="text-sm text-gray-800 truncate max-w-[38%]">{n.doc.nome}</span>
          <span class="text-[10px] bg-gray-200 text-gray-600 rounded px-1 py-px uppercase shrink-0">
            {rotuloMime(n.doc.mime)}
          </span>
          <span class="text-[10px] text-gray-400 shrink-0">
            v{n.doc.versao_atual} · {formatarTamanho(n.doc.tamanho)}
          </span>
          {#if (n.doc.tags ?? []).length}
            <span class="text-[10px] text-indigo-600 truncate shrink-0 hidden sm:inline">
              {n.doc.tags.join(", ")}
            </span>
          {/if}
          <span class="flex gap-0.5 ml-auto opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
            <button type="button" aria-label={`Ver versões de ${n.doc.nome}`} onclick={() => onAcao("versoes-doc", { doc: n.doc })} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Versões">📚</button>
            <button type="button" aria-label={`Ver histórico de ${n.doc.nome}`} onclick={() => onAcao("historico-doc", { doc: n.doc })} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Histórico">🕓</button>
            <button type="button" aria-label={`Editar tags de ${n.doc.nome}`} onclick={() => abrirEditor("tags", "doc", n.doc)} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Tags">🏷</button>
            <button type="button" aria-label={`Renomear documento ${n.doc.nome}`} onclick={() => abrirEditor("renomear", "doc", n.doc)} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Renomear">✏️</button>
            <button type="button" aria-label={`Mover documento ${n.doc.nome}`} onclick={() => abrirEditor("mover", "doc", n.doc)} class="px-1 text-gray-400 hover:text-indigo-600 text-sm" title="Mover">↔</button>
            <button type="button" aria-label={`Excluir documento ${n.doc.nome}`} onclick={() => onAcao("excluir-doc", { doc: n.doc })} class="px-1 text-gray-400 hover:text-red-600 text-sm" title="Excluir">🗑</button>
          </span>
        </div>

        {#if vazioEditorAberto("doc", n.doc.id) || (editor && editor.modo === "tags" && editor.doc?.id === n.doc.id)}
          {#if editor.modo === "renomear"}
            <div class="pl-6 pt-1 pb-1 flex items-center gap-1.5">
              <input
                type="text"
                value={editor.nome}
                oninput={(e) => (editor.nome = e.currentTarget.value)}
                class="flex-1 text-sm border border-gray-300 rounded-md px-2 py-1"
              />
              <button
                type="button"
                onclick={() => {
                  onAcao("renomear-doc", { id: n.doc.id, nome: editor.nome });
                  editor = null;
                }}
                class="text-sm px-2 py-1 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
              >
                Salvar
              </button>
            </div>
          {:else if editor.modo === "mover"}
            <div class="pl-6 pt-1 pb-1 flex items-center gap-1.5">
              <select
                value={destino}
                onchange={(e) => (destino = e.currentTarget.value)}
                class="text-sm border border-gray-300 rounded-md px-2 py-1 flex-1"
              >
                {#each opcoesDestino() as o}
                  <option value={o.value}>{o.label}</option>
                {/each}
              </select>
              <button
                type="button"
                onclick={() => {
                  onAcao("mover-doc", { id: n.doc.id, novoPai: destino });
                  editor = null;
                }}
                class="text-sm px-2 py-1 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
              >
                Mover
              </button>
            </div>
          {:else if editor.modo === "tags"}
            <div class="pl-6 pt-1 pb-1">
              <TagEditor
                tags={n.doc.tags}
                onAplicar={async (tags) => {
                  await onAcao("tags-doc", { doc: n.doc, tags });
                  editor = null;
                }}
                onFechar={() => (editor = null)}
              />
            </div>
          {/if}
        {/if}
      </div>
    {/if}
  {:else}
    <p class="text-sm text-gray-400 pl-2 py-2">
      Nenhuma pasta ou documento ainda. Envie o primeiro arquivo abaixo.
    </p>
  {/each}
</div>