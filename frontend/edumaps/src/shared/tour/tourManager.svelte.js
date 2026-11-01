// src/shared/tour/tourManager.svelte.js
//
// Ajuda guiada (product tour): camada fina em runes sobre o driver.js.
//
// O driver.js cuida do destaque (recorte no overlay), do popover, do teclado
// (setas, Esc, Tab preso entre popover e elemento) e do `role="dialog"`. Esta
// camada acrescenta o que é do EduMaps:
//
//   - tours que atravessam páginas: cada passo tem uma `rota`; ao avançar ou
//     voltar para um passo de outra página, navegamos pelo roteador do app e o
//     driver espera o alvo aparecer (`waitForElement`);
//   - persistência: "já viu este tour" fica no localStorage (por versão do
//     tour); o passo em andamento fica no sessionStorage, para retomar após
//     recarregar a página;
//   - disparo: botão de ajuda, primeira visita à página (uma vez só) e o
//     parâmetro `?tour=<id>` na URL;
//   - acessibilidade complementar: `aria-modal` e devolução do foco ao
//     elemento que estava focado antes do tour.
//
// Os alvos são atributos `data-tour="<nome>"` nos componentes, nunca classes
// CSS — refatoração visual não pode quebrar a ajuda.
//
// Dependências injetáveis (driver, roteador, armazenamento) para os testes.

const PREFIXO = "edumaps.tour";
const CHAVE_SESSAO = `${PREFIXO}.em-andamento`;

/** Lê/grava armazenamento sem nunca lançar (aba privada, site data bloqueado). */
function ler(obterStorage, chave) {
  try {
    return obterStorage()?.getItem(chave) ?? null;
  } catch {
    return null;
  }
}
function gravar(obterStorage, chave, valor) {
  try {
    obterStorage()?.setItem(chave, valor);
  } catch {
    /* sem persistência: o tour continua funcionando */
  }
}
function remover(obterStorage, chave) {
  try {
    obterStorage()?.removeItem(chave);
  } catch {
    /* idem */
  }
}

function prefereMenosMovimento() {
  try {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  } catch {
    return false;
  }
}

export function seletorDoAlvo(alvo) {
  return `[data-tour="${alvo}"]`;
}

/** Chave do "já viu" — muda com a versão, para reapresentar tours revistos. */
export function chaveVisto(tour) {
  return `${PREFIXO}.${tour.id}.v${tour.versao ?? 1}`;
}

/**
 * Normaliza a definição: todo passo fica com `rota` explícita (herda a do
 * passo anterior; o primeiro herda `rotaInicial`).
 */
function normalizar(tour) {
  let rota = tour.rotaInicial;
  const passos = tour.passos.map((passo) => {
    rota = passo.rota ?? rota;
    return { ...passo, rota };
  });
  return { versao: 1, automatico: false, ...tour, passos };
}

export const TEXTOS = {
  proximo: "Próximo →",
  anterior: "← Anterior",
  concluir: "Concluir",
  fechar: "Fechar ajuda guiada",
  progresso: "{{current}} de {{total}}",
};

export class TourManager {
  /** id do tour em exibição, ou null. */
  ativo = $state(null);
  /** índice do passo em exibição. */
  passo = $state(0);

  #tours = new Map();
  #tour = null;
  #driver = null;
  #concluido = false;
  #focoAnterior = null;

  #router;
  #criarDriver;
  #local;
  #sessao;
  #esperaMs;

  /**
   * @param {object} deps
   * @param {{ path: string, navigate: (to: string) => void }} deps.router
   * @param {(config: object) => object} deps.criarDriver - `driver` do driver.js
   * @param {() => Storage | null} [deps.local]
   * @param {() => Storage | null} [deps.sessao]
   * @param {number} [deps.esperaMs] - quanto esperar o alvo aparecer
   */
  constructor({ router, criarDriver, local = () => null, sessao = () => null, esperaMs = 4000 }) {
    this.#router = router;
    this.#criarDriver = criarDriver;
    this.#local = local;
    this.#sessao = sessao;
    this.#esperaMs = esperaMs;
  }

  registrar(...tours) {
    for (const tour of tours) this.#tours.set(tour.id, normalizar(tour));
    return this;
  }

  obter(id) {
    return this.#tours.get(id) ?? null;
  }

  /** Tour cuja página inicial é `path` (é o que o botão de ajuda oferece). */
  tourDaRota(path) {
    for (const tour of this.#tours.values()) {
      if (tour.rotaInicial === path) return tour;
    }
    return null;
  }

  jaVisto(tour) {
    return ler(this.#local, chaveVisto(tour)) !== null;
  }

  /** Situação registrada do tour: null | "visto" | "concluido". */
  situacao(tour) {
    return ler(this.#local, chaveVisto(tour));
  }

  /**
   * Chamado a cada mudança de rota (e na carga). Decide, nesta ordem:
   * encerrar um tour que perdeu a página, `?tour=<id>`, retomar o passo
   * salvo na sessão, ou abrir o tour automático da primeira visita.
   *
   * @returns {boolean} se algum tour foi iniciado
   */
  aoNavegar(path, search = "") {
    if (this.ativo) {
      // Voltar do navegador (popstate) ou link fora do tour: o alvo do passo
      // sumiu da tela, então o tour não tem mais o que mostrar.
      const rotaDoPasso = this.#tour?.passos[this.passo]?.rota;
      if (rotaDoPasso && rotaDoPasso !== path) this.encerrar();
      return false;
    }

    const pedido = new URLSearchParams(search).get("tour");
    if (pedido && this.#tours.has(pedido)) {
      this.iniciar(pedido);
      return true;
    }

    const salvo = this.#lerSessao();
    if (salvo) {
      const tour = this.#tours.get(salvo.id);
      if (tour && tour.passos[salvo.passo]?.rota === path) {
        this.iniciar(salvo.id, { passo: salvo.passo });
        return true;
      }
      remover(this.#sessao, CHAVE_SESSAO);
    }

    const tour = this.tourDaRota(path);
    if (tour?.automatico && !this.jaVisto(tour)) {
      this.iniciar(tour.id);
      return true;
    }
    return false;
  }

  iniciar(id, { passo = 0 } = {}) {
    const tour = this.#tours.get(id);
    if (!tour) return false;
    if (this.ativo) this.encerrar();

    this.#tour = tour;
    this.#concluido = false;
    this.#focoAnterior = typeof document !== "undefined" ? document.activeElement : null;

    // Marca já na abertura: o tour automático aparece uma vez só, mesmo que
    // a pessoa feche no primeiro passo. Não rebaixa um "concluido".
    if (this.situacao(tour) !== "concluido") gravar(this.#local, chaveVisto(tour), "visto");

    this.#driver = this.#criarDriver(this.#configuracao(tour));
    this.ativo = tour.id;
    this.#irPara(passo);
    return true;
  }

  encerrar() {
    this.#driver?.destroy();
  }

  // --- interno -------------------------------------------------------------

  #configuracao(tour) {
    return {
      steps: tour.passos.map((p) => ({
        // Sem alvo: popover centralizado (boas-vindas, encerramento).
        element: p.alvo ? seletorDoAlvo(p.alvo) : undefined,
        popover: {
          title: p.titulo,
          description: p.texto,
          side: p.lado,
          align: p.alinhamento,
        },
      })),
      animate: !prefereMenosMovimento(),
      showProgress: true,
      progressText: TEXTOS.progresso,
      nextBtnText: TEXTOS.proximo,
      prevBtnText: TEXTOS.anterior,
      doneBtnText: TEXTOS.concluir,
      closeBtnLabel: TEXTOS.fechar,
      popoverClass: "edumaps-tour",
      stagePadding: 6,
      stageRadius: 8,
      // Alvo ausente (outra página ainda montando, lista vazia): espera; se
      // não aparecer, o driver mostra o popover centralizado em vez de travar.
      waitForElement: this.#esperaMs,
      // O tour explica; não deixa clicar no destaque (um clique em "Comparar
      // Redes" sairia da página com o tour aberto). Esc e "×" fecham.
      disableActiveInteraction: true,
      overlayClickBehavior: "none",
      onNextClick: () => this.#mover(+1),
      onPrevClick: () => this.#mover(-1),
      onHighlighted: (_el, _step, { state }) => {
        this.passo = state.activeIndex ?? 0;
        gravar(this.#sessao, CHAVE_SESSAO, JSON.stringify({ id: tour.id, passo: this.passo }));
      },
      onPopoverRender: (popover) => {
        popover.wrapper.setAttribute("aria-modal", "true");
      },
      onDestroyed: () => this.#aoDestruir(),
    };
  }

  #mover(delta) {
    const destino = this.passo + delta;
    if (destino < 0) return;
    if (destino >= this.#tour.passos.length) {
      this.#concluido = true;
      this.#driver.destroy();
      return;
    }
    this.#irPara(destino);
  }

  #irPara(indice) {
    const { rota } = this.#tour.passos[indice];
    // Atualiza o passo ANTES de navegar: a mudança de rota dispara
    // aoNavegar(), que encerraria o tour se a rota não batesse com o passo.
    this.passo = indice;
    if (rota && rota !== this.#router.path) this.#router.navigate(rota);
    this.#driver.drive(indice);
  }

  #aoDestruir() {
    if (this.#concluido) gravar(this.#local, chaveVisto(this.#tour), "concluido");
    remover(this.#sessao, CHAVE_SESSAO);

    const foco = this.#focoAnterior;
    this.#driver = null;
    this.#tour = null;
    this.#focoAnterior = null;
    this.ativo = null;
    this.passo = 0;

    if (foco?.isConnected && typeof foco.focus === "function") foco.focus();
  }

  #lerSessao() {
    const bruto = ler(this.#sessao, CHAVE_SESSAO);
    if (!bruto) return null;
    try {
      const salvo = JSON.parse(bruto);
      return typeof salvo?.id === "string" && Number.isInteger(salvo?.passo) ? salvo : null;
    } catch {
      return null;
    }
  }
}
