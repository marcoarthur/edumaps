import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import SchoolProfile from "./SchoolProfile.svelte";
import { transformProfileData } from "../../utils/transformProfileData.js";
import { transformEvolutionData } from "../../utils/transformEvolutionData.js";
import { PROFILE_FIXTURE, EVOLUTION_FIXTURE } from "../../mocks/fixtures.js";

function profileFixture() {
  return transformProfileData(PROFILE_FIXTURE);
}

describe("SchoolProfile", () => {
  it("renderiza o cabeçalho com nome, município/UF, INEP e censo", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("EMEF Exemplo")).toBeInTheDocument();
    expect(
      screen.getByText(/São Paulo · SP · INEP 35123456/),
    ).toBeInTheDocument();
    expect(screen.getByText(/Alta perfil escolar/)).toBeInTheDocument();
  });

  it("mostra o frescor do perfil (atualizado em + run do cluster)", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText(/Perfil atualizado em/)).toBeInTheDocument();
    expect(screen.getByText(/cluster run_123/)).toBeInTheDocument();
  });

  it("renderiza os sinais de atenção", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("Sinais de atenção")).toBeInTheDocument();
    // #542: a frase com os números, no lugar de "quartil… do cluster"
    const sinal = screen.getByTestId("sinal-ratio_aluno_docente");
    expect(sinal).toHaveTextContent(/32,1 nesta escola\. Nas \d+ escolas parecidas do município, metade tem/);
    expect(sinal.textContent).not.toMatch(/quartil/);
  });

  it("mostra mensagem positiva quando não há sinais de atenção", () => {
    const profile = profileFixture();
    profile.flags = [];
    render(SchoolProfile, { profile });

    expect(
      screen.getByText(/Nenhum indicador pior que o grupo de referência/i),
    ).toBeInTheDocument();
  });

  it("renderiza a posição relativa com os comparativos formatados", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("Posição relativa")).toBeInTheDocument();
    expect(
      screen.getAllByText("Docentes com licenciatura").length,
    ).toBeGreaterThan(0);
    expect(screen.getByText("87.0%")).toBeInTheDocument();
    // ratio do cluster (também aparece como p50 na distribuição)
    expect(screen.getAllByText("25.1").length).toBeGreaterThan(0);
  });

  it("renderiza a distribuição no grupo de referência (#493)", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("Distribuição no grupo de referência")).toBeInTheDocument();
    expect(screen.getByText("p25")).toBeInTheDocument();
    expect(screen.getByText("p75")).toBeInTheDocument();
  });

  it("renderiza a seção de evolução quando há série", () => {
    const evolutionGroups = transformEvolutionData(EVOLUTION_FIXTURE).groups;
    render(SchoolProfile, { profile: profileFixture(), evolutionGroups });

    expect(screen.getByText("Evolução")).toBeInTheDocument();
    expect(screen.getByText("Anos Finais")).toBeInTheDocument();
    expect(screen.getAllByText("IDEB observado").length).toBeGreaterThan(0);
  });

  it("explica cada tabela/gráfico com legenda e caixa (?)", () => {
    const evolutionGroups = transformEvolutionData(EVOLUTION_FIXTURE).groups;
    render(SchoolProfile, { profile: profileFixture(), evolutionGroups });

    // um (?) por seção: atenção, posição relativa, evolução, cluster, peers
    expect(
      screen.getAllByRole("button", { name: "Detalhes sobre este dado" }).length,
    ).toBeGreaterThanOrEqual(5);

    // legendas visíveis
    expect(screen.getByText(/p25\/p50\/p75/)).toBeInTheDocument();
    expect(screen.getByText(/Similaridade 0/)).toBeInTheDocument();
    expect(screen.getByText(/barra é proporcional/)).toBeInTheDocument();
  });

  it("renderiza as escolas similares com a fonte", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("EMEF Vizinha")).toBeInTheDocument();
    expect(
      screen.getByText(/fonte: contexto, no município inteiro/),
    ).toBeInTheDocument();
    expect(screen.getByText(/Similaridade 94%/)).toBeInTheDocument();
  });

  it("mostra a diferença de IDEB de cada similar para a escola (#495)", () => {
    render(SchoolProfile, { profile: profileFixture() });

    // escola 4,7; similares 6,1 e 5,8
    const diffs = screen.getAllByTestId("peer-ideb-diferenca").map((n) => n.textContent);
    expect(diffs).toEqual(["(+1,4)", "(+1,1)"]);
    expect(screen.getByText(/IDEB 6,1/)).toBeInTheDocument();
    expect(screen.getByText(/diferença de IDEB para esta escola \(4,7\)/)).toBeInTheDocument();
  });

  it("chama onSelectPeer com o co_entidade ao clicar numa similar", async () => {
    const onSelectPeer = vi.fn();
    render(SchoolProfile, { profile: profileFixture(), onSelectPeer });

    await fireEvent.click(screen.getByText("EMEF Vizinha").closest("button"));

    expect(onSelectPeer).toHaveBeenCalledWith("35003111");
  });

  it("tem links para o painel da escola e financeiro", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(
      screen.getByRole("link", { name: /Painel da escola/ }),
    ).toHaveAttribute("href", "/escola/panel?inep=35123456");
    expect(
      screen.getByRole("link", { name: /Painel financeiro/ }),
    ).toHaveAttribute("href", "/escola/financeiro?inep=35123456");
  });
});

describe("SchoolProfile: IDEB em cada etapa (#483)", () => {
  it("mostra cada etapa da escola com município, rede e Brasil da mesma etapa", () => {
    const raw = structuredClone(PROFILE_FIXTURE);
    raw.tables.ideb_por_etapa = [
      { etapa: "fundamental_ii", etapa_texto: "anos finais", ano: 2023, escola: 4.5, municipio: 4.05, rede: 4.94, brasil: 4.74, n_municipio: 153, n_rede: 13753, n_brasil: 30970, principal: true },
      { etapa: "ensino_medio", etapa_texto: "ensino médio", ano: 2023, escola: 3.6, municipio: 3.77, rede: 4.25, brasil: 4.26, n_municipio: 70, n_rede: 14154, n_brasil: 14389, principal: false },
    ];
    render(SchoolProfile, { profile: transformProfileData(raw) });
    expect(screen.getByRole("region", { name: "IDEB em cada etapa" })).toBeInTheDocument();
    expect(screen.getByText(/Anos finais 2023/)).toBeInTheDocument();
    expect(screen.getByText(/Ensino médio 2023/)).toBeInTheDocument();
    expect(screen.getByText("usada na posição relativa")).toBeInTheDocument();
  });

  it("sem a tabela (perfil antigo), não mostra a seção", () => {
    render(SchoolProfile, { profile: profileFixture() });
    expect(screen.queryByRole("region", { name: "IDEB em cada etapa" })).toBeNull();
  });

  it("mostra o critério do grupo vindo do perfil (#493)", () => {
    const p = profileFixture();
    p.cluster = { ...p.cluster, criterio: "As escolas do mesmo município de contexto mais parecido." };
    render(SchoolProfile, { profile: p });
    expect(screen.getByTestId("grupo-criterio")).toHaveTextContent("contexto mais parecido");
  });
});
