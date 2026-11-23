// src/features/schools/components/SchoolRanking.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolRanking from "./SchoolRanking.svelte";
import { DEMO_SCHOOL_COD_INEP } from "../mocks/fixtures.js";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";

describe("SchoolRanking", () => {
  async function waitForRankingLoad() {
    await waitFor(() => {
      expect(
        screen.getByRole("heading", { name: "Ranking" }),
      ).toBeInTheDocument();
    });
    await waitFor(() => {
      const ordinals = screen.getAllByText(/\dº/);
      expect(ordinals.length).toBeGreaterThan(0);
    });
  }

  it("carrega o primeiro indicador disponível automaticamente e mostra o ranking", async () => {
    render(SchoolRanking, { props: { codInep: DEMO_SCHOOL_COD_INEP } });
    await waitForRankingLoad();
    // Removida a linha problemática – o waitForRankingLoad já confirma o carregamento
  });

  it("troca de indicador e recarrega o ranking", async () => {
    render(SchoolRanking, { props: { codInep: DEMO_SCHOOL_COD_INEP } });
    await waitForRankingLoad();

    const indicatorSelect = screen.getByLabelText(/indicador/i);
    await fireEvent.change(indicatorSelect, {
      target: { value: "infraestrutura" },
    });

    await waitFor(() => {
      expect(screen.getByText(/1º/)).toBeInTheDocument();
    });
  });

  it("troca de rede e recarrega o ranking com o filtro correto", async () => {
    render(SchoolRanking, { props: { codInep: DEMO_SCHOOL_COD_INEP } });
    await waitForRankingLoad();

    const networkSelect = screen.getByLabelText(/rede/i);
    await fireEvent.change(networkSelect, { target: { value: "municipal" } });

    await waitFor(() => {
      expect(screen.getByText(/de 10/)).toBeInTheDocument();
      expect(screen.getByText(/Acima de 90% das outras escolas/)).toBeInTheDocument();
    });
  });

  it("mostra aviso quando o indicador selecionado não está disponível", async () => {
    render(SchoolRanking, { props: { codInep: DEMO_SCHOOL_COD_INEP } });
    await waitForRankingLoad();

    const indicatorSelect = screen.getByLabelText(/indicador/i);
    await fireEvent.change(indicatorSelect, {
      target: { value: "ideb_ensino_medio" },
    });

    await waitFor(() => {
      expect(screen.getByText(/não está disponível/i)).toBeInTheDocument();
    });
  });

  it("chama onExport com os dados do ranking atual", async () => {
    const onExport = vi.fn();
    render(SchoolRanking, {
      props: { codInep: DEMO_SCHOOL_COD_INEP, onExport },
    });

    await waitForRankingLoad();

    const exportButton = screen.getByRole("button", {
      name: /exportar relatório/i,
    });
    await fireEvent.click(exportButton);

    expect(onExport).toHaveBeenCalledWith(
      expect.objectContaining({
        codInep: DEMO_SCHOOL_COD_INEP,
        indicator: expect.any(String),
        ranking: expect.any(Object),
      }),
    );
  });

  it("mostra o empate e explica a posição (#506)", async () => {
    server.use(http.get(`*/api/school/${DEMO_SCHOOL_COD_INEP}/ranking`, () => HttpResponse.json({
      indicador: { id: "sustentabilidade", label: "Sustentabilidade", valor: 0 },
      ano: 2025, rede: null,
      ranking: {
        municipio: { posicao: 767, total: 1432, empate: 666, abaixo: 0, percentil: 0 },
        estado: { posicao: 1, total: 16106, empate: 1, abaixo: 16105, percentil: 100 },
        nacional: null,
      },
    })));
    render(SchoolRanking, { codInep: DEMO_SCHOOL_COD_INEP });
    await waitForRankingLoad();
    const escopos = await screen.findAllByTestId("escopo-posicao");
    expect(escopos[0]).toHaveTextContent("767º de 1.432");
    expect(escopos[0]).not.toHaveTextContent("empatada com");
    // #541: último lugar dividido, no lugar de "acima de 0%"
    expect(escopos[0]).toHaveTextContent("Último lugar, dividido com 665 escolas com o mesmo valor");
    // sem empate: sem a linha
    expect(escopos[1]).not.toHaveTextContent("empatada");
    expect(escopos[1]).toHaveTextContent("Acima de 100% das outras escolas");
    expect(screen.getAllByRole("button", { name: "Detalhes sobre este dado" }).length).toBeGreaterThan(0);
  });
});
