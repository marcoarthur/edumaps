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
//     elemento que estava focado antes do tour;
//   - telemetria: `aoEvento` recebe abertura (com o gatilho), conclusão e
//     fechamento (com o passo, 1-based). Retomada após recarregar NÃO conta
//     como abertura.
//
// Os alvos são atributos `data-tour="<nome>"` nos componentes, nunca classes
// CSS — refatoração visual não pode quebrar a ajuda.
//
// Dependências injetáveis (driver, roteador, armazenamento) para os testes.

const PREFIXO = "edumaps.tour";
const CHAVE_SESSAO = `${PREFIXO}.em-andamento`;
// `?tour=off` desliga só a abertura AUTOMÁTICA neste navegador (perfil de
// e2e, apresentações); `?tour=on` religa. Botão "?", `?tour=<id>` e a
// retomada após recarregar continuam funcionando.
export const CHAVE_AUTOMATICO = `${PREFIXO}.automatico`;

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
 * Rotas de tour podem ser padrões com segmentos `:param` (ex.:
 * "/gestor/reunioes/:id") e `rotaInicial` pode ser uma lista (uma página que
 * atende duas rotas, como “nova” e “editar”). Mesma regra do matchRoute do
 * app: segmento a segmento, `:x` casa qualquer valor não vazio.
 * @param {string|string[]|undefined} padrao
 * @param {string} path - pathname, sem query
 */
export function rotaCasa(padrao, path) {
  if (!padrao || typeof path !== "string") return false;
  if (Array.isArray(padrao)) return padrao.some((p) => rotaCasa(p, path));
  const limpa = (p) => p.split("?")[0].replace(/\/+$/, "") || "/";
  const a = limpa(padrao).split("/").filter(Boolean);
  const b = limpa(path).split("/").filter(Boolean);
  return a.length === b.length && a.every((seg, i) => seg.startsWith(":") || seg === b[i]);
}

/** Rota concreta (sem `:param`) e única: dá para navegar até ela. */
function navegavel(rota) {
  return typeof rota === "string" && !rota.includes("/:");
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
  #espera = null;

  #router;
  #criarDriver;
  #local;
  #sessao;
  #esperaMs;
  #aoEvento;

  /**
   * @param {object} deps
   * @param {{ path: string, navigate: (to: string) => void }} deps.router
   * @param {(config: object) => object} deps.criarDriver - `driver` do driver.js
   * @param {() => Storage | null} [deps.local]
   * @param {() => Storage | null} [deps.sessao]
   * @param {number} [deps.esperaMs] - quanto esperar o alvo aparecer
   * @param {(evento: {tour_id: string, action: string, step?: number, total: number, trigger?: string}) => void} [deps.aoEvento]
   *   telemetria; nunca deve lançar (erros são engolidos aqui)
   */
  constructor({
    router,
    criarDriver,
    local = () => null,
    sessao = () => null,
    esperaMs = 4000,
    aoEvento = () => {},
  }) {
    this.#router = router;
    this.#criarDriver = criarDriver;
    this.#local = local;
    this.#sessao = sessao;
    this.#esperaMs = esperaMs;
    this.#aoEvento = aoEvento;
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
      if (rotaCasa(tour.rotaInicial, path)) return tour;
    }
    return null;
  }

  jaVisto(tour) {
    return ler(this.#local, chaveVisto(tour)) !== null;
  }

  /** Abertura automática ligada neste navegador? (ver `?tour=off`). */
  automaticoLigado() {
    return ler(this.#local, CHAVE_AUTOMATICO) !== "off";
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
      // Navegação feita pelo próprio tour (multi-página): nada a fazer.
      const rotaDoPasso = this.#tour?.passos[this.passo]?.rota;
      if (!rotaDoPasso || rotaCasa(rotaDoPasso, path)) return false;
      // Voltar do navegador (popstate) ou link fora do tour: o alvo do passo
      // sumiu da tela. Fecha e SEGUE avaliando a página nova — antes parava
      // aqui, e o tour automático da página de destino nunca abria.
      this.encerrar();
    }

    const pedido = new URLSearchParams(search).get("tour");
    if (pedido === "off") {
      gravar(this.#local, CHAVE_AUTOMATICO, "off");
      return false;
    }
    if (pedido === "on") remover(this.#local, CHAVE_AUTOMATICO);
    if (pedido && this.#tours.has(pedido)) {
      // pode recusar (tour de rota-padrão fora da página): devolve o resultado
      return this.iniciar(pedido, { origem: "link" });
    }

    const salvo = this.#lerSessao();
    if (salvo) {
      const tour = this.#tours.get(salvo.id);
      if (tour && rotaCasa(tour.passos[salvo.passo]?.rota, path)) {
        this.iniciar(salvo.id, { passo: salvo.passo, origem: "resume" });
        return true;
      }
      remover(this.#sessao, CHAVE_SESSAO);
    }

    const tour = this.tourDaRota(path);
    if (tour?.automatico && !this.jaVisto(tour) && this.automaticoLigado()) {
      if (tour.prontoQuando) {
        this.#iniciarQuandoPronto(tour, path);
        return false;
      }
      this.iniciar(tour.id, { origem: "auto" });
      return true;
    }
    return false;
  }

  /**
   * Tour automático de página que carrega dados antes de montar os alvos
   * (ex.: painel do gestor): só abre quando `prontoQuando` aparece no DOM.
   * Se não aparecer no prazo (erro, INEP inválido), não abre e não marca
   * "visto" — a pessoa ainda o verá numa visita em que o painel carregue.
   */
  #iniciarQuandoPronto(tour, path) {
    clearInterval(this.#espera);
    const inicio = Date.now();
    const seletor = seletorDoAlvo(tour.prontoQuando);
    this.#espera = setInterval(() => {
      const saiuDaPagina = this.#router.path.split("?")[0] !== path;
      if (this.ativo || saiuDaPagina) {
        clearInterval(this.#espera);
      } else if (document.querySelector(seletor)) {
        clearInterval(this.#espera);
        if (!this.jaVisto(tour)) this.iniciar(tour.id, { origem: "auto" });
      } else if (Date.now() - inicio > this.#esperaMs) {
        clearInterval(this.#espera);
      }
    }, 100);
  }

  /**
   * @param {string} id
   * @param {{passo?: number, origem?: "button"|"auto"|"link"|"resume"}} [opts]
   *   `origem` vai para a telemetria; o padrão é o botão "?".
   */
  iniciar(id, { passo = 0, origem = "button" } = {}) {
    const tour = this.#tours.get(id);
    if (!tour) return false;
    // Passo inicial com rota-padrão (detalhe de um item, “nova”/“editar”):
    // não há URL concreta para navegar — só abre já estando na página.
    const rotaInicialDoPasso = tour.passos[passo]?.rota;
    const caminhoAtual = this.#router.path.split("?")[0];
    if (rotaInicialDoPasso && !navegavel(rotaInicialDoPasso) && !rotaCasa(rotaInicialDoPasso, caminhoAtual)) {
      return false;
    }
    if (this.ativo) this.encerrar();

    this.#tour = tour;
    this.#concluido = false;
    this.#focoAnterior = typeof document !== "undefined" ? document.activeElement : null;

    // Marca já na abertura: o tour automático aparece uma vez só, mesmo que
    // a pessoa feche no primeiro passo. Não rebaixa um "concluido".
    if (this.situacao(tour) !== "concluido") gravar(this.#local, chaveVisto(tour), "visto");

    this.#driver = this.#criarDriver(this.#configuracao(tour));
    this.ativo = tour.id;
    if (origem !== "resume") {
      this.#emitir({ tour_id: tour.id, action: "start", total: tour.passos.length, trigger: origem });
    }
    this.#irPara(passo);
    return true;
  }

  encerrar() {
    this.#finalizar();
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
      // Fechamento pela pessoa (×, Esc): o driver chama onDestroyStarted e
      // NÃO destrói — quem destrói somos nós, em #finalizar. Não usamos
      // onDestroyed: o driver.js só o chama se já houver elemento ativo, e
      // um fechamento durante a animação de um passo (~0,6–1,2 s) destruía o
      // tour sem avisar, deixando `ativo` preso (sem dismiss, sem limpar a
      // sessão, e nenhum tour automático abria até recarregar).
      onDestroyStarted: () => this.#finalizar(),
    };
  }

  #mover(delta) {
    const destino = this.passo + delta;
    if (destino < 0) return;
    if (destino >= this.#tour.passos.length) {
      this.#concluido = true;
      this.#finalizar();
      return;
    }
    this.#irPara(destino);
  }

  #irPara(indice) {
    const { rota } = this.#tour.passos[indice];
    // Atualiza o passo ANTES de navegar: a mudança de rota dispara
    // aoNavegar(), que encerraria o tour se a rota não batesse com o passo.
    this.passo = indice;
    if (navegavel(rota) && !rotaCasa(rota, this.#router.path)) this.#router.navigate(rota);
    this.#driver.drive(indice);
  }

  /**
   * Único caminho de encerramento: destrói o driver (a API `destroy()` não
   * passa por onDestroyStarted, então não há recursão) e faz a limpeza.
   * Idempotente.
   */
  #finalizar() {
    const driver = this.#driver;
    if (!driver || !this.#tour) return;
    this.#driver = null;
    driver.destroy();
    this.#aoDestruir();
  }

  #aoDestruir() {
    const total = this.#tour.passos.length;
    this.#emitir(
      this.#concluido
        ? { tour_id: this.#tour.id, action: "complete", step: total, total }
        : { tour_id: this.#tour.id, action: "dismiss", step: this.passo + 1, total }
    );
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

  /** Telemetria nunca quebra o tour. */
  #emitir(evento) {
    try {
      this.#aoEvento(evento);
    } catch {
      /* fogo-e-esqueça */
    }
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
