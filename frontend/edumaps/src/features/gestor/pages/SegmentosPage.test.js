// src/features/gestor/pages/SegmentosPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetCanaisMockState } from "../mocks/canaisHandlers.js";
import { resetEnviosMockState } from "../mocks/enviosHandlers.js";
import { server } from "../../../mocks/server.js";
import SegmentosPage from "./SegmentosPage.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("SegmentosPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    resetEnviosMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
  });

  it("lista as listas dinâmicas com as listas e o resumo do critério", async () => {
    render(SegmentosPage);
    expect(await screen.findByRole("heading", { name: "Listas dinâmicas" })).toBeInTheDocument();
    const rows = await screen.findAllByTestId("segmento-row");
    expect(rows).toHaveLength(2);
    expect(rows[0]).toHaveTextContent("Família 8ºC, Comunidade escolar");
    expect(rows[0]).toHaveTextContent("Confirmado");
    expect(rows[1]).toHaveTextContent("lista excluída");
    expect(within(rows[0]).getByRole("link", { name: "Enviar e-mail para Confirmados" })).toHaveAttribute(
      "href",
      "/gestor/envios?novo=1&alvo_tipo=segmento&alvo_id=1",
    );
  });

  it("cria com prévia ao vivo (contagem, amostra e dedupe)", async () => {
    render(SegmentosPage);
    await fireEvent.click(await screen.findByRole("button", { name: "+ Nova lista dinâmica" }));
    const form = screen.getByTestId("segmento-form");
    expect(within(form).getByTestId("segmento-previa")).toHaveTextContent("Escolha uma lista");

    await fireEvent.input(within(form).getByLabelText("Nome"), { target: { value: "Famílias" } });
    await fireEvent.click(within(form).getByLabelText("Família 8ºC"));
    await waitFor(() => expect(screen.getByTestId("segmento-previa-total")).toHaveTextContent("3"));
    expect(screen.getByText("a***@e***.org")).toBeInTheDocument();

    await fireEvent.click(within(form).getByLabelText("Comunidade escolar"));
    // Bruno está nas duas listas: conta uma vez
    await waitFor(() => expect(screen.getByTestId("segmento-previa-total")).toHaveTextContent("4"));

    await fireEvent.click(within(form).getByLabelText("Sim"));
    await waitFor(() => expect(screen.getByTestId("segmento-previa-total")).toHaveTextContent("1"));

    await fireEvent.click(within(form).getByRole("button", { name: "Salvar lista dinâmica" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Lista dinâmica criada.", "success"));
    const rows = await screen.findAllByTestId("segmento-row");
    expect(rows.map((r) => r.textContent)).toEqual(
      expect.arrayContaining([expect.stringContaining("Famílias")]),
    );
  });

  it("filtra por estado e datas", async () => {
    render(SegmentosPage);
    await fireEvent.click(await screen.findByRole("button", { name: "+ Nova lista dinâmica" }));
    const form = screen.getByTestId("segmento-form");
    await fireEvent.click(within(form).getByLabelText("Família 8ºC"));
    await waitFor(() => expect(screen.getByTestId("segmento-previa-total")).toHaveTextContent("3"));
    await fireEvent.click(within(form).getByLabelText("Pendente"));
    await waitFor(() => expect(screen.getByTestId("segmento-previa-total")).toHaveTextContent("1"));
    await fireEvent.input(within(form).getByLabelText("Inscritos desde"), { target: { value: "2026-10-13" } });
    await waitFor(() => expect(screen.getByTestId("segmento-previa-total")).toHaveTextContent("0"));
  });

  it("envia os critérios no formato do contrato", async () => {
    const corpos = [];
    server.use(
      http.post("/api/gestor/:cod_inep/canais/segmentos/previa", async ({ request }) => {
        corpos.push(await request.json());
        return HttpResponse.json({ destinatarios: 0, amostra: [], listas_ignoradas: [] });
      }),
    );
    render(SegmentosPage);
    await fireEvent.click(await screen.findByRole("button", { name: "+ Nova lista dinâmica" }));
    const form = screen.getByTestId("segmento-form");
    await fireEvent.click(within(form).getByLabelText("Comunidade escolar"));
    await fireEvent.click(within(form).getByLabelText("Família 8ºC"));
    await fireEvent.click(within(form).getByLabelText("Não"));
    await waitFor(() =>
      expect(corpos.at(-1)).toEqual({
        criterios: {
          listas: [4, 5],
          estado: [],
          email_confirmado: false,
          inscritos_desde: null,
          inscritos_ate: null,
        },
      }),
    );
    // debounce: mudanças em sequência não disparam uma prévia por clique
    expect(corpos.length).toBeLessThan(3);
  });

  it("edita uma lista dinâmica com lista excluída (aviso de listas ignoradas)", async () => {
    render(SegmentosPage);
    const rows = await screen.findAllByTestId("segmento-row");
    await fireEvent.click(within(rows[1]).getByRole("button", { name: "Editar Lista antiga" }));
    const form = screen.getByTestId("segmento-form");
    expect(within(form).getByTestId("listas-excluidas-aviso")).toBeInTheDocument();
    expect(within(form).getByLabelText("Boletim por e-mail")).toBeChecked();
    await waitFor(() => expect(screen.getByTestId("segmento-previa-total")).toHaveTextContent("1"));
    await fireEvent.click(within(form).getByRole("button", { name: "Salvar lista dinâmica" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Lista dinâmica atualizada.", "success"));
  });

  it("mostra a mensagem de nome repetido (409)", async () => {
    render(SegmentosPage);
    await fireEvent.click(await screen.findByRole("button", { name: "+ Nova lista dinâmica" }));
    const form = screen.getByTestId("segmento-form");
    await fireEvent.input(within(form).getByLabelText("Nome"), { target: { value: "Confirmados" } });
    await fireEvent.click(within(form).getByLabelText("Família 8ºC"));
    await fireEvent.click(within(form).getByRole("button", { name: "Salvar lista dinâmica" }));
    expect(await within(form).findByRole("alert")).toHaveTextContent("Já existe uma lista dinâmica com esse nome.");
  });

  it("valida nome e listas", async () => {
    render(SegmentosPage);
    await fireEvent.click(await screen.findByRole("button", { name: "+ Nova lista dinâmica" }));
    const form = screen.getByTestId("segmento-form");
    await fireEvent.click(within(form).getByRole("button", { name: "Salvar lista dinâmica" }));
    expect(within(form).getByRole("alert")).toHaveTextContent("Informe o nome");
    await fireEvent.input(within(form).getByLabelText("Nome"), { target: { value: "X" } });
    await fireEvent.click(within(form).getByRole("button", { name: "Salvar lista dinâmica" }));
    expect(within(form).getByRole("alert")).toHaveTextContent("Escolha pelo menos uma lista");
  });

  it("apaga com confirmação", async () => {
    render(SegmentosPage);
    await screen.findAllByTestId("segmento-row");
    await fireEvent.click(screen.getByRole("button", { name: "Apagar Confirmados" }));
    const dlg = await screen.findByTestId("apagar-segmento-dialog");
    await fireEvent.click(within(dlg).getByRole("button", { name: "Apagar" }));
    await waitFor(() => expect(screen.getAllByTestId("segmento-row")).toHaveLength(1));
    expect(addToast).toHaveBeenCalledWith("Lista dinâmica apagada.", "success");
  });
});
