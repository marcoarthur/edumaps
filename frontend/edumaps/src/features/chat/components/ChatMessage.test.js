// src/features/chat/components/ChatMessage.test.js
import { describe, it, expect, vi } from "vitest";
import { render, screen, within } from "@testing-library/svelte";
import ChatMessage from "./ChatMessage.svelte";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

describe("ChatMessage", () => {
  it("assistente: markdown seguro (negrito, lista) e SQL/resultado em <details>", () => {
    const { container } = render(ChatMessage, {
      props: {
        role: "assistant",
        content: "# Resumo\n\nSão **3** escolas:\n\n1. A\n2. B",
        meta: { sql: "SELECT 1", resultado: [{ a: 1 }], linhas: 1 },
      },
    });
    const resposta = screen.getByTestId("chat-resposta");
    expect(within(resposta).getByText("3").tagName).toBe("STRONG");
    expect(within(resposta).getAllByRole("listitem")).toHaveLength(2);
    expect(resposta).not.toHaveTextContent("#");
    expect(container.querySelectorAll("details")).toHaveLength(2);
    expect(screen.getByText("SELECT 1").closest("details")).not.toBeNull();
  });

  it("usuário: texto puro, sem markdown", () => {
    render(ChatMessage, { props: { role: "user", content: "quero **negrito**" } });
    expect(screen.getByText("quero **negrito**")).toBeInTheDocument();
    expect(screen.queryByTestId("chat-resposta")).toBeNull();
  });

  it("gráfico de pizza vira Donut; de linhas, LineChart", () => {
    render(ChatMessage, {
      props: {
        role: "assistant",
        content: "ok",
        meta: { chart: { data: [{ labels: ["U", "R"], values: [7, 3], type: "pie" }], layout: {} } },
      },
    });
    expect(screen.getByTestId("chat-grafico")).toHaveAttribute("data-grafico", "pizza");
    expect(screen.getByTestId("carbon-chart-stub")).toHaveAttribute("data-rows", "2");
  });

  it("chart irreconhecível não quebra a mensagem", () => {
    render(ChatMessage, {
      props: { role: "assistant", content: "ok", meta: { chart: { data: "lixo" } } },
    });
    expect(screen.getByTestId("chat-resposta")).toHaveTextContent("ok");
    expect(screen.queryByTestId("chat-grafico")).toBeNull();
  });
});
