<!-- src/features/gestor/components/planos/EvidenciaPicker.svelte -->
<script>
  // Escolhe a evidência de uma ação ou meta (#372): uma reunião (ata), uma
  // versão de documento já guardada ou uma nota. Só lista o que é da escola
  // do gestor (o backend recusa o resto). Nada é reenviado: o vínculo aponta
  // para a reunião ou para a versão do documento.
  import { fmtData } from "../../constants/planos.js";

  /** @type {{ origens: {reunioes: Array, documentos: Array} | null, onSalvar: (dados: object) => void, onCancelar: () => void, salvando?: boolean }} */
  let { origens, onSalvar, onCancelar, salvando = false } = $props();

  let tipo = $state("ata");
  let reuniaoId = $state("");
  let versaoId = $state("");
  let texto = $state("");

  let reunioes = $derived(origens?.reunioes ?? []);
  let documentos = $derived(origens?.documentos ?? []);
  let pronto = $derived(
    tipo === "ata" ? reuniaoId !== "" : tipo === "documento" ? versaoId !== "" : texto.trim() !== "",
  );

  function salvar() {
    if (!pronto) return;
    if (tipo === "ata") onSalvar({ tipo, reuniao_id: Number(reuniaoId) });
    else if (tipo === "documento") onSalvar({ tipo, documento_versao_id: Number(versaoId) });
    else onSalvar({ tipo, texto: texto.trim() });
  }

  const TIPOS = [
    { valor: "ata", rotulo: "Reunião / ata" },
    { valor: "documento", rotulo: "Documento" },
    { valor: "nota", rotulo: "Nota" },
  ];
</script>

<div class="rounded-md border border-blue-200 bg-blue-50 p-3 space-y-2" aria-label="Nova evidência">
  <div class="flex flex-wrap gap-3 text-xs" role="radiogroup" aria-label="Tipo de evidência">
    {#each TIPOS as t (t.valor)}
      <label class="flex items-center gap-1 text-gray-700">
        <input type="radio" name="tipo-evidencia" value={t.valor} bind:group={tipo} class="accent-blue-600" />
        {t.rotulo}
      </label>
    {/each}
  </div>

  {#if origens === null}
    <p class="text-xs text-gray-500">Carregando reuniões e documentos…</p>
  {:else if tipo === "ata"}
    {#if reunioes.length}
      <label class="block text-xs text-gray-600"><span class="block">Reunião</span>
        <select bind:value={reuniaoId} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
          <option value="">Escolha a reunião…</option>
          {#each reunioes as r (r.id)}
            <option value={String(r.id)}>{fmtData(r.quando)} · {r.titulo}{r.tem_ata ? " · com ata" : ""}</option>
          {/each}
        </select></label>
    {:else}
      <p class="text-xs text-gray-500">Nenhuma reunião registrada. Registre a reunião em Reuniões da escola.</p>
    {/if}
  {:else if tipo === "documento"}
    {#if documentos.length}
      <label class="block text-xs text-gray-600"><span class="block">Documento (versão)</span>
        <select bind:value={versaoId} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
          <option value="">Escolha o documento…</option>
          {#each documentos as d (d.versao_id)}
            <option value={String(d.versao_id)}>{d.nome} (v{d.versao}) · {fmtData(d.criado_em)}</option>
          {/each}
        </select></label>
      <p class="text-[11px] text-gray-500">A evidência fica presa a esta versão: uma versão nova do documento não a substitui.</p>
    {:else}
      <p class="text-xs text-gray-500">Nenhum documento guardado. Envie o arquivo em Documentos e planos.</p>
    {/if}
  {:else}
    <label class="block text-xs text-gray-600"><span class="block">Nota</span>
      <textarea bind:value={texto} maxlength="2000" rows="2" placeholder="Ex.: lista de presença afixada no mural em 10/03" class="mt-1 w-full px-2 py-1 rounded-md border border-gray-300 text-sm"></textarea></label>
  {/if}

  <div class="flex justify-end gap-2">
    <button type="button" onclick={onCancelar} class="px-3 py-1 rounded-md bg-gray-200 text-gray-700 text-xs hover:bg-gray-300">Cancelar</button>
    <button type="button" onclick={salvar} disabled={!pronto || salvando} class="px-3 py-1 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700 disabled:opacity-50">Ligar evidência</button>
  </div>
</div>
