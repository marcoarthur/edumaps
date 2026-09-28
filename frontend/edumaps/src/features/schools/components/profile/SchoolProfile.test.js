import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import SchoolProfile from "./SchoolProfile.svelte";
import { transformProfileData } from "../../utils/transformProfileData.js";
import { PROFILE_FIXTURE } from "../../mocks/fixtures.js";

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

  it("renderiza os sinais de atenção", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("Sinais de atenção")).toBeInTheDocument();
    expect(
      screen.getByText(/Relação aluno\/docente no quartil inferior do cluster/),
    ).toBeInTheDocument();
  });

  it("mostra mensagem positiva quando não há sinais de atenção", () => {
    const profile = profileFixture();
    profile.flags = [];
    render(SchoolProfile, { profile });

    expect(
      screen.getByText(/Nenhum indicador no quartil inferior do cluster/i),
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

  it("renderiza a distribuição no cluster", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("Distribuição no cluster")).toBeInTheDocument();
    expect(screen.getByText("p25")).toBeInTheDocument();
    expect(screen.getByText("p75")).toBeInTheDocument();
  });

  it("renderiza as escolas similares com a fonte", () => {
    render(SchoolProfile, { profile: profileFixture() });

    expect(screen.getByText("EMEF Vizinha")).toBeInTheDocument();
    expect(
      screen.getByText(/fonte: Gower calculado no município/),
    ).toBeInTheDocument();
    expect(screen.getByText(/Similaridade 94%/)).toBeInTheDocument();
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
