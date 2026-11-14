<!-- src/features/config/pages/RedeContasPage.svelte -->
<script>
  // Contas de rede (#394, rota admin /config/rede). Mesma proteção do /config:
  // sessão com access_role = 'admin'. O admin cria a conta da secretaria, copia
  // o link de convite (uso único, 7 dias — o token só aparece agora) e liga a
  // conta às redes (dependência municipal/estadual + município). Revogar corta
  // o acesso na hora. A auditoria de cada conta abre sob demanda.
  import { onMount } from "svelte";
  import {
    listRedeContas,
    criarRedeConta,
    gerarRedeConvite,
    concederRedeVinculo,
    revogarRedeVinculo,
    getRedeAuditoria,
    linkConviteRede,
  } from "../api/configApi.js";
  import { fetchMe } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { criarEnvio } from "@/shared/utils/envio.svelte.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);
  let contas = $state([]);

  let nova = $state({ nome: "", email: "", cargo: "" });
  let criando = $state(false);
  // { contaId, nome, link, expira_em } do último convite gerado (só nesta tela)
  let convite = $state(null);
  // vínculo em edição por conta: { [contaId]: { tp_dependencia, co_municipio } }
  let vinculoForm = $state({});
  let auditoria = $state({});

  const ACOES = {
    conta_criada: "Conta criada",
    convite_gerado: "Convite gerado",
    convite_aceito: "Convite aceito (senha definida)",
    vinculo_concedido: "Rede concedida",
    vinculo_revogado: "Rede revogada",
  };
  const fmtQuando = (iso) => (iso ? new Date(iso).toLocaleString("pt-BR") : "—");
  const msg = (err, padrao) => (err instanceof ApiError ? err.message : padrao);

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    semPermissao = false;
    try {
      const me = await fetchMe();
      if (me.access_role !== "admin") {
        semPermissao = true;
        return;
      }
      contas = (await listRedeContas()).contas ?? [];
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else if (err instanceof ApiError && err.status === 403) semPermissao = true;
      else error = "Não foi possível carregar as contas de rede.";
    } finally {
      carregando = false;
    }
  }

  async function recarregar() {
    contas = (await listRedeContas()).contas ?? [];
  }

  async function criar() {
    if (!nova.nome.trim() || !/^\S+@\S+\.\S+$/.test(nova.email.trim())) {
      addToast("Informe o nome e um e-mail válido.", "warning");
      return;
    }
    criando = true;
    try {
      const r = await criarRedeConta({ nome: nova.nome.trim(), email: nova.email.trim(), cargo: nova.cargo.trim() || null });
      convite = { contaId: r.conta.id, nome: r.conta.nome, link: linkConviteRede(r.convite.token), expira_em: r.convite.expira_em };
      nova = { nome: "", email: "", cargo: "" };
      addToast("Conta de rede criada.", "success");
      await recarregar();
    } catch (err) {
      addToast(msg(err, "Não foi possível criar a conta."), "error");
    } finally {
      criando = false;
    }
  }

  // Um envio por vez: o botão fica desabilitado até a resposta (sem réplica).
  const envio = criarEnvio();

  const novoConvite = envio.travar(async (c) => {
    if (c.convite_pendente && !window.confirm(`Gerar um convite novo para ${c.nome}? O link anterior deixa de valer.`)) return;
    try {
      const r = await gerarRedeConvite(c.id);
      convite = { contaId: c.id, nome: c.nome, link: linkConviteRede(r.token), expira_em: r.expira_em };
      await recarregar();
    } catch (err) {
      addToast(msg(err, "Não foi possível gerar o convite."), "error");
    }
  });

  async function copiar() {
    try {
      await navigator.clipboard.writeText(convite.link);
      addToast("Link copiado.", "success");
    } catch {
      addToast("Copie o link pelo campo.", "warning");
    }
  }

  function abrirVinculo(c) {
    vinculoForm = { ...vinculoForm, [c.id]: { tp_dependencia: "3", co_municipio: "" } };
  }

  const conceder = envio.travar(async (c) => {
    const f = vinculoForm[c.id];
    if (!/^\d{7}$/.test(f.co_municipio.trim())) {
      addToast("Informe o código IBGE do município (7 dígitos).", "warning");
      return;
    }
    try {
      await concederRedeVinculo(c.id, { tp_dependencia: Number(f.tp_dependencia), co_municipio: Number(f.co_municipio.trim()) });
      const { [c.id]: _, ...resto } = vinculoForm;
      vinculoForm = resto;
      addToast("Rede concedida.", "success");
      await recarregar();
    } catch (err) {
      addToast(msg(err, "Não foi possível conceder a rede."), "error");
    }
  });

  const revogar = envio.travar(async (c, v) => {
    if (!window.confirm(`Revogar a rede ${v.dependencia.toLowerCase()} de ${v.municipio}/${v.uf} de ${c.nome}? O acesso acaba na hora.`)) return;
    try {
      await revogarRedeVinculo(c.id, v.id);
      addToast("Rede revogada.", "success");
      await recarregar();
    } catch (err) {
      addToast(msg(err, "Não foi possível revogar."), "error");
    }
  });

  async function alternarAuditoria(c) {
    if (auditoria[c.id]) {
      const { [c.id]: _, ...resto } = auditoria;
      auditoria = resto;
      return;
    }
    try {
      auditoria = { ...auditoria, [c.id]: (await getRedeAuditoria(c.id)).auditoria ?? [] };
    } catch (err) {
      addToast(msg(err, "Não foi possível carregar a auditoria."), "error");
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
</script>

<div class="space-y-6 max-w-4xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Contas de rede</h1>
      <p class="text-sm text-gray-600 mt-1">
        Contas das secretarias: cada uma vê as escolas das redes ligadas a ela, só para leitura.
      </p>
    </div>
    <a href="/config" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">← Configurações</a>
  </header>

  {#if carregando}
    <p class="text-gray-500">Carregando…</p>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre como administrador." />
  {:else if semPermissao}
    <div class="rounded-md bg-amber-50 border border-amber-200 text-amber-900 text-sm p-4">Acesso restrito a administradores da instalação.</div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else}
    {#if convite}
      <section class="rounded-card border border-green-300 bg-green-50 p-4 space-y-2" aria-label="Convite gerado">
        <p class="text-sm text-green-900">
          Convite de <strong>{convite.nome}</strong>. Copie o link e envie à pessoa: ele vale uma vez, até {fmtQuando(convite.expira_em)},
          e não aparece de novo.
        </p>
        <div class="flex flex-wrap gap-2">
          <input readonly value={convite.link} aria-label="Link do convite" class="flex-1 min-w-[16rem] h-9 px-2 rounded-md border border-gray-300 text-xs bg-white" />
          <button type="button" onclick={copiar} class="px-3 py-1.5 rounded-md bg-green-700 text-white text-xs font-semibold hover:bg-green-800">Copiar link</button>
          <button type="button" onclick={() => (convite = null)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs hover:bg-gray-300">Fechar</button>
        </div>
      </section>
    {/if}

    <section class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-3" aria-label="Nova conta de rede">
      <h2 class="text-sm font-semibold text-gray-900">Nova conta de rede</h2>
      <div class="grid gap-2 sm:grid-cols-3">
        <label class="text-xs text-gray-600"><span class="block">Nome *</span>
          <input bind:value={nova.nome} maxlength="120" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
        <label class="text-xs text-gray-600"><span class="block">E-mail *</span>
          <input type="email" bind:value={nova.email} maxlength="254" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
        <label class="text-xs text-gray-600"><span class="block">Cargo</span>
          <input bind:value={nova.cargo} maxlength="80" placeholder="Ex.: Técnica pedagógica" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      </div>
      <div class="flex justify-end">
        <button type="button" onclick={criar} disabled={criando} class="px-4 py-1.5 rounded-md bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 disabled:opacity-50">
          {criando ? "Criando…" : "Criar conta e gerar convite"}
        </button>
      </div>
    </section>

    <ul class="space-y-3" aria-label="Contas de rede">
      {#each contas as c (c.id)}
        <li class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-2">
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div>
              <p class="text-base font-semibold text-gray-900">{c.nome}</p>
              <p class="text-xs text-gray-500">{c.cargo ?? "sem cargo"} · {c.email}</p>
              <p class="text-xs mt-0.5 {c.senha_definida ? 'text-green-700' : 'text-amber-800'}">
                {#if c.senha_definida}Senha definida{:else if c.convite_pendente}Convite pendente, vale até {fmtQuando(c.convite_pendente.expira_em)}{:else}Sem senha e sem convite válido{/if}
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <button disabled={envio.ocupado} type="button" onclick={() => novoConvite(c)} class="disabled:opacity-50 disabled:cursor-not-allowed px-3 py-1 rounded-md bg-gray-100 text-gray-800 text-xs hover:bg-gray-200">Novo convite</button>
              <button type="button" onclick={() => alternarAuditoria(c)} class="px-3 py-1 rounded-md bg-gray-100 text-gray-800 text-xs hover:bg-gray-200">{auditoria[c.id] ? "Ocultar histórico" : "Histórico"}</button>
            </div>
          </div>

          <div class="space-y-1">
            <h3 class="text-xs font-semibold uppercase text-gray-500">Redes</h3>
            {#if c.vinculos.length}
              <ul class="space-y-1 text-sm">
                {#each c.vinculos as v (v.id)}
                  <li class="flex items-center gap-2">
                    <span>Rede {v.dependencia.toLowerCase()} · {v.municipio}/{v.uf} <span class="text-xs text-gray-500">({v.co_municipio})</span></span>
                    <button disabled={envio.ocupado} type="button" onclick={() => revogar(c, v)} aria-label={`Revogar rede ${v.dependencia} de ${v.municipio}`} class="disabled:opacity-50 disabled:cursor-not-allowed text-xs text-red-700 hover:underline">Revogar</button>
                  </li>
                {/each}
              </ul>
            {:else}
              <p class="text-xs text-gray-500">Nenhuma rede ligada: a conta não vê escola nenhuma.</p>
            {/if}
            {#if vinculoForm[c.id]}
              <div class="flex flex-wrap items-end gap-2 pt-1">
                <label class="text-xs text-gray-600"><span class="block">Dependência</span>
                  <select bind:value={vinculoForm[c.id].tp_dependencia} class="mt-1 h-8 px-2 rounded-md border border-gray-300 text-xs bg-white">
                    <option value="3">Municipal</option>
                    <option value="2">Estadual</option>
                  </select></label>
                <label class="text-xs text-gray-600"><span class="block">Município (código IBGE)</span>
                  <input bind:value={vinculoForm[c.id].co_municipio} inputmode="numeric" maxlength="7" placeholder="Ex.: 3550308" class="mt-1 w-32 h-8 px-2 rounded-md border border-gray-300 text-xs" /></label>
                <button disabled={envio.ocupado} type="button" onclick={() => conceder(c)} class="disabled:opacity-50 disabled:cursor-not-allowed px-3 py-1 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">Conceder</button>
                <button type="button" onclick={() => { const { [c.id]: _, ...r } = vinculoForm; vinculoForm = r; }} class="px-3 py-1 rounded-md bg-gray-200 text-gray-700 text-xs hover:bg-gray-300">Cancelar</button>
              </div>
            {:else}
              <button type="button" onclick={() => abrirVinculo(c)} class="text-xs text-blue-700 hover:underline">+ Conceder rede</button>
            {/if}
          </div>

          {#if auditoria[c.id]}
            <ol class="text-xs text-gray-600 space-y-0.5 border-t border-gray-100 pt-2" aria-label={`Histórico de ${c.nome}`}>
              {#each auditoria[c.id] as a (a.id)}
                <li>{fmtQuando(a.criado_em)} · {ACOES[a.acao] ?? a.acao}{#if a.ator}{" · por "}{a.ator}{/if}</li>
              {/each}
            </ol>
          {/if}
        </li>
      {:else}
        <li class="rounded-card bg-white border border-gray-200 p-6 text-center text-sm text-gray-500">Nenhuma conta de rede ainda.</li>
      {/each}
    </ul>
  {/if}
</div>
