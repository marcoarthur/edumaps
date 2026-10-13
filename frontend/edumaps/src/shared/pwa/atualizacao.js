// src/shared/pwa/atualizacao.js
//
// Atualização da SPA e do service worker (issue #225).
//
// Decisão do developer (2026-10-13):
//   - Novo SW em espera → aviso discreto "Nova versão disponível — Atualizar".
//     A página só recarrega quando a pessoa clica (não perde formulário).
//   - Chunk antigo que falha ao carregar (aba aberta antes do deploy) →
//     recarga automática ÚNICA, protegida por marcador em sessionStorage.
//
// Toda dependência de navegador (serviceWorker, window, document, storage,
// reload) é injetável, para os testes rodarem sem navegador real.

export const CHAVE_RELOAD = "edumaps:reload-chunk";
export const VALIDADE_MARCADOR_MS = 60_000;
export const INTERVALO_VERIFICACAO_MS = 30 * 60_000;

// ---------------------------------------------------------------------------
// Reload único em erro de chunk
// ---------------------------------------------------------------------------

/**
 * Decide se a página deve recarregar por erro de chunk. Se sim, grava o
 * marcador (timestamp) antes. Um marcador ainda válido significa que já
 * recarregamos há pouco: não recarrega de novo (evita laço).
 * sessionStorage indisponível (privado, bloqueado) → não recarrega: sem
 * marcador não há proteção contra laço.
 */
export function decidirReloadUnico({
  storage,
  agora = Date.now(),
  validadeMs = VALIDADE_MARCADOR_MS,
} = {}) {
  try {
    if (!storage) return false;
    const anterior = Number(storage.getItem(CHAVE_RELOAD));
    if (anterior && agora - anterior >= 0 && agora - anterior < validadeMs) {
      return false;
    }
    storage.setItem(CHAVE_RELOAD, String(agora));
    // Confirma que a gravação pegou; senão não há proteção contra laço.
    return storage.getItem(CHAVE_RELOAD) === String(agora);
  } catch {
    return false;
  }
}

const PADROES_ERRO_CHUNK = [
  /Failed to fetch dynamically imported module/i, // Chromium
  /error loading dynamically imported module/i, // Firefox
  /Importing a module script failed/i, // Safari
  /Unable to preload CSS/i, // Vite (CSS do chunk)
];

/** O erro (ou motivo de rejeição) é de chunk/import dinâmico que não carregou? */
export function ehErroDeChunk(erro) {
  const msg =
    typeof erro === "string" ? erro : erro && typeof erro.message === "string" ? erro.message : "";
  return PADROES_ERRO_CHUNK.some((re) => re.test(msg));
}

function storageSeguro(win) {
  try {
    return win.sessionStorage;
  } catch {
    return null;
  }
}

/**
 * Liga os listeners de erro de chunk: `vite:preloadError` (preload do Vite)
 * e `unhandledrejection` com mensagem de import dinâmico falho.
 * Retorna a função que desliga os listeners.
 */
export function instalarRecargaDeChunk({
  win = window,
  storage = storageSeguro(win),
  recarregar = () => win.location.reload(),
  aoFalhar = () => {},
  agora = () => Date.now(),
} = {}) {
  function tratar(evento) {
    if (decidirReloadUnico({ storage, agora: agora() })) {
      // Evita que o Vite relance o erro: a página vai recarregar.
      evento?.preventDefault?.();
      recarregar();
    } else {
      aoFalhar();
    }
  }
  const onPreload = (e) => tratar(e);
  const onRejeicao = (e) => {
    if (ehErroDeChunk(e?.reason)) tratar(e);
  };
  win.addEventListener("vite:preloadError", onPreload);
  win.addEventListener("unhandledrejection", onRejeicao);
  return () => {
    win.removeEventListener("vite:preloadError", onPreload);
    win.removeEventListener("unhandledrejection", onRejeicao);
  };
}

// ---------------------------------------------------------------------------
// Aviso de nova versão
// ---------------------------------------------------------------------------

/**
 * Cria o controlador do aviso. Expõe um store compatível com Svelte
 * (`subscribe`) cujo valor é `{ visivel, motivo }`, com motivo
 * `"nova-versao"` (SW novo em espera) ou `"erro-chunk"` (recarga automática
 * já usada e o chunk continua falhando).
 */
export function criarAtualizador({
  sw = typeof navigator !== "undefined" ? navigator.serviceWorker : undefined,
  win = typeof window !== "undefined" ? window : undefined,
  doc = typeof document !== "undefined" ? document : undefined,
  recarregar = () => win.location.reload(),
  intervaloMs = INTERVALO_VERIFICACAO_MS,
} = {}) {
  let estado = { visivel: false, motivo: null };
  const inscritos = new Set();
  let emEspera = null; // ServiceWorker "installed" aguardando SKIP_WAITING
  let registro = null;
  let recarregando = false;
  const limpezas = [];

  function definir(novo) {
    estado = { ...estado, ...novo };
    for (const fn of inscritos) fn(estado);
  }

  function subscribe(fn) {
    inscritos.add(fn);
    fn(estado);
    return () => inscritos.delete(fn);
  }

  /** Um SW novo está esperando: mostra o aviso (só se já houver controlador,
   *  isto é, não é a primeira instalação). */
  function onNeedRefresh(worker) {
    emEspera = worker;
    definir({ visivel: true, motivo: "nova-versao" });
  }

  function mostrarErroChunk() {
    definir({ visivel: true, motivo: "erro-chunk" });
  }

  function recarregarUmaVez() {
    if (recarregando) return;
    recarregando = true;
    recarregar();
  }

  /** "Atualizar": ativa o SW em espera e recarrega no `controllerchange`.
   *  Sem SW em espera (ex.: erro de chunk), só recarrega. */
  function atualizar() {
    definir({ visivel: false });
    if (emEspera && sw) {
      sw.addEventListener("controllerchange", recarregarUmaVez);
      emEspera.postMessage({ type: "SKIP_WAITING" });
      return;
    }
    recarregarUmaVez();
  }

  /** "Depois": esconde o aviso; o SW novo segue em espera (assume quando todas
   *  as abas fecharem, ou o aviso volta na próxima verificação). */
  function adiar() {
    definir({ visivel: false });
  }

  function observar(reg) {
    const temControlador = () => Boolean(sw?.controller);
    if (reg.waiting && temControlador()) onNeedRefresh(reg.waiting);
    reg.addEventListener("updatefound", () => {
      const novo = reg.installing;
      if (!novo) return;
      novo.addEventListener("statechange", () => {
        if (novo.state === "installed" && temControlador()) onNeedRefresh(novo);
      });
    });
  }

  function verificar() {
    if (!registro) return Promise.resolve();
    return Promise.resolve(registro.update?.())
      .then(() => {
        if (registro.waiting && sw?.controller) onNeedRefresh(registro.waiting);
      })
      .catch(() => {});
  }

  /** Registra o SW e liga as verificações periódicas (intervalo + volta à aba). */
  async function registrar(url = "/sw.js") {
    if (!sw) return null;
    registro = await sw.register(url, { scope: "/" });
    observar(registro);

    const id = setInterval(verificar, intervaloMs);
    limpezas.push(() => clearInterval(id));
    if (doc) {
      const onVis = () => {
        if (doc.visibilityState === "visible") verificar();
      };
      doc.addEventListener("visibilitychange", onVis);
      limpezas.push(() => doc.removeEventListener("visibilitychange", onVis));
    }
    return registro;
  }

  function destruir() {
    while (limpezas.length) limpezas.pop()();
    sw?.removeEventListener?.("controllerchange", recarregarUmaVez);
  }

  return {
    subscribe,
    onNeedRefresh,
    mostrarErroChunk,
    atualizar,
    adiar,
    registrar,
    verificar,
    destruir,
  };
}

// Instância única da aplicação (usada por main.js e pelo componente de aviso).
export const atualizador = criarAtualizador();
