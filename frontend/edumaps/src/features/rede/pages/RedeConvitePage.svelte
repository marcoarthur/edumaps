<!-- src/features/rede/pages/RedeConvitePage.svelte -->
<script>
  // Convite da conta de rede (#394): página pública (sem menu), aberta pelo
  // link que o administrador enviou. Mostra de quem é o convite e deixa a
  // pessoa definir a própria senha. Uso único: depois disso, entra pelo login.
  import { onMount } from "svelte";
  import { getConviteRede, aceitarConviteRede } from "../api/redeApi.js";
  import { ApiError } from "@/shared/api/client.js";

  // O App passa o token da rota (páginas públicas sem menu); sem ele, lê da URL.
  let { token: tokenRota = null } = $props();
  const token = tokenRota ?? new URL(location.href).pathname.match(/\/rede\/convite\/([A-Za-z0-9_-]{43})/)?.[1] ?? null;

  let carregando = $state(true);
  let convite = $state(null);
  let erro = $state(null);
  let senha = $state("");
  let confirmacao = $state("");
  let salvando = $state(false);
  let pronto = $state(false);

  const MOTIVO = {
    usado: "Este convite já foi usado. Entre com o seu e-mail e a senha que você definiu.",
    vencido: "Este convite venceu. Peça um novo ao administrador da plataforma.",
    substituido: "Este convite foi substituído por um mais novo. Use o link mais recente que você recebeu.",
  };

  onMount(async () => {
    if (!token) {
      erro = "Link de convite inválido.";
      carregando = false;
      return;
    }
    try {
      convite = await getConviteRede(token);
    } catch (err) {
      erro = err instanceof ApiError && err.status === 404 ? "Convite não encontrado." : "Não foi possível abrir o convite.";
    } finally {
      carregando = false;
    }
  });

  async function definir() {
    erro = null;
    if (senha.length < 6) {
      erro = "A senha deve ter ao menos 6 caracteres.";
      return;
    }
    if (senha !== confirmacao) {
      erro = "As duas senhas não são iguais.";
      return;
    }
    salvando = true;
    try {
      await aceitarConviteRede(token, senha);
      senha = "";
      confirmacao = "";
      pronto = true;
    } catch (err) {
      erro = err instanceof ApiError ? err.message : "Não foi possível definir a senha.";
    } finally {
      salvando = false;
    }
  }
</script>

<div class="min-h-[70vh] flex items-start justify-center px-4 py-10 bg-gray-50">
  <div class="w-full max-w-md rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-4">
    <header>
      <p class="text-xs uppercase tracking-wide text-gray-500">EduMaps · conta de rede</p>
      <h1 class="text-xl font-bold text-gray-900">Defina a sua senha</h1>
    </header>

    {#if carregando}
      <p class="text-sm text-gray-500">Abrindo o convite…</p>
    {:else if pronto}
      <p class="text-sm text-green-800" role="status">Senha definida. Agora entre com o seu e-mail e a senha nova.</p>
      <a href="/gestor" class="inline-block px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700">Entrar</a>
    {:else if !convite}
      <p class="text-sm text-red-700" role="alert">{erro}</p>
    {:else if convite.situacao !== "valido"}
      <p class="text-sm text-amber-800" role="alert">{MOTIVO[convite.situacao] ?? "Este convite não vale mais."}</p>
      {#if convite.situacao === "usado"}
        <a href="/gestor" class="inline-block px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700">Entrar</a>
      {/if}
    {:else}
      <p class="text-sm text-gray-700">
        Convite para <strong>{convite.nome}</strong> ({convite.email}). Com esta conta você acompanha as escolas
        da rede que o administrador ligou a ela.
      </p>
      <label class="block text-xs text-gray-600"><span class="block">Senha nova</span>
        <input type="password" bind:value={senha} autocomplete="new-password" maxlength="64" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      <label class="block text-xs text-gray-600"><span class="block">Repita a senha</span>
        <input type="password" bind:value={confirmacao} autocomplete="new-password" maxlength="64" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
      {#if erro}<p class="text-sm text-red-700" role="alert">{erro}</p>{/if}
      <button type="button" onclick={definir} disabled={salvando} class="w-full px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50">
        {salvando ? "Salvando…" : "Definir senha"}
      </button>
      <p class="text-xs text-gray-500">O link vale uma vez. Ninguém além de você conhece esta senha.</p>
    {/if}
  </div>
</div>
