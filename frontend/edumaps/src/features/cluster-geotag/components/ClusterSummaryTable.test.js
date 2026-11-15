import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import ClusterSummaryTable from "./ClusterSummaryTable.svelte";

const COLS = [{ column_name: "in_internet", comment: "Acesso à internet na escola?" }];

describe("ClusterSummaryTable (#427)", () => {
  it("mostra o que mais distingue o grupo, com nome legível e média geral", () => {
    render(ClusterSummaryTable, {
      props: {
        columns: COLS,
        summary: [{
          cluster_id: 1, cluster_size: 63, cluster_label: "Alta qualidade de infraestrutura",
          indicators: {},
          destaques: [{ indicador: "in_internet", media_grupo: 0.95, media_geral: 0.6, z: 1.2 }],
        }, {
          cluster_id: 2, cluster_size: 1, cluster_label: "Grupo pequeno (1 escola)",
          indicators: {}, destaques: [],
        }],
      },
    });
    const d = screen.getByTestId("destaques");
    expect(d).toHaveTextContent("Acesso à internet: 95% × 60%");
    expect(screen.getByText("Grupo pequeno (1 escola)")).toBeInTheDocument();
    expect(screen.queryByText(/in_internet|in internet/)).toBeNull();
  });

  it("execução antiga (sem destaques) cai nos maiores valores", () => {
    render(ClusterSummaryTable, {
      props: { summary: [{ cluster_id: 3, cluster_size: 5, indicators: { qt_doc_bas: 12 } }] },
    });
    expect(screen.getByText("Grupo 3")).toBeInTheDocument();
    expect(screen.getByText(/qt doc bas/)).toBeInTheDocument();
  });
});
