<!-- src/features/gestor/components/envios/EnvioEditor.svelte -->
<script>
  // Editor de rascunho de envio por e-mail (issue #216, Fase 3).
  // Alvo (lista ou lista dinâmica), operação, assunto e corpo em markdown
  // simples (prévia com TextoMarkdown, sem {@html}). "Pré-visualizar" mostra o
  // texto final com o rodapé e a estimativa de destinatários; "Enviar teste
  // para mim" manda só para o gestor; "Enviar agora" / "Agendar" pedem
  // confirmação com a contagem estimada. Toda ação salva o rascunho antes.
  import {
    createEnvio,
    atualizarEnvio,
    deleteEnvio,
    previaEnvio,
    testeEnvio,
    dispararEnvio,
  } from "../../api/gestorEnviosApi.js";
  import {
    OPERACOES,
    LIMITES_TEXTO,
    mensagemErroEnvio,
    localParaIsoUtc,
    formatarDataHora,
  } from "../../constants/envios.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import ConfirmDialog from "@/shared/ui/components/ConfirmDialog.svelte";
  import TextoMarkdown from "@/features/inscricao/components/TextoMarkdown.svelte";

  /**
   * @type {{
   *   inep: string|number,
   *   envio?: object|null,
   *   alvoInicial?: {tipo: string, id: number}|null,
   *   listas?: Array,
   *   segmentos?: Array,
   *   limites?: object|null,
   *   onSalvo?: (envio: object) => void,
   *   onDisparado?: (envio: object) => void,
   *   onApagado?: (id: number) => void,
   *   onFechar?: () => void,
   *   onSessaoExpirada?: () => void,
   * }}
   */
  let {
    inep,
    envio = null,
    alvoInicial = null,
    listas = [],
    segmentos = [],
    limites = null,
    onSalvo = () => {},
    onDisparado = () => {},
    onApagado = () => {},
    onFechar = () => {},
    onSessaoExpirada = () => {},
  } = $props();

  const chaveAlvo = (tipo, id) => (tipo && id != null ? `${tipo}:${id}` : "");

  // estado inicial do formulário (só na montagem: o editor é recriado por envio)
  // svelte-ignore state_referenced_locally
  const inicial = envio;
  // svelte-ignore state_referenced_locally
  const alvo0 = alvoInicial;
  let atual = $state(inicial);
  let form = $state({
    alvo: inicial
      ? chaveAlvo(inicial.alvo?.tipo, inicial.alvo?.id)
      : chaveAlvo(alvo0?.tipo, alvo0?.id),
    operacao: inicial?.operacao ?? "aviso",
    assunto: inicial?.assunto ?? "",
    corpo: inicial?.corpo ?? "",
  });

  let ocupado = $state(false);
  let erro = $state(null);
  let previa = $state(null); // {assunto, texto, estimativa}
  let agendarAberto = $state(false);
  let quando = $state(""); // datetime-local (hora local)
  let confirmando = $state(null); // {modo: "agora"|"agendar", estimativa, agendado_para}
  let disparando = $state(false);
  let erroDialogo = $state(null);
  let apagando = $state(false);
  let apagandoOcupado = $state(false);

  // o alvo pode ter sido excluído: mantém a opção para o gestor ver e trocar
  const alvoAusente = $derived.by(() => {
    if (!form.alvo) return null;
    const [tipo, id] = form.alvo.split(":");
    const fonte = tipo === "lista" ? listas : segmentos;
    if (fonte.some((x) => String(x.id) === id)) return null;
    const nome = atual?.alvo?.nome ?? null;
    return { valor: form.alvo, rotulo: nome ? `${nome} (indisponível)` : "Alvo excluído" };
  });

  function tratarErro(err, padrao) {
    if (err instanceof ApiError && err.status === 401) {
      onSessaoExpirada();
      return null;
    }
    return mensagemErroEnvio(err, padrao);
  }

  function validar() {
    if (!form.alvo) return "Escolha para quem enviar (lista ou lista dinâmica).";
    const assunto = form.assunto.trim();
    if (!assunto) return "Informe o assunto.";
    if (assunto.length > LIMITES_TEXTO.assunto) return `O assunto pode ter até ${LIMITES_TEXTO.assunto} caracteres.`;
    if (!form.corpo.trim()) return "Escreva a mensagem.";
    if (form.corpo.length > LIMITES_TEXTO.corpo) return `A mensagem pode ter até ${LIMITES_TEXTO.corpo} caracteres.`;
    return null;
  }

  function dadosForm() {
    const [alvo_tipo, alvo_id] = form.alvo.split(":");
    return {
      alvo_tipo,
      alvo_id: Number(alvo_id),
      operacao: form.operacao,
      assunto: form.assunto.trim(),
      corpo: form.corpo,
    };
  }

  function mudou(dados) {
    if (!atual) return true;
    return (
      atual.alvo?.tipo !== dados.alvo_tipo ||
      Number(atual.alvo?.id) !== dados.alvo_id ||
      atual.operacao !== dados.operacao ||
      atual.assunto !== dados.assunto ||
      atual.corpo !== dados.corpo
    );
  }

  /** Cria ou atualiza o rascunho; devolve o envio salvo (ou null em erro). */
  async function salvar({ avisar = false } = {}) {
    const msg = validar();
    if (msg) {
      erro = msg;
      return null;
    }
    const dados = dadosForm();
    if (!mudou(dados)) return atual;
    try {
      const salvo = atual
        ? await atualizarEnvio(inep, atual.id, dados)
        : await createEnvio(inep, dados);
      atual = { ...salvo, corpo: salvo.corpo ?? dados.corpo };
      previa = null;
      onSalvo(atual);
      if (avisar) addToast("Rascunho salvo.", "success");
      return atual;
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) {
        erro = "A lista escolhida não foi encontrada nesta escola.";
      } else {
        const m = tratarErro(err, "Não foi possível salvar o rascunho.");
        if (m) erro = m;
      }
      return null;
    }
  }

  async function executar(fn) {
    if (ocupado) return;
    ocupado = true;
    erro = null;
    try {
      await fn();
    } finally {
      ocupado = false;
    }
  }

  const salvarRascunho = () => executar(() => salvar({ avisar: true }));

  const previsualizar = () =>
    executar(async () => {
      const salvo = await salvar();
      if (!salvo) return;
      try {
        previa = await previaEnvio(inep, salvo.id);
      } catch (err) {
        const m = tratarErro(err, "Não foi possível gerar a prévia.");
        if (m) erro = m;
      }
    });

  const enviarTeste = () =>
    executar(async () => {
      const salvo = await salvar();
      if (!salvo) return;
      try {
        const r = await testeEnvio(inep, salvo.id);
        addToast(`Teste enviado para ${r?.para ?? "o seu e-mail"}.`, "success");
      } catch (err) {
        const m = tratarErro(err, "Não foi possível enviar o teste.");
        if (m) erro = m;
      }
    });

  function pedirDisparo(modo) {
    let agendado_para = null;
    if (modo === "agendar") {
      agendado_para = localParaIsoUtc(quando);
      if (!agendado_para) {
        erro = "Escolha a data e a hora do envio.";
        return;
      }
      if (new Date(agendado_para).getTime() <= Date.now()) {
        erro = "Escolha uma data e hora no futuro.";
        return;
      }
    }
    return executar(async () => {
      const salvo = await salvar();
      if (!salvo) return;
      try {
        const p = await previaEnvio(inep, salvo.id);
        previa = p;
        erroDialogo = null;
        confirmando = { modo, estimativa: p.estimativa, agendado_para };
      } catch (err) {
        const m = tratarErro(err, "Não foi possível calcular os destinatários.");
        if (m) erro = m;
      }
    });
  }

  async function confirmarDisparo() {
    if (!confirmando || !atual) return;
    disparando = true;
    erroDialogo = null;
    try {
      const r = await dispararEnvio(inep, atual.id, confirmando.agendado_para);
      const agendado = confirmando.modo === "agendar";
      confirmando = null;
      addToast(agendado ? "Envio agendado." : "Envio iniciado.", "success");
      onDisparado(r);
    } catch (err) {
      const m = tratarErro(err, "Não foi possível disparar o envio.");
      if (m) erroDialogo = m;
      else confirmando = null;
    } finally {
      disparando = false;
    }
  }

  async function confirmarApagar() {
    if (!atual) return;
    apagandoOcupado = true;
    try {
      await deleteEnvio(inep, atual.id);
      apagando = false;
      addToast("Rascunho apagado.", "success");
      onApagado(atual.id);
    } catch (err) {
      apagando = false;
      const m = tratarErro(err, "Não foi possível apagar o rascunho.");
      if (m) erro = m;
    } finally {
      apagandoOcupado = false;
    }
  }

  const descricaoConfirmacao = $derived.by(() => {
    if (!confirmando) return "";
    const n = confirmando.estimativa?.destinatarios ?? 0;
    const base = `${n} destinatário(s) vão receber "${form.assunto.trim()}"`;
    const quandoTxt =
      confirmando.modo === "agendar"
        ? ` em ${formatarDataHora(confirmando.agendado_para)}.`
        : " agora.";
    const ign = (confirmando.estimativa?.ignorados_optout ?? 0) + (confirmando.estimativa?.ignorados_duplicado ?? 0);
    return base + quandoTxt + (ign > 0 ? ` ${ign} endereço(s) ficam de fora (saíram da lista ou repetidos).` : "");
  });

  const bloqueado = $derived(
    Boolean(limites?.suspensao) || limites?.enabled === false || limites?.smtp_disponivel === false,
  );
</script>

<section class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-4" data-testid="envio-editor">
  <div class="flex items-center justify-between gap-2">
    <h2 class="text-base font-semibold text-gray-900">
      {atual ? "Editar rascunho" : "Novo envio"}
    </h2>
    <button
      type="button"
      onclick={onFechar}
      class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
    >← Voltar aos envios</button>
  </div>

  {#if limites}
    <p class="text-xs text-gray-600" data-testid="editor-saldo">
      Saldo de hoje: <strong>{limites.saldo_hoje}</strong> de {limites.cota_diaria} e-mail(s).
    </p>
  {/if}

  <form class="space-y-3" onsubmit={(e) => { e.preventDefault(); salvarRascunho(); }}>
    <div class="grid sm:grid-cols-2 gap-3">
      <label class="block text-sm text-gray-700">
        Enviar para
        <select
          bind:value={form.alvo}
          aria-label="Enviar para"
          class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white"
        >
          <option value="">Escolha uma lista…</option>
          {#if alvoAusente}
            <option value={alvoAusente.valor}>{alvoAusente.rotulo}</option>
          {/if}
          {#if listas.length > 0}
            <optgroup label="Listas">
              {#each listas as l (l.id)}
                <option value={`lista:${l.id}`}>{l.nome}</option>
              {/each}
            </optgroup>
          {/if}
          {#if segmentos.length > 0}
            <optgroup label="Listas dinâmicas">
              {#each segmentos as s (s.id)}
                <option value={`segmento:${s.id}`}>{s.nome}</option>
              {/each}
            </optgroup>
          {/if}
        </select>
      </label>
      <label class="block text-sm text-gray-700">
        Motivo (operação)
        <select
          bind:value={form.operacao}
          aria-label="Motivo (operação)"
          class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white"
        >
          {#each OPERACOES as o (o.valor)}
            <option value={o.valor}>{o.rotulo}</option>
          {/each}
        </select>
      </label>
    </div>

    <label class="block text-sm text-gray-700">
      Assunto
      <input
        bind:value={form.assunto}
        aria-label="Assunto"
        maxlength={LIMITES_TEXTO.assunto}
        class="mt-1 w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
    </label>

    <div class="grid md:grid-cols-2 gap-3">
      <label class="block text-sm text-gray-700">
        Mensagem
        <textarea
          bind:value={form.corpo}
          aria-label="Mensagem"
          rows="10"
          maxlength={LIMITES_TEXTO.corpo}
          class="mt-1 w-full px-3 py-2 rounded-md border border-gray-300 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500"
        ></textarea>
        <span class="block text-xs text-gray-500">
          Use linha em branco entre parágrafos, <code>- item</code> para listas e <code>**negrito**</code>.
          {form.corpo.length}/{LIMITES_TEXTO.corpo}
        </span>
      </label>
      <div class="text-sm text-gray-700">
        <p>Como fica</p>
        <div
          class="mt-1 min-h-[10rem] rounded-md border border-gray-200 bg-gray-50 p-3 space-y-2 text-sm text-gray-800"
          data-testid="corpo-previa"
          aria-label="Prévia da mensagem"
        >
          {#if form.corpo.trim()}
            <TextoMarkdown texto={form.corpo} />
          {:else}
            <p class="text-gray-400">A prévia aparece aqui.</p>
          {/if}
        </div>
      </div>
    </div>

    {#if erro}
      <p class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-3" role="alert" data-testid="editor-erro">{erro}</p>
    {/if}

    <div class="flex flex-wrap items-center gap-2">
      <button
        type="submit"
        disabled={ocupado}
        class="px-3 h-9 rounded-md bg-gray-200 text-gray-800 text-sm font-medium hover:bg-gray-300 disabled:opacity-50"
      >Salvar rascunho</button>
      <button
        type="button"
        disabled={ocupado}
        onclick={previsualizar}
        class="px-3 h-9 rounded-md border border-gray-300 text-gray-800 text-sm font-medium hover:bg-gray-50 disabled:opacity-50"
      >Pré-visualizar</button>
      <button
        type="button"
        disabled={ocupado || bloqueado}
        onclick={enviarTeste}
        class="px-3 h-9 rounded-md border border-gray-300 text-gray-800 text-sm font-medium hover:bg-gray-50 disabled:opacity-50"
      >Enviar teste para mim</button>
      <span class="grow"></span>
      <button
        type="button"
        disabled={ocupado || bloqueado}
        onclick={() => (agendarAberto = !agendarAberto)}
        aria-expanded={agendarAberto}
        class="px-3 h-9 rounded-md border border-blue-300 text-blue-700 text-sm font-medium hover:bg-blue-50 disabled:opacity-50"
      >Agendar…</button>
      <button
        type="button"
        disabled={ocupado || bloqueado}
        onclick={() => pedirDisparo("agora")}
        class="px-3 h-9 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50"
      >Enviar agora</button>
    </div>

    {#if agendarAberto}
      <div class="flex flex-wrap items-end gap-2 rounded-md border border-blue-200 bg-blue-50/50 p-3">
        <label class="block text-sm text-gray-700">
          Data e hora do envio
          <input
            type="datetime-local"
            bind:value={quando}
            aria-label="Data e hora do envio"
            class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm bg-white"
          />
        </label>
        <button
          type="button"
          disabled={ocupado || bloqueado}
          onclick={() => pedirDisparo("agendar")}
          class="px-3 h-9 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50"
        >Agendar</button>
      </div>
    {/if}

    {#if atual}
      <div class="pt-2 border-t border-gray-100">
        <button
          type="button"
          disabled={ocupado}
          onclick={() => (apagando = true)}
          class="px-2 py-1 rounded text-xs text-red-600 hover:bg-red-50 disabled:opacity-50"
        >Apagar rascunho</button>
      </div>
    {/if}
  </form>

  {#if previa}
    <section class="rounded-md border border-gray-200 p-3 space-y-2" data-testid="previa-final" aria-label="Prévia do e-mail">
      <h3 class="text-sm font-semibold text-gray-900">Prévia do e-mail</h3>
      <p class="text-xs text-gray-600" data-testid="previa-estimativa">
        Estimativa: <strong>{previa.estimativa?.destinatarios ?? 0}</strong> destinatário(s)
        {#if (previa.estimativa?.ignorados_optout ?? 0) > 0}
          · {previa.estimativa.ignorados_optout} saíram da lista
        {/if}
        {#if (previa.estimativa?.ignorados_duplicado ?? 0) > 0}
          · {previa.estimativa.ignorados_duplicado} repetido(s)
        {/if}
      </p>
      <p class="text-sm"><span class="text-gray-500">Assunto:</span> {previa.assunto}</p>
      <pre class="whitespace-pre-wrap break-words text-xs bg-gray-50 border border-gray-100 rounded p-3 text-gray-800">{previa.texto}</pre>
    </section>
  {/if}
</section>

{#if confirmando}
  <ConfirmDialog
    titulo={confirmando.modo === "agendar" ? "Agendar envio" : "Enviar agora"}
    descricao={descricaoConfirmacao}
    confirmarRotulo={confirmando.modo === "agendar" ? "Agendar" : "Enviar"}
    ocupado={disparando}
    erro={erroDialogo}
    onConfirmar={confirmarDisparo}
    onCancelar={() => (confirmando = null)}
    testid="disparo-dialog"
  />
{/if}

{#if apagando}
  <ConfirmDialog
    titulo="Apagar rascunho"
    descricao="O rascunho será apagado. Não pode ser desfeito."
    confirmarRotulo="Apagar"
    perigo
    ocupado={apagandoOcupado}
    onConfirmar={confirmarApagar}
    onCancelar={() => (apagando = false)}
    testid="apagar-envio-dialog"
  />
{/if}
