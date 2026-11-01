// src/shared/tour/tourManager.test.js
import { describe, it, expect, beforeEach, vi } from "vitest";
import { TourManager, chaveVisto, seletorDoAlvo } from "./tourManager.svelte.js";
import buscaEscola from "./tours/buscaEscola.js";

// --- dublês ---------------------------------------------------------------

function memoria() {
  const dados = new Map();
  return {
    getItem: (k) => (dados.has(k) ? dados.get(k) : null),
    setItem: (k, v) => dados.set(k, String(v)),
    removeItem: (k) => dados.delete(k),
    dados,
  };
}

function roteadorFalso(path = "/") {
  return {
    path,
    navigate: vi.fn(function (to) {
      this.path = to;
    }),
  };
}

/** Driver falso: registra a config e expõe os ganchos para o teste disparar. */
function driverFalso() {
  const criados = [];
  const criar = (config) => {
    const d = {
      config,
      ativo: true,
      indice: undefined,
      drive: vi.fn((i) => {
        d.indice = i;
        config.onHighlighted?.(undefined, config.steps[i], { state: { activeIndex: i } });
      }),
      destroy: vi.fn(() => {
        if (!d.ativo) return;
        d.ativo = false;
        config.onDestroyed?.(undefined, undefined, {});
      }),
      // simulam o clique nos botões do popover
      proximo: () => config.onNextClick(),
      anterior: () => config.onPrevClick(),
    };
    criados.push(d);
    return d;
  };
  return { criar, criados, ultimo: () => criados.at(-1) };
}

const TOUR = {
  id: "teste",
  versao: 2,
  titulo: "Tour de teste",
  rotaInicial: "/a",
  automatico: true,
  passos: [
    { alvo: "um", titulo: "Um", texto: "1" },
    { titulo: "Dois (sem alvo)", texto: "2" },
    { rota: "/b", alvo: "tres", titulo: "Três", texto: "3" },
  ],
};

let router, drivers, local, sessao, tm;

beforeEach(() => {
  router = roteadorFalso("/a");
  drivers = driverFalso();
  local = memoria();
  sessao = memoria();
  tm = new TourManager({
    router,
    criarDriver: drivers.criar,
    local: () => local,
    sessao: () => sessao,
  }).registrar(TOUR);
});

// --- testes ---------------------------------------------------------------

describe("TourManager — configuração do driver", () => {
  it("traduz passos em steps do driver.js com seletor data-tour e textos PT-BR", () => {
    tm.iniciar("teste");
    const { config } = drivers.ultimo();

    expect(config.steps).toHaveLength(3);
    expect(config.steps[0].element).toBe('[data-tour="um"]');
    expect(config.steps[1].element).toBeUndefined(); // popover centralizado
    expect(config.steps[0].popover).toMatchObject({ title: "Um", description: "1" });
    expect(config.nextBtnText).toMatch(/Próximo/);
    expect(config.doneBtnText).toBe("Concluir");
    expect(config.progressText).toBe("{{current}} de {{total}}");
    expect(config.waitForElement).toBeGreaterThan(0);
    expect(config.disableActiveInteraction).toBe(true);
  });

  it("marca o popover como modal (aria-modal)", () => {
    tm.iniciar("teste");
    const wrapper = document.createElement("div");
    drivers.ultimo().config.onPopoverRender({ wrapper });
    expect(wrapper.getAttribute("aria-modal")).toBe("true");
  });

  it("seletorDoAlvo gera o atributo estável", () => {
    expect(seletorDoAlvo("busca-nome")).toBe('[data-tour="busca-nome"]');
  });
});

describe("TourManager — navegação entre passos e páginas", () => {
  it("avança passo a passo e navega pelo roteador ao mudar de página", () => {
    tm.iniciar("teste");
    const d = drivers.ultimo();
    expect(tm.ativo).toBe("teste");
    expect(d.drive).toHaveBeenLastCalledWith(0);

    d.proximo();
    expect(tm.passo).toBe(1);
    expect(router.navigate).not.toHaveBeenCalled(); // passo 2 herda /a

    d.proximo();
    expect(router.navigate).toHaveBeenCalledWith("/b");
    expect(d.drive).toHaveBeenLastCalledWith(2);
    expect(tm.passo).toBe(2);
  });

  it("voltar para um passo de outra página navega de volta", () => {
    tm.iniciar("teste", { passo: 2 });
    expect(router.path).toBe("/b");

    drivers.ultimo().anterior();
    expect(router.path).toBe("/a");
    expect(tm.passo).toBe(1);
  });

  it("a navegação feita pelo próprio tour não o encerra", () => {
    tm.iniciar("teste");
    drivers.ultimo().proximo();
    drivers.ultimo().proximo(); // foi para /b
    tm.aoNavegar("/b", "");
    expect(tm.ativo).toBe("teste");
  });

  it("navegar para fora (voltar do navegador) encerra o tour", () => {
    tm.iniciar("teste");
    tm.aoNavegar("/outra", "");
    expect(drivers.ultimo().destroy).toHaveBeenCalled();
    expect(tm.ativo).toBeNull();
  });

  it("anterior no primeiro passo não faz nada", () => {
    tm.iniciar("teste");
    drivers.ultimo().anterior();
    expect(tm.passo).toBe(0);
    expect(tm.ativo).toBe("teste");
  });
});

describe("TourManager — persistência", () => {
  it("marca 'visto' ao abrir e 'concluido' ao terminar o último passo", () => {
    tm.iniciar("teste");
    expect(local.getItem(chaveVisto(TOUR))).toBe("visto");
    expect(chaveVisto(TOUR)).toBe("edumaps.tour.teste.v2");

    const d = drivers.ultimo();
    d.proximo();
    d.proximo();
    d.proximo(); // além do último: concluir
    expect(d.destroy).toHaveBeenCalled();
    expect(local.getItem(chaveVisto(TOUR))).toBe("concluido");
    expect(tm.ativo).toBeNull();
    expect(sessao.getItem("edumaps.tour.em-andamento")).toBeNull();
  });

  it("fechar no meio (Esc/×) mantém 'visto' e não rebaixa um 'concluido'", () => {
    tm.iniciar("teste");
    drivers.ultimo().destroy();
    expect(local.getItem(chaveVisto(TOUR))).toBe("visto");

    local.setItem(chaveVisto(TOUR), "concluido");
    tm.iniciar("teste");
    drivers.ultimo().destroy();
    expect(local.getItem(chaveVisto(TOUR))).toBe("concluido");
  });

  it("guarda o passo em andamento na sessão e retoma após recarregar", () => {
    tm.iniciar("teste");
    drivers.ultimo().proximo();
    expect(JSON.parse(sessao.getItem("edumaps.tour.em-andamento"))).toEqual({
      id: "teste",
      passo: 1,
    });

    // "recarregar": nova instância, mesmo armazenamento
    const outro = new TourManager({
      router: roteadorFalso("/a"),
      criarDriver: drivers.criar,
      local: () => local,
      sessao: () => sessao,
    }).registrar(TOUR);
    expect(outro.aoNavegar("/a", "")).toBe(true);
    expect(outro.passo).toBe(1);
    expect(drivers.ultimo().drive).toHaveBeenLastCalledWith(1);
  });

  it("descarta progresso salvo de outra página ou corrompido", () => {
    sessao.setItem("edumaps.tour.em-andamento", JSON.stringify({ id: "teste", passo: 2 }));
    local.setItem(chaveVisto(TOUR), "visto"); // evita o automático
    expect(tm.aoNavegar("/a", "")).toBe(false);
    expect(sessao.getItem("edumaps.tour.em-andamento")).toBeNull();

    sessao.setItem("edumaps.tour.em-andamento", "{lixo");
    expect(tm.aoNavegar("/a", "")).toBe(false);
  });

  it("funciona sem armazenamento (getItem lançando)", () => {
    const quebrado = () => {
      throw new Error("SecurityError");
    };
    const semStorage = new TourManager({
      router,
      criarDriver: drivers.criar,
      local: quebrado,
      sessao: quebrado,
    }).registrar(TOUR);
    expect(semStorage.aoNavegar("/a", "")).toBe(true);
    drivers.ultimo().proximo();
    drivers.ultimo().destroy();
    expect(semStorage.ativo).toBeNull();
  });
});

describe("TourManager — disparo", () => {
  it("abre o tour automático na primeira visita, e só nela", () => {
    expect(tm.aoNavegar("/a", "")).toBe(true);
    drivers.ultimo().destroy();
    expect(tm.aoNavegar("/a", "")).toBe(false);
  });

  it("versão nova do tour é reapresentada", () => {
    local.setItem("edumaps.tour.teste.v1", "concluido");
    expect(tm.aoNavegar("/a", "")).toBe(true);
  });

  it("?tour=<id> abre o tour mesmo já visto, navegando até a rota do passo", () => {
    local.setItem(chaveVisto(TOUR), "concluido");
    router.path = "/qualquer";
    expect(tm.aoNavegar("/qualquer", "?tour=teste")).toBe(true);
    expect(router.navigate).toHaveBeenCalledWith("/a");
  });

  it("ignora ?tour= desconhecido e páginas sem tour", () => {
    expect(tm.aoNavegar("/zzz", "?tour=nao-existe")).toBe(false);
    expect(drivers.criados).toHaveLength(0);
  });

  it("tourDaRota acha o tour pela rota inicial", () => {
    expect(tm.tourDaRota("/a")?.id).toBe("teste");
    expect(tm.tourDaRota("/b")).toBeNull();
  });

  it("devolve o foco ao elemento de origem ao fechar", () => {
    const botao = document.createElement("button");
    document.body.appendChild(botao);
    botao.focus();
    tm.iniciar("teste");
    const noPopover = document.createElement("button"); // driver.js foca o popover
    document.body.appendChild(noPopover);
    noPopover.focus();
    drivers.ultimo().destroy();
    expect(document.activeElement).toBe(botao);
    botao.remove();
    noPopover.remove();
  });
});

describe("tour busca-escola (definição)", () => {
  it("todos os passos têm alvo, título e texto; termina na comparação de redes", () => {
    for (const passo of buscaEscola.passos) {
      expect(passo.alvo).toMatch(/^[a-z-]+$/);
      expect(passo.titulo).toBeTruthy();
      expect(passo.texto).toBeTruthy();
    }
    expect(buscaEscola.rotaInicial).toBe("/escola/search");
    expect(buscaEscola.passos.at(-1).rota).toBe("/municipio/compare");
  });
});
