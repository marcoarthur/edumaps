<!-- src/features/gestor/pages/PlanoDetailPage.svelte -->
<script>
  // Plano de gestão (#371, épico #368): acompanhamento e edição na mesma
  // página. Objetivos → metas (indicador oficial ou manual, progresso,
  // medições) e ações (responsável, prazo, situação, recurso). Encerrado é só
  // leitura (pode ser reaberto). Exige sessão do gestor. Ações e metas têm
  // evidências (#372): ata de reunião, versão de documento ou nota.
  import { onMount } from "svelte";
  import {
    getPlano,
    updatePlano,
    arquivarPlano,
    getIndicadores,
    objetivos as objApi,
    metas as metaApi,
    acoes as acaoApi,
    createMedicao,
    deleteMedicao,
    getEvidenciaOrigens,
    createEvidencia,
    deleteEvidencia,
  } from "../api/gestorPlanosApi.js";
  import { downloadDocumento, getDocumentos } from "../api/gestorDocumentosApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { criarEnvio } from "@/shared/utils/envio.svelte.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    PLANO_TIPO_LABEL,
    PLANO_SITUACAO_LABEL,
    PLANO_SITUACAO_BADGE,
    ACAO_SITUACOES,
    ACAO_SITUACAO_LABEL,
    FONTES_RECURSO,
    FONTE_RECURSO_LABEL,
    SENTIDOS,
    META_ESTADO_LABEL,
    PLANO_LIMITS as L,
    pct,
    sugerirIndicador,
    fmtData,
    fmtNum,
    fmtComUnidade,
  } from "../constants/planos.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import MetaHistorico from "../components/planos/MetaHistorico.svelte";
  import EvidenciaPicker from "../components/planos/EvidenciaPicker.svelte";

  const planoId = Number(new URL(location.href).pathname.match(/\/(\d+)$/)?.[1]);

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);
  let plano = $state(null);
  let indicadores = $state([]);

  let objetivoForm = $state(null);
  // edição (#383): { id, titulo } do objetivo em edição; metaForm/acaoForm com
  // `id` editam o item existente (sem `id`, criam um novo).
  let objetivoEdit = $state(null);
  // arquivo do plano em Documentos e planos (#385): lista carregada ao escolher
  let documentosEscola = $state(null);
  let escolhendoDoc = $state(false);
  let docEscolhido = $state("");
  let metaForm = $state(null);
  let acaoForm = $state(null);
  let medicaoForm = $state(null);
  // { dono: "acao"|"meta", id } — onde o seletor de evidência está aberto
  let evidenciaPara = $state(null);
  let origens = $state(null);
  let salvandoEvidencia = $state(false);

  let editavel = $derived(plano && plano.situacao !== "encerrado");

  // Hoje e +7 dias (data local, AAAA-MM-DD) para "vence em 7 dias". O
  // "atrasada" vem do backend (America/Sao_Paulo).
  const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  const hoje = iso(new Date());
  const limite7 = iso(new Date(Date.now() + 7 * 86400000));
  const aberta = (a) => a.situacao === "nao_iniciada" || a.situacao === "em_andamento";

  let todasAcoes = $derived(plano ? plano.objetivos.flatMap((o) => o.acoes) : []);
  let atrasadas = $derived(todasAcoes.filter((a) => a.atrasada));
  let vencendo = $derived(
    todasAcoes.filter((a) => aberta(a) && !a.atrasada && a.prazo && a.prazo >= hoje && a.prazo <= limite7),
  );
  const metasDoObjetivo = (oid) => plano?.objetivos.find((o) => o.id === oid)?.metas ?? [];
  const indicadorDe = (codigo) => indicadores.find((i) => i.codigo === codigo);

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      const [p, ind] = await Promise.all([getPlano(me.cod_inep, planoId), getIndicadores(me.cod_inep)]);
      plano = p;
      indicadores = ind.indicadores ?? [];
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar o plano.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function recarregar() {
    plano = await getPlano(inep, planoId);
  }

  // Uma mudança por vez: enquanto uma está em curso, os botões que mudam o
  // plano ficam desabilitados e um segundo clique é ignorado (sem réplica).
  const envio = criarEnvio();

  // Executa uma mudança, mostra o toast e recarrega o plano (o progresso é
  // recalculado no backend).
  const mudar = envio.travar(async (fn, ok, padrao) => {
    try {
      await fn();
      if (ok) addToast(ok, "success");
      await recarregar();
      return true;
    } catch (err) {
      const msg = onApiError(err, padrao);
      if (msg) addToast(msg, "error");
      return false;
    }
  });

  // --- plano -----------------------------------------------------------------
  const situacao = (nova, ok) =>
    mudar(() => updatePlano(inep, planoId, { situacao: nova }), ok, "Não foi possível mudar a situação do plano.");

  const alternarAlertas = () =>
    mudar(
      () => updatePlano(inep, planoId, { alertas_ativos: !plano.alertas_ativos }),
      plano.alertas_ativos ? "Alertas de prazo desligados." : "Alertas de prazo ligados.",
      "Não foi possível mudar os alertas.",
    );

  const arquivar = envio.travar(async () => {
    if (!window.confirm(`Arquivar o plano "${plano.titulo}"? Ele sai da lista, mas não é apagado.`)) return;
    try {
      await arquivarPlano(inep, planoId);
      addToast("Plano arquivado.", "success");
      window.location.href = "/gestor/planos";
    } catch (err) {
      const msg = onApiError(err, "Não foi possível arquivar o plano.");
      if (msg) addToast(msg, "error");
    }
  });

  // --- objetivos ---------------------------------------------------------------
  async function salvarObjetivo() {
    if (!objetivoForm.titulo.trim()) {
      addToast("Dê um título ao objetivo.", "warning");
      return;
    }
    const ok = await mudar(
      () => objApi.create(inep, planoId, { titulo: objetivoForm.titulo.trim() }),
      "Objetivo adicionado.",
      "Não foi possível adicionar o objetivo.",
    );
    if (ok) objetivoForm = null;
  }

  async function salvarObjetivoEdit() {
    if (!objetivoEdit.titulo.trim()) {
      addToast("Dê um título ao objetivo.", "warning");
      return;
    }
    const ok = await mudar(
      () => objApi.update(inep, planoId, objetivoEdit.id, { titulo: objetivoEdit.titulo.trim() }),
      "Objetivo atualizado.",
      "Não foi possível atualizar o objetivo.",
    );
    if (ok) objetivoEdit = null;
  }

  async function excluirObjetivo(o) {
    if (!window.confirm(`Excluir o objetivo "${o.titulo}" com as metas e ações dele?`)) return;
    await mudar(() => objApi.remove(inep, planoId, o.id), "Objetivo excluído.", "Não foi possível excluir o objetivo.");
  }

  // --- metas ---------------------------------------------------------------------
  function novaMeta(o) {
    metaForm = { objetivo_id: o.id, descricao: "", indicador_codigo: "", sentido: "aumentar",
                 unidade: "", linha_base: "", alvo: "", prazo: "" };
  }

  const txt = (v) => (v === null || v === undefined ? "" : String(v));

  function editarMeta(m) {
    acaoForm = null;
    metaForm = { id: m.id, objetivo_id: m.objetivo_id, descricao: m.descricao, indicador_codigo: m.indicador_codigo ?? "",
                 sentido: m.sentido, unidade: txt(m.unidade), linha_base: txt(m.linha_base), alvo: txt(m.alvo),
                 prazo: m.prazo ?? "", linha_base_oficial: txt(m.linha_base_oficial) };
  }

  // Sugestão de indicador oficial para meta manual nova (#397): só sugere, a
  // escola pode manter a meta manual ("Manter meta manual" esconde o aviso).
  let sugestao = $derived(
    metaForm && !metaForm.id && !metaForm.indicador_codigo && !metaForm.sugestaoDispensada
      && metaForm.descricao.trim().length >= 4
      ? sugerirIndicador(metaForm.descricao, indicadores)
      : null,
  );

  function usarSugestao() {
    metaForm.indicador_codigo = sugestao.codigo;
    escolherIndicador();
  }

  function escolherIndicador() {
    const ind = indicadorDe(metaForm.indicador_codigo);
    if (ind) {
      metaForm.sentido = ind.sentido_sugerido;
      if (!metaForm.descricao.trim()) metaForm.descricao = ind.rotulo;
    }
  }

  async function salvarMeta() {
    if (!metaForm.descricao.trim()) {
      addToast("Descreva a meta.", "warning");
      return;
    }
    const oficial = !!metaForm.indicador_codigo;
    if (metaForm.id) {
      // edição: o indicador não muda (para trocar, crie outra meta)
      const campos = {
        descricao: metaForm.descricao.trim(),
        sentido: metaForm.sentido,
        linha_base: metaForm.linha_base === "" ? null : metaForm.linha_base,
        alvo: metaForm.alvo === "" ? null : metaForm.alvo,
        prazo: metaForm.prazo || null,
      };
      if (!oficial) campos.unidade = metaForm.unidade.trim() || null;
      const ok = await mudar(() => metaApi.update(inep, planoId, metaForm.id, campos), "Meta atualizada.",
        "Não foi possível atualizar a meta.");
      if (ok) metaForm = null;
      return;
    }
    const dados = {
      objetivo_id: metaForm.objetivo_id,
      descricao: metaForm.descricao.trim(),
      sentido: metaForm.sentido,
      alvo: metaForm.alvo === "" ? null : metaForm.alvo,
      prazo: metaForm.prazo || null,
    };
    if (oficial) {
      dados.indicador_codigo = metaForm.indicador_codigo;
      // sem linha de base: o backend sugere o último valor da escola
      if (metaForm.linha_base !== "") dados.linha_base = metaForm.linha_base;
    } else {
      dados.unidade = metaForm.unidade.trim() || null;
      dados.linha_base = metaForm.linha_base === "" ? null : metaForm.linha_base;
    }
    const ok = await mudar(() => metaApi.create(inep, planoId, dados), "Meta adicionada.", "Não foi possível adicionar a meta.");
    if (ok) metaForm = null;
  }

  async function excluirMeta(m) {
    if (!window.confirm(`Excluir a meta "${m.descricao}"?`)) return;
    await mudar(() => metaApi.remove(inep, planoId, m.id), "Meta excluída.", "Não foi possível excluir a meta.");
  }

  function novaMedicao(m) {
    medicaoForm = { meta_id: m.id, data_ref: hoje, valor: "", nota: "" };
  }

  async function salvarMedicao() {
    if (medicaoForm.valor === "" || !medicaoForm.data_ref) {
      addToast("Informe a data e o valor da medição.", "warning");
      return;
    }
    const ok = await mudar(
      () => createMedicao(inep, planoId, medicaoForm.meta_id, {
        data_ref: medicaoForm.data_ref, valor: medicaoForm.valor, nota: medicaoForm.nota.trim() || null,
      }),
      "Medição registrada.",
      "Não foi possível registrar a medição.",
    );
    if (ok) medicaoForm = null;
  }

  const excluirMedicao = (m, med) =>
    mudar(() => deleteMedicao(inep, planoId, m.id, med.id), "Medição excluída.", "Não foi possível excluir a medição.");

  // --- ações ---------------------------------------------------------------------
  function novaAcao(o) {
    acaoForm = { objetivo_id: o.id, meta_id: "", descricao: "", responsavel: "", inicio: "", prazo: "",
                 custo_previsto: "", fonte_recurso: "", custo_executado: "", executado_em: "" };
  }

  function editarAcao(a) {
    metaForm = null;
    acaoForm = { id: a.id, objetivo_id: a.objetivo_id, meta_id: a.meta_id ? String(a.meta_id) : "", descricao: a.descricao,
                 responsavel: txt(a.responsavel), inicio: a.inicio ?? "", prazo: a.prazo ?? "",
                 custo_previsto: txt(a.custo_previsto), fonte_recurso: a.fonte_recurso ?? "",
                 custo_executado: txt(a.custo_executado), executado_em: a.executado_em ?? "" };
  }

  async function salvarAcao() {
    if (!acaoForm.descricao.trim()) {
      addToast("Descreva a ação.", "warning");
      return;
    }
    if (acaoForm.inicio && acaoForm.prazo && acaoForm.prazo < acaoForm.inicio) {
      addToast("O prazo da ação não pode ser antes do início.", "warning");
      return;
    }
    const campos = {
      meta_id: acaoForm.meta_id === "" ? null : Number(acaoForm.meta_id),
      descricao: acaoForm.descricao.trim(),
      responsavel: acaoForm.responsavel.trim() || null,
      inicio: acaoForm.inicio || null,
      prazo: acaoForm.prazo || null,
      custo_previsto: acaoForm.custo_previsto === "" ? null : acaoForm.custo_previsto,
      custo_executado: acaoForm.custo_executado === "" ? null : acaoForm.custo_executado,
      executado_em: acaoForm.executado_em || null,
      fonte_recurso: acaoForm.fonte_recurso || null,
    };
    const ok = acaoForm.id
      ? await mudar(() => acaoApi.update(inep, planoId, acaoForm.id, campos), "Ação atualizada.",
          "Não foi possível atualizar a ação.")
      : await mudar(() => acaoApi.create(inep, planoId, { objetivo_id: acaoForm.objetivo_id, ...campos }),
          "Ação adicionada.", "Não foi possível adicionar a ação.");
    if (ok) acaoForm = null;
  }

  const mudarSituacaoAcao = (a, nova) =>
    mudar(() => acaoApi.update(inep, planoId, a.id, { situacao: nova }), null, "Não foi possível mudar a ação.");

  async function excluirAcao(a) {
    if (!window.confirm(`Excluir a ação "${a.descricao}"?`)) return;
    await mudar(() => acaoApi.remove(inep, planoId, a.id), "Ação excluída.", "Não foi possível excluir a ação.");
  }

  // --- evidências (#372) -------------------------------------------------------------
  async function abrirEvidencia(dono, id) {
    evidenciaPara = { dono, id };
    if (origens) return;
    try {
      origens = await getEvidenciaOrigens(inep);
    } catch (err) {
      evidenciaPara = null;
      const msg = onApiError(err, "Não foi possível carregar as reuniões e os documentos.");
      if (msg) addToast(msg, "error");
    }
  }

  async function ligarEvidencia(dados) {
    salvandoEvidencia = true;
    const campo = evidenciaPara.dono === "acao" ? "acao_id" : "meta_id";
    const ok = await mudar(
      () => createEvidencia(inep, planoId, { ...dados, [campo]: evidenciaPara.id }),
      "Evidência ligada.",
      "Não foi possível ligar a evidência.",
    );
    salvandoEvidencia = false;
    if (ok) evidenciaPara = null;
  }

  async function desligarEvidencia(ev) {
    const nome = ev.tipo === "nota" ? "esta nota" : `"${ev.titulo}"`;
    if (!window.confirm(`Tirar ${nome} das evidências? A reunião ou o documento não são apagados.`)) return;
    await mudar(() => deleteEvidencia(inep, planoId, ev.id), "Evidência retirada.", "Não foi possível retirar a evidência.");
  }

  // --- arquivo do plano (#385) ------------------------------------------------------
  async function escolherArquivo() {
    docEscolhido = plano.documento ? String(plano.documento.id) : "";
    escolhendoDoc = true;
    if (documentosEscola) return;
    try {
      documentosEscola = (await getDocumentos(inep)).documentos ?? [];
    } catch (err) {
      escolhendoDoc = false;
      const msg = onApiError(err, "Não foi possível carregar os documentos da escola.");
      if (msg) addToast(msg, "error");
    }
  }

  async function salvarArquivo(id) {
    const ok = await mudar(
      () => updatePlano(inep, planoId, { documento_id: id }),
      id ? "Arquivo do plano ligado." : "Arquivo do plano desligado.",
      "Não foi possível mudar o arquivo do plano.",
    );
    if (ok) escolhendoDoc = false;
  }

  async function desligarArquivo() {
    if (!window.confirm("Desligar o arquivo do plano? O documento continua em Documentos e planos.")) return;
    await salvarArquivo(null);
  }

  const baixarArquivo = () => baixar(plano.documento.id, null);
  const baixarEvidencia = (ev) => baixar(ev.documento_id, ev.versao);

  async function baixar(documentoId, versao) {
    try {
      const { blob, filename } = await downloadDocumento(inep, documentoId, versao);
      const url = window.URL.createObjectURL(blob);
      const a = window.document.createElement("a");
      a.href = url;
      a.download = filename;
      window.document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível baixar o documento.");
      if (msg) addToast(msg, "error");
    }
  }

  const abertoPara = (dono, id) => evidenciaPara?.dono === dono && evidenciaPara?.id === id;

  // --- sessão ----------------------------------------------------------------------
  async function sair() {
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      gestor = null;
      precisaLogin = true;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregar();
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });

  const metaDescricao = (oid, mid) => metasDoObjetivo(oid).find((m) => m.id === mid)?.descricao;
  const barra = (v) => `width: ${Math.round((v ?? 0) * 100)}%`;
</script>

{#snippet progresso(p, rotulo)}
  {#if p?.valor !== null && p?.valor !== undefined}
    <div class="flex items-center gap-2" aria-label={`${rotulo}: ${pct(p.valor)}`}>
      <div class="h-2 flex-1 rounded-full bg-gray-200 overflow-hidden"><div class="h-2 bg-green-600" style={barra(p.valor)}></div></div>
      <span class="text-xs font-semibold text-gray-800 w-10 text-right">{pct(p.valor)}</span>
    </div>
  {:else}
    <p class="text-xs text-gray-500">Sem metas medidas ainda.</p>
  {/if}
  {#if p}<p class="text-[11px] text-gray-500">{p.n_medidas} de {p.n_metas} meta(s) medida(s)</p>{/if}
{/snippet}

{#snippet formMeta(o)}
  <div class="rounded-md border border-blue-200 bg-blue-50 p-3 space-y-2">
    {#if metaForm.id}
      <p class="text-xs text-gray-600">
        {metaForm.indicador_codigo ? `Indicador oficial: ${indicadorDe(metaForm.indicador_codigo)?.rotulo ?? metaForm.indicador_codigo}.` : "Meta manual."}
        O tipo da meta não muda na edição; para trocar, crie outra meta.
      </p>
    {:else}
    <label class="block text-xs text-gray-600"><span class="block">Indicador oficial (opcional)</span>
      <select bind:value={metaForm.indicador_codigo} onchange={escolherIndicador} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
        <option value="">Meta manual (o valor é informado pela escola)</option>
        {#each indicadores as i (i.codigo)}
          <option value={i.codigo}>{i.rotulo} — {i.ultimo ? `${fmtNum(i.ultimo.valor)} (${i.ultimo.ano})` : "sem dado"}</option>
        {/each}
      </select></label>
    {/if}
    {#if metaForm.indicador_codigo && !metaForm.id}
      {@const ind = indicadorDe(metaForm.indicador_codigo)}
      <p class="text-xs text-gray-600">
        Fonte: {ind?.fonte}. {#if ind?.ultimo}Último valor da escola: {fmtNum(ind.ultimo.valor)} ({ind.ultimo.ano}) — vira a linha de base se você não informar outra.{:else}A fonte não tem valor desta escola: a meta fica "sem dado" até a fonte trazer.{/if}
      </p>
    {/if}
    <label class="block text-xs text-gray-600"><span class="block">Meta *</span>
      <input bind:value={metaForm.descricao} maxlength={L.DESCRICAO_MAX} placeholder="Ex.: Reduzir as faltas para 12%" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
    {#if sugestao}
      <div class="rounded-md border border-indigo-200 bg-indigo-50 p-2 text-xs text-indigo-900 space-y-1" role="status" aria-label="Sugestão de indicador oficial">
        <p>
          Esta meta parece com o indicador oficial <strong>{sugestao.rotulo}</strong>. Com o indicador, o valor vem
          da fonte e a secretaria consegue comparar com as outras escolas da rede.
        </p>
        <div class="flex gap-2">
          <button type="button" onclick={usarSugestao} class="px-2 py-0.5 rounded bg-indigo-600 text-white hover:bg-indigo-700">Usar este indicador</button>
          <button type="button" onclick={() => (metaForm.sugestaoDispensada = true)} class="px-2 py-0.5 rounded bg-white border border-indigo-200 hover:bg-indigo-100">Manter meta manual</button>
        </div>
      </div>
    {/if}
    <div class="grid gap-2 sm:grid-cols-4">
      <label class="text-xs text-gray-600"><span class="block">Sentido</span>
        <select bind:value={metaForm.sentido} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
          {#each SENTIDOS as s (s.valor)}<option value={s.valor}>{s.rotulo}</option>{/each}
        </select></label>
      <label class="text-xs text-gray-600"><span class="block">Linha de base</span>
        <input bind:value={metaForm.linha_base} inputmode="decimal" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      <label class="text-xs text-gray-600"><span class="block">Alvo</span>
        <input bind:value={metaForm.alvo} inputmode="decimal" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      <label class="text-xs text-gray-600"><span class="block">Prazo</span>
        <input type="date" bind:value={metaForm.prazo} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
    </div>
    <p class="text-xs text-gray-600">
      <strong>Sentido:</strong> se o valor deve aumentar, diminuir ou não cair abaixo do alvo.
      <strong>Linha de base:</strong> o valor de partida, de onde o andamento é medido até o alvo.
    </p>
    {#if metaForm.id && metaForm.indicador_codigo && metaForm.linha_base_oficial !== ""}
      <p class="text-xs text-amber-800">
        Valor oficial da fonte quando a meta foi criada: <strong>{fmtNum(Number(metaForm.linha_base_oficial))}</strong>.
        Uma linha de base diferente aparece como <strong>ajustada pela escola</strong>, na tela e no relatório.
      </p>
    {/if}
    {#if !metaForm.indicador_codigo}
      <label class="block text-xs text-gray-600"><span class="block">Unidade</span>
        <input bind:value={metaForm.unidade} maxlength="40" placeholder="Ex.: %, alunos, professores" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
    {/if}
    <div class="flex justify-end gap-2">
      <button type="button" onclick={() => (metaForm = null)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Cancelar</button>
      <button type="button" disabled={envio.ocupado} onclick={salvarMeta} class="disabled:opacity-50 disabled:cursor-not-allowed px-4 py-1.5 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">{envio.ocupado ? "Salvando…" : metaForm.id ? "Salvar alterações" : "Salvar meta"}</button>
    </div>
  </div>
{/snippet}

{#snippet formAcao(o)}
  <div class="rounded-md border border-blue-200 bg-blue-50 p-3 space-y-2">
    <label class="block text-xs text-gray-600"><span class="block">Ação *</span>
      <input bind:value={acaoForm.descricao} maxlength={L.DESCRICAO_MAX} placeholder="Ex.: Reforço de leitura no contraturno" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
    <div class="grid gap-2 sm:grid-cols-3">
      <label class="text-xs text-gray-600"><span class="block">Responsável</span>
        <input bind:value={acaoForm.responsavel} maxlength={L.RESPONSAVEL_MAX} placeholder="Ex.: Coordenação pedagógica" aria-describedby="dica-responsavel" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" />
        <span id="dica-responsavel" class="block mt-1 text-[11px] text-gray-500">Prefira o cargo ou a equipe ao nome: o responsável aparece no relatório.</span></label>
      <label class="text-xs text-gray-600"><span class="block">Início</span>
        <input type="date" bind:value={acaoForm.inicio} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      <label class="text-xs text-gray-600"><span class="block">Prazo</span>
        <input type="date" bind:value={acaoForm.prazo} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
    </div>
    <div class="grid gap-2 sm:grid-cols-3">
      <label class="text-xs text-gray-600"><span class="block">Contribui para a meta</span>
        <select bind:value={acaoForm.meta_id} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
          <option value="">Nenhuma em especial</option>
          {#each o.metas as m (m.id)}<option value={String(m.id)}>{m.descricao}</option>{/each}
        </select></label>
      <label class="text-xs text-gray-600"><span class="block">Custo previsto (R$)</span>
        <input bind:value={acaoForm.custo_previsto} inputmode="decimal" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      <label class="text-xs text-gray-600"><span class="block">Fonte do recurso</span>
        <select bind:value={acaoForm.fonte_recurso} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
          <option value="">—</option>
          {#each FONTES_RECURSO as f (f.valor)}<option value={f.valor}>{f.rotulo}</option>{/each}
        </select></label>
    </div>
    <div class="grid gap-2 sm:grid-cols-3">
      <label class="text-xs text-gray-600"><span class="block">Custo executado (R$)</span>
        <input bind:value={acaoForm.custo_executado} inputmode="decimal" placeholder="Quanto já foi gasto" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      <label class="text-xs text-gray-600"><span class="block">Executado em</span>
        <input type="date" bind:value={acaoForm.executado_em} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      <p class="text-xs text-gray-500 self-end">Deixe em branco o que ainda não foi gasto: vazio não conta como R$ 0.</p>
    </div>
    <div class="flex justify-end gap-2">
      <button type="button" onclick={() => (acaoForm = null)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Cancelar</button>
      <button type="button" disabled={envio.ocupado} onclick={salvarAcao} class="disabled:opacity-50 disabled:cursor-not-allowed px-4 py-1.5 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">{envio.ocupado ? "Salvando…" : acaoForm.id ? "Salvar alterações" : "Salvar ação"}</button>
    </div>
  </div>
{/snippet}

{#snippet linhaAcao(a)}
  <span class="text-gray-800">{a.descricao}</span>
  <span class="text-xs text-gray-500">{" · prazo "}{fmtData(a.prazo)}{#if a.responsavel}{" · "}{a.responsavel}{/if}</span>
{/snippet}

{#snippet evidencias(lista, dono, id, rotulo)}
  <div class="space-y-1" aria-label={`Evidências de ${rotulo}`}>
    {#if lista.length}
      <ul class="space-y-0.5 text-xs">
        {#each lista as ev (ev.id)}
          <li class="flex items-start gap-1.5">
            <span aria-hidden="true">{ev.tipo === "ata" ? "🗓️" : ev.tipo === "documento" ? "📄" : "📝"}</span>
            <span class="min-w-0 flex-1">
              {#if ev.tipo === "nota"}
                <span class="text-gray-700 whitespace-pre-line">{ev.texto}</span>
              {:else if ev.origem_removida}
                <span class="text-gray-500">{ev.titulo ?? "Sem título"}</span>
                <span class="ml-1 text-[10px] uppercase text-gray-500 font-semibold">origem removida</span>
              {:else if ev.tipo === "ata"}
                <a href={`/gestor/reunioes/${ev.reuniao_id}`} class="text-blue-700 hover:underline">{ev.titulo}</a>
                {#if ev.quando}<span class="text-gray-500">{" · "}{fmtData(ev.quando)}</span>{/if}
              {:else}
                <button type="button" onclick={() => baixarEvidencia(ev)} class="text-blue-700 hover:underline text-left" title="Baixar esta versão">{ev.titulo}</button>
              {/if}
            </span>
            {#if editavel}
              <button type="button" disabled={envio.ocupado} onclick={() => desligarEvidencia(ev)} aria-label={`Retirar evidência ${ev.titulo ?? ev.texto}`} class="disabled:opacity-50 disabled:cursor-not-allowed text-red-600 hover:underline shrink-0">✕</button>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
    {#if editavel}
      {#if abertoPara(dono, id)}
        <EvidenciaPicker {origens} salvando={salvandoEvidencia} onSalvar={ligarEvidencia} onCancelar={() => (evidenciaPara = null)} />
      {:else}
        <button type="button" onclick={() => abrirEvidencia(dono, id)} class="text-xs text-blue-700 hover:underline">+ Evidência</button>
      {/if}
    {/if}
  </div>
{/snippet}

<div class="space-y-6 max-w-4xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div class="min-w-0">
      <h1 class="text-2xl font-bold text-gray-900">{plano?.titulo ?? "Plano"}</h1>
      {#if plano}
        <p class="text-sm text-gray-600 mt-1">
          {PLANO_TIPO_LABEL[plano.tipo] ?? plano.tipo}
          {#if plano.inicio || plano.fim}{" · "}{fmtData(plano.inicio)} a {fmtData(plano.fim)}{/if}
          <span class={`ml-2 px-2 py-0.5 rounded-full text-[11px] font-medium ${PLANO_SITUACAO_BADGE[plano.situacao] ?? ""}`}>{PLANO_SITUACAO_LABEL[plano.situacao] ?? plano.situacao}</span>
        </p>
      {/if}
    </div>
    <div class="flex items-center gap-2">
      {#if gestor}
        <button type="button" onclick={sair} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors">Sair</button>
      {/if}
      {#if plano}
        <a href={`/gestor/planos/${planoId}/relatorio`} data-tour="plano-relatorio" class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors">🖨️ Relatório</a>
      {/if}
      <a href="/gestor/planos" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">← Planos</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando plano…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver o plano." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if plano}
    <!-- quem mais vê o plano (#407, P1-RD-01) -->
    <p class="rounded-md bg-slate-50 border border-slate-200 text-slate-700 text-xs px-3 py-2" aria-label="Quem vê o plano">
      Se a secretaria de educação da sua rede usa o EduMaps, ela vê este plano e o relatório, só para leitura. Quem edita é a escola.
    </p>
    <!-- resumo e situação -->
    <section class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-3" data-tour="plano-resumo">
      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <h2 class="text-xs font-semibold uppercase text-gray-500">Andamento das metas</h2>
          {@render progresso(plano.resumo.progresso, "Andamento do plano")}
        </div>
        <div class="text-sm text-gray-700">
          <p>{plano.resumo.n_acoes_concluidas} de {plano.resumo.n_acoes} ação(ões) concluída(s)</p>
          {#if plano.resumo.n_acoes_atrasadas > 0}
            <p class="text-red-700 font-semibold">{plano.resumo.n_acoes_atrasadas} ação(ões) atrasada(s)</p>
          {/if}
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2 text-sm" role="group" aria-label="Arquivo do plano" data-tour="plano-arquivo">
        <span class="text-xs font-semibold uppercase text-gray-500">Arquivo do plano</span>
        {#if escolhendoDoc}
          {#if documentosEscola === null}
            <span class="text-xs text-gray-500">Carregando documentos…</span>
          {:else if documentosEscola.length}
            <select bind:value={docEscolhido} aria-label="Documento do plano" class="h-8 px-2 rounded-md border border-gray-300 text-xs bg-white max-w-xs">
              <option value="">Escolha o documento…</option>
              {#each documentosEscola as d (d.id)}<option value={String(d.id)}>{d.nome} (v{d.versao_atual})</option>{/each}
            </select>
            <button type="button" onclick={() => salvarArquivo(Number(docEscolhido))} disabled={envio.ocupado || !docEscolhido} class="px-3 py-1 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700 disabled:opacity-50">Ligar</button>
          {:else}
            <span class="text-xs text-gray-500">Nenhum documento guardado. Envie o arquivo em Documentos e planos.</span>
          {/if}
          <button type="button" onclick={() => (escolhendoDoc = false)} class="px-3 py-1 rounded-md bg-gray-200 text-gray-700 text-xs hover:bg-gray-300">Cancelar</button>
        {:else if plano.documento}
          <button type="button" onclick={baixarArquivo} class="text-blue-700 hover:underline" title="Baixar a versão atual">📄 {plano.documento.nome} (v{plano.documento.versao_atual})</button>
          {#if editavel}
            <button type="button" onclick={escolherArquivo} class="text-xs text-blue-700 hover:underline">Trocar</button>
            <button type="button" disabled={envio.ocupado} onclick={desligarArquivo} class="disabled:opacity-50 disabled:cursor-not-allowed text-xs text-red-700 hover:underline">Desligar</button>
          {/if}
        {:else}
          <span class="text-xs text-gray-500">Nenhum arquivo ligado.</span>
          {#if editavel}
            <button type="button" onclick={escolherArquivo} class="text-xs text-blue-700 hover:underline">Ligar arquivo de Documentos e planos</button>
          {/if}
        {/if}
      </div>
      <div class="flex flex-wrap items-center gap-2 pt-2 border-t border-gray-100">
        {#if plano.situacao === "rascunho"}
          <button type="button" disabled={envio.ocupado} onclick={() => situacao("vigente", "Plano em vigor.")} class="disabled:opacity-50 disabled:cursor-not-allowed px-3 py-1.5 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">Colocar em vigor</button>
        {/if}
        {#if plano.situacao === "vigente"}
          <button type="button" disabled={envio.ocupado} onclick={() => situacao("encerrado", "Plano encerrado.")} class="disabled:opacity-50 disabled:cursor-not-allowed px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700">Encerrar plano</button>
        {/if}
        {#if plano.situacao === "encerrado"}
          <button type="button" disabled={envio.ocupado} onclick={() => situacao("vigente", "Plano reaberto.")} class="disabled:opacity-50 disabled:cursor-not-allowed px-3 py-1.5 rounded-md bg-gray-200 text-gray-800 text-xs font-semibold hover:bg-gray-300">Reabrir plano</button>
          <span class="text-xs text-gray-500">Plano encerrado: só leitura.</span>
        {/if}
        {#if editavel}
          <label class="flex items-center gap-2 text-xs text-gray-600 ml-auto">
            <input type="checkbox" checked={plano.alertas_ativos} disabled={envio.ocupado} onchange={alternarAlertas} class="accent-blue-600" />
            Receber alertas de prazo por e-mail
          </label>
        {/if}
        <button type="button" disabled={envio.ocupado} onclick={arquivar} class="disabled:opacity-50 disabled:cursor-not-allowed px-3 py-1.5 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100">Arquivar</button>
      </div>
    </section>

    <!-- prazos -->
    {#if atrasadas.length || vencendo.length}
      <section class="rounded-card border border-amber-200 bg-amber-50 p-4 space-y-2" data-tour="plano-prazos">
        {#if atrasadas.length}
          <h2 class="text-sm font-semibold text-red-800">Atrasadas</h2>
          <ul class="space-y-1 text-sm">{#each atrasadas as a (a.id)}<li>{@render linhaAcao(a)}</li>{/each}</ul>
        {/if}
        {#if vencendo.length}
          <h2 class="text-sm font-semibold text-amber-900">Vencem nos próximos 7 dias</h2>
          <ul class="space-y-1 text-sm">{#each vencendo as a (a.id)}<li>{@render linhaAcao(a)}</li>{/each}</ul>
        {/if}
      </section>
    {/if}

    <!-- objetivos -->
    <section class="space-y-4" data-tour="plano-objetivos">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-gray-900">Objetivos</h2>
        {#if editavel}
          <button type="button" onclick={() => (objetivoForm = { titulo: "" })} class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700">+ Objetivo</button>
        {/if}
      </div>

      {#if objetivoForm}
        <div class="rounded-card border border-blue-200 bg-blue-50 p-3 flex flex-wrap items-end gap-2">
          <label class="text-xs text-gray-600 flex-1 min-w-[16rem]"><span class="block">Objetivo *</span>
            <input bind:value={objetivoForm.titulo} maxlength={L.OBJETIVO_MAX} placeholder="Ex.: Melhorar a aprendizagem em leitura" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
          <button type="button" onclick={() => (objetivoForm = null)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Cancelar</button>
          <button type="button" disabled={envio.ocupado} onclick={salvarObjetivo} class="disabled:opacity-50 disabled:cursor-not-allowed px-4 py-1.5 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">{envio.ocupado ? "Salvando…" : "Salvar objetivo"}</button>
        </div>
      {/if}

      {#each plano.objetivos as o (o.id)}
        <article class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-4">
          {#if objetivoEdit?.id === o.id}
            <div class="flex flex-wrap items-end gap-2">
              <label class="text-xs text-gray-600 flex-1 min-w-[16rem]"><span class="block">Objetivo *</span>
                <input bind:value={objetivoEdit.titulo} maxlength={L.OBJETIVO_MAX} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
              <button type="button" onclick={() => (objetivoEdit = null)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Cancelar</button>
              <button type="button" disabled={envio.ocupado} onclick={salvarObjetivoEdit} class="disabled:opacity-50 disabled:cursor-not-allowed px-4 py-1.5 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">{envio.ocupado ? "Salvando…" : "Salvar alterações"}</button>
            </div>
          {:else}
          <div class="flex items-start justify-between gap-2">
            <h3 class="text-base font-semibold text-gray-900">{o.titulo}</h3>
            {#if editavel}
              <div class="flex gap-1 shrink-0">
              <button type="button" onclick={() => (objetivoEdit = { id: o.id, titulo: o.titulo })} aria-label={`Editar objetivo ${o.titulo}`} class="px-2.5 py-1 rounded-md bg-gray-100 text-gray-700 text-xs font-medium hover:bg-gray-200">✎</button>
              <button type="button" disabled={envio.ocupado} onclick={() => excluirObjetivo(o)} aria-label={`Excluir objetivo ${o.titulo}`} class="disabled:opacity-50 disabled:cursor-not-allowed px-2.5 py-1 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100">✕</button>
              </div>
            {/if}
          </div>
          {/if}
          {@render progresso(o.progresso, `Andamento de ${o.titulo}`)}

          <!-- metas -->
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <h4 class="text-xs font-semibold uppercase text-gray-500">Metas</h4>
              {#if editavel}
                <button type="button" onclick={() => novaMeta(o)} class="text-xs text-blue-700 hover:underline">+ Meta</button>
              {/if}
            </div>

            {#if metaForm && !metaForm.id && metaForm.objetivo_id === o.id}{@render formMeta(o)}{/if}

            <ul class="divide-y divide-gray-100 rounded-md border border-gray-100">
              {#each o.metas as m (m.id)}
                <li class="p-3 space-y-1">
                  {#if metaForm?.id === m.id}
                    {@render formMeta(o)}
                  {:else}
                  <div class="flex items-start justify-between gap-2">
                    <div class="min-w-0">
                      <p class="text-sm font-medium text-gray-800">{m.descricao}</p>
                      <p class="text-xs text-gray-500">
                        {m.indicador ? m.indicador.fonte : "Meta manual"}
                        · base {m.unidade === "%" ? fmtComUnidade(m.linha_base, "%") : fmtNum(m.linha_base)}{#if m.base_ajustada}{" "}<span class="text-amber-700 font-medium" title="A escola mudou a linha de base desta meta oficial. O ajuste aparece também no relatório.">(ajustada pela escola; oficial: {fmtNum(m.linha_base_oficial)})</span>{/if} → alvo {fmtComUnidade(m.alvo, m.unidade)}
                        {#if m.atual}{" · atual "}{m.unidade === "%" ? fmtComUnidade(m.atual.valor, "%") : fmtNum(m.atual.valor)} ({m.atual.ano_ref ?? fmtData(m.atual.data_ref)}){/if}
                      </p>
                    </div>
                    {#if editavel}
                      <div class="flex gap-1 shrink-0">
                        <button type="button" onclick={() => editarMeta(m)} aria-label={`Editar meta ${m.descricao}`} class="px-2 py-0.5 rounded-md bg-gray-100 text-gray-700 text-xs hover:bg-gray-200">✎</button>
                        <button type="button" disabled={envio.ocupado} onclick={() => excluirMeta(m)} aria-label={`Excluir meta ${m.descricao}`} class="disabled:opacity-50 disabled:cursor-not-allowed px-2 py-0.5 rounded-md bg-red-50 text-red-700 text-xs hover:bg-red-100">✕</button>
                      </div>
                    {/if}
                  </div>
                  {/if}
                  {#if m.progresso !== null && m.progresso !== undefined}
                    <div class="flex items-center gap-2" aria-label={`Progresso da meta ${m.descricao}: ${pct(m.progresso)}`}>
                      <div class="h-1.5 flex-1 max-w-xs rounded-full bg-gray-200 overflow-hidden"><div class="h-1.5 bg-blue-600" style={barra(m.progresso)}></div></div>
                      <span class="text-xs text-gray-700">{pct(m.progresso)}</span>
                    </div>
                  {:else}
                    <p class="text-xs text-amber-700">{META_ESTADO_LABEL[m.estado] ?? m.estado}</p>
                  {/if}
                  <MetaHistorico medicoes={m.medicoes} linhaBase={m.linha_base} alvo={m.alvo} rotulo={`Histórico de ${m.descricao}`} />
                  {#if !m.indicador}
                    {#if m.medicoes.length}
                      <ul class="text-[11px] text-gray-500 flex flex-wrap gap-x-3">
                        {#each m.medicoes as med (med.id)}
                          <li>{fmtData(med.data_ref)}: {fmtNum(med.valor)}{#if editavel} <button type="button" disabled={envio.ocupado} onclick={() => excluirMedicao(m, med)} aria-label={`Excluir medição de ${fmtData(med.data_ref)}`} class="disabled:opacity-50 disabled:cursor-not-allowed text-red-600 hover:underline">✕</button>{/if}</li>
                        {/each}
                      </ul>
                    {/if}
                    {#if editavel}
                      {#if medicaoForm && medicaoForm.meta_id === m.id}
                        <div class="flex flex-wrap items-end gap-2 pt-1">
                          <label class="text-xs text-gray-600"><span class="block">Data</span>
                            <input type="date" bind:value={medicaoForm.data_ref} class="mt-1 h-8 px-2 rounded-md border border-gray-300 text-sm" /></label>
                          <label class="text-xs text-gray-600"><span class="block">Valor</span>
                            <input bind:value={medicaoForm.valor} inputmode="decimal" class="mt-1 w-24 h-8 px-2 rounded-md border border-gray-300 text-sm" /></label>
                          <label class="text-xs text-gray-600 flex-1 min-w-[10rem]"><span class="block">Nota</span>
                            <input bind:value={medicaoForm.nota} maxlength="500" class="mt-1 w-full h-8 px-2 rounded-md border border-gray-300 text-sm" /></label>
                          <button type="button" onclick={() => (medicaoForm = null)} class="px-3 py-1 rounded-md bg-gray-200 text-gray-700 text-xs hover:bg-gray-300">Cancelar</button>
                          <button type="button" disabled={envio.ocupado} onclick={salvarMedicao} class="disabled:opacity-50 disabled:cursor-not-allowed px-3 py-1 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">{envio.ocupado ? "Salvando…" : "Registrar"}</button>
                        </div>
                      {:else}
                        <button type="button" onclick={() => novaMedicao(m)} class="text-xs text-blue-700 hover:underline">+ Registrar medição</button>
                      {/if}
                    {/if}
                  {/if}
                  {@render evidencias(m.evidencias ?? [], "meta", m.id, m.descricao)}
                </li>
              {:else}
                <li class="p-3 text-xs text-gray-400">Nenhuma meta neste objetivo.</li>
              {/each}
            </ul>
          </div>

          <!-- ações -->
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <h4 class="text-xs font-semibold uppercase text-gray-500">Ações</h4>
              {#if editavel}
                <button type="button" onclick={() => novaAcao(o)} class="text-xs text-blue-700 hover:underline">+ Ação</button>
              {/if}
            </div>

            {#if acaoForm && !acaoForm.id && acaoForm.objetivo_id === o.id}{@render formAcao(o)}{/if}

            <ul class="divide-y divide-gray-100 rounded-md border border-gray-100">
              {#each o.acoes as a (a.id)}
                <li class="p-3 flex flex-wrap items-center gap-2">
                  {#if acaoForm?.id === a.id}
                  <div class="w-full">{@render formAcao(o)}</div>
                  {:else}
                  <div class="min-w-0 flex-1">
                    <p class={`text-sm ${a.situacao === "concluida" || a.situacao === "cancelada" ? "line-through text-gray-400" : "text-gray-800"}`}>
                      {a.descricao}
                      {#if a.atrasada}<span class="ml-1 text-[10px] uppercase text-red-600 font-semibold">atrasada</span>{/if}
                    </p>
                    <p class="text-xs text-gray-500">
                      prazo {fmtData(a.prazo)}{#if a.responsavel}{" · "}{a.responsavel}{/if}
                      {#if a.custo_previsto !== null}{" · R$ "}{fmtNum(a.custo_previsto)}{/if}
                      {#if a.fonte_recurso}{" ("}{FONTE_RECURSO_LABEL[a.fonte_recurso]}){/if}
                      {#if a.custo_executado !== null && a.custo_executado !== undefined}{" · executado R$ "}{fmtNum(a.custo_executado)}{#if a.executado_em}{" em "}{fmtData(a.executado_em)}{/if}{/if}
                      {#if a.meta_id}{" · meta: "}{metaDescricao(o.id, a.meta_id)}{/if}
                    </p>
                  </div>
                  {#if editavel}
                    <select value={a.situacao} disabled={envio.ocupado} onchange={(e) => mudarSituacaoAcao(a, e.target.value)} aria-label={`Situação de ${a.descricao}`} class="h-8 px-2 rounded-md border border-gray-300 text-xs bg-white">
                      {#each ACAO_SITUACOES as s (s.valor)}<option value={s.valor}>{s.rotulo}</option>{/each}
                    </select>
                    <button type="button" onclick={() => editarAcao(a)} aria-label={`Editar ação ${a.descricao}`} class="px-2 py-0.5 rounded-md bg-gray-100 text-gray-700 text-xs hover:bg-gray-200">✎</button>
                    <button type="button" disabled={envio.ocupado} onclick={() => excluirAcao(a)} aria-label={`Excluir ação ${a.descricao}`} class="disabled:opacity-50 disabled:cursor-not-allowed px-2 py-0.5 rounded-md bg-red-50 text-red-700 text-xs hover:bg-red-100">✕</button>
                  {:else}
                    <span class="text-xs text-gray-600">{ACAO_SITUACAO_LABEL[a.situacao]}</span>
                  {/if}
                  {/if}
                  <div class="w-full">{@render evidencias(a.evidencias ?? [], "acao", a.id, a.descricao)}</div>
                </li>
              {:else}
                <li class="p-3 text-xs text-gray-400">Nenhuma ação neste objetivo.</li>
              {/each}
            </ul>
          </div>
        </article>
      {:else}
        <p class="rounded-card bg-white border border-gray-200 p-8 text-center text-sm text-gray-500">
          Nenhum objetivo ainda. Comece pelos dois ou três grandes objetivos do plano.
        </p>
      {/each}
    </section>
  {/if}
</div>
