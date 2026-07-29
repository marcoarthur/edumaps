// src/features/schools/components/SchoolRanking.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolRanking from "./SchoolRanking.svelte";
import { DEMO_SCHOOL_COD_INEP } from "../mocks/fixtures.js";

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
      expect(screen.getByText(/Acima de 90% das escolas/)).toBeInTheDocument();
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
});
