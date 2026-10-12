<!-- src/features/gestor/components/envios/SegmentoForm.svelte -->
<script>
  // Formulário de lista dinâmica (segmento, issue #216): nome, listas da
  // escola, estados do inscrito, e-mail confirmado (sim/não/indiferente) e
  // período de inscrição. A prévia (contagem + amostra mascarada) é ao vivo,
  // com debounce, a cada mudança dos critérios.
  import { previaCriterios } from "../../api/gestorEnviosApi.js";
  import { ESTADOS_MEMBRO } from "../../constants/envios.js";
  import { ApiError } from "@/shared/api/client.js";

  const DEBOUNCE_MS = 300;

  /**
   * @type {{
   *   inep: string|number,
   *   segmento?: object|null,
   *   listas?: Array,
   *   ocupado?: boolean,
   *   erro?: string|null,
   *   onSalvar: (dados: {nome: string, criterios: object}) => void,
   *   onCancelar: () => void,
   *   onSessaoExpirada?: () => void,
   * }}
   */
  let {
    inep,
    segmento = null,
    listas = [],
    ocupado = false,
    erro = null,
    onSalvar,
    onCancelar,
    onSessaoExpirada = () => {},
  } = $props();

  // svelte-ignore state_referenced_locally
  const inicial = segmento;
  // svelte-ignore state_referenced_locally
  const idsExistentes = new Set(listas.map((l) => l.id));
  const c0 = inicial?.criterios ?? {};
  // listas que não existem mais saem do critério ao salvar (aviso abaixo)
  const listasExcluidas = (c0.listas ?? []).filter((id) => !idsExistentes.has(id));

  let nome = $state(inicial?.nome ?? "");
  let listasSel = $state((c0.listas ?? []).filter((id) => idsExistentes.has(id)));
  let estados = $state([...(c0.estado ?? [])]);
  let emailConfirmado = $state(
    c0.email_confirmado === true ? "sim" : c0.email_confirmado === false ? "nao" : "indiferente",
  );
  let desde = $state(c0.inscritos_desde ?? "");
  let ate = $state(c0.inscritos_ate ?? "");
  let erroLocal = $state(null);

  let previa = $state(null);
  let previaCarregando = $state(false);
  let erroPrevia = $state(null);
  let seq = 0;

  const criterios = $derived({
    listas: [...listasSel].sort((a, b) => a - b),
    estado: [...estados],
    email_confirmado: emailConfirmado === "sim" ? true : emailConfirmado === "nao" ? false : null,
    inscritos_desde: desde || null,
    inscritos_ate: ate || null,
  });
  const chave = $derived(JSON.stringify(criterios));

  function alternar(arr, valor) {
    return arr.includes(valor) ? arr.filter((v) => v !== valor) : [...arr, valor];
  }

  function validar() {
    if (!nome.trim()) return "Informe o nome da lista dinâmica.";
    if (criterios.listas.length === 0) return "Escolha pelo menos uma lista.";
    if (criterios.listas.length > 50) return "Escolha no máximo 50 listas.";
    if (desde && ate && desde > ate) return "A data inicial deve ser anterior à final.";
    return null;
  }

  async function atualizarPrevia(c) {
    const meu = ++seq;
    previaCarregando = true;
    erroPrevia = null;
    try {
      const r = await previaCriterios(inep, c);
      if (meu === seq) previa = r;
    } catch (err) {
      if (meu !== seq) return;
      if (err instanceof ApiError && err.status === 401) onSessaoExpirada();
      else erroPrevia = err instanceof ApiError ? err.message : "Não foi possível calcular a prévia.";
      previa = null;
    } finally {
      if (meu === seq) previaCarregando = false;
    }
  }

  // prévia ao vivo com debounce; sem lista escolhida (ou datas invertidas) não consulta
  $effect(() => {
    const c = JSON.parse(chave);
    if (c.listas.length === 0 || (c.inscritos_desde && c.inscritos_ate && c.inscritos_desde > c.inscritos_ate)) {
      seq += 1;
      previa = null;
      previaCarregando = false;
      return;
    }
    const t = setTimeout(() => atualizarPrevia(c), DEBOUNCE_MS);
    return () => clearTimeout(t);
  });

  function submeter() {
    const msg = validar();
    erroLocal = msg;
    if (msg) return;
    onSalvar({ nome: nome.trim(), criterios: JSON.parse(chave) });
  }

  const nomeLista = (id) => listas.find((l) => l.id === id)?.nome ?? `Lista #${id}`;
</script>

<form
  class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-4"
  data-testid="segmento-form"
  onsubmit={(e) => { e.preventDefault(); submeter(); }}
>
  <h2 class="text-base font-semibold text-gray-900">
    {inicial ? "Editar lista dinâmica" : "Nova lista dinâmica"}
  </h2>

  <label class="block text-sm text-gray-700">
    Nome
    <input
      bind:value={nome}
      maxlength="120"
      placeholder="Ex.: Confirmados 8º e 9º"
      class="mt-1 w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
    />
  </label>

  <fieldset class="space-y-1">
    <legend class="text-sm text-gray-700">Listas da escola</legend>
    {#if listas.length === 0}
      <p class="text-xs text-gray-400">A escola ainda não tem listas.</p>
    {:else}
      <div class="grid sm:grid-cols-2 gap-1">
        {#each listas as l (l.id)}
          <label class="flex items-center gap-2 text-sm text-gray-700">
            <input
              type="checkbox"
              checked={listasSel.includes(l.id)}
              onchange={() => (listasSel = alternar(listasSel, l.id))}
              class="accent-blue-600"
            />
            {l.nome}
          </label>
        {/each}
      </div>
    {/if}
    {#if listasExcluidas.length > 0}
      <p class="text-xs text-amber-700" data-testid="listas-excluidas-aviso">
        {listasExcluidas.length} lista(s) deste critério foram excluídas e saem dele ao salvar.
      </p>
    {/if}
  </fieldset>

  <fieldset class="space-y-1">
    <legend class="text-sm text-gray-700">Estado do inscrito <span class="text-xs text-gray-500">(nenhum marcado = todos)</span></legend>
    <div class="flex flex-wrap gap-3">
      {#each ESTADOS_MEMBRO as e (e.valor)}
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input
            type="checkbox"
            checked={estados.includes(e.valor)}
            onchange={() => (estados = alternar(estados, e.valor))}
            class="accent-blue-600"
          />
          {e.rotulo}
        </label>
      {/each}
    </div>
  </fieldset>

  <fieldset class="space-y-1">
    <legend class="text-sm text-gray-700">E-mail confirmado</legend>
    <div class="flex flex-wrap gap-3">
      {#each [["indiferente", "Indiferente"], ["sim", "Sim"], ["nao", "Não"]] as [valor, rotulo] (valor)}
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input type="radio" name="email-confirmado" value={valor} bind:group={emailConfirmado} class="accent-blue-600" />
          {rotulo}
        </label>
      {/each}
    </div>
  </fieldset>

  <div class="flex flex-wrap gap-3">
    <label class="block text-sm text-gray-700">
      Inscritos desde
      <input type="date" bind:value={desde} class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm bg-white" />
    </label>
    <label class="block text-sm text-gray-700">
      Inscritos até
      <input type="date" bind:value={ate} class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm bg-white" />
    </label>
  </div>

  <section class="rounded-md border border-gray-200 bg-gray-50 p-3 space-y-2" aria-live="polite" data-testid="segmento-previa">
    {#if criterios.listas.length === 0}
      <p class="text-xs text-gray-500">Escolha uma lista para ver quem entra.</p>
    {:else if erroPrevia}
      <p class="text-xs text-red-600">{erroPrevia}</p>
    {:else if previa}
      <p class="text-sm text-gray-800">
        <strong data-testid="segmento-previa-total">{previa.destinatarios}</strong> destinatário(s) com e-mail
        {#if previaCarregando}<span class="text-xs text-gray-400">(atualizando…)</span>{/if}
      </p>
      {#if previa.listas_ignoradas?.length > 0}
        <p class="text-xs text-amber-700" data-testid="segmento-previa-ignoradas">
          Listas ignoradas (excluídas): {previa.listas_ignoradas.map(nomeLista).join(", ")}.
        </p>
      {/if}
      {#if previa.amostra?.length > 0}
        <ul class="text-xs text-gray-600 space-y-0.5" aria-label="Amostra de destinatários">
          {#each previa.amostra as a, i (i)}
            <li>{a.nome ?? "—"} · <span class="font-mono">{a.email}</span></li>
          {/each}
        </ul>
      {/if}
    {:else}
      <p class="text-xs text-gray-500">Calculando…</p>
    {/if}
  </section>

  {#if erroLocal || erro}
    <p class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-3" role="alert">{erroLocal ?? erro}</p>
  {/if}

  <div class="flex justify-end gap-2">
    <button
      type="button"
      onclick={onCancelar}
      disabled={ocupado}
      class="px-4 h-9 rounded-md border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
    >Cancelar</button>
    <button
      type="submit"
      disabled={ocupado}
      class="px-4 h-9 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50"
    >Salvar lista dinâmica</button>
  </div>
</form>
