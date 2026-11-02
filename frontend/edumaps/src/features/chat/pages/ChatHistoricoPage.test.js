// src/features/chat/pages/ChatHistoricoPage.test.js
//
// Filtro por dia do histórico: clicar num dia do calendário pede a lista com
// from = to = o dia (e o fuso do navegador), mostra o aviso do filtro e a
// mensagem de dia vazio; clicar de novo ou em "Ver todas" volta à lista
// completa; busca e dia não se combinam.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { diaLocal, formatarDia } from "../utils/dia.js";
import ChatHistoricoPage from "./ChatHistoricoPage.svelte";

// dia 10 do mês corrente (o calendário abre no mês atual)
const hoje = new Date();
const DIA = diaLocal(new Date(hoje.getFullYear(), hoje.getMonth(), 10));

const TODAS = [
  { id: 1, titulo: "Matrículas", created_at: "2026-10-10T13:00:00Z", total_mensagens: 2 },
  { id: 2, titulo: "IDEB", created_at: "2026-10-03T13:00:00Z", total_mensagens: 2 },
];

let pedidosLista;
let pedidosCalendario;

function pagina(items) {
  return { items, total: items.length, total_pages: items.length ? 1 : 0, page: 1, per_page: 20 };
}

beforeEach(() => {
  window.localStorage.clear();
  setSessaoToken(SESSION_TOKEN);
  setApiToken(SESSION_TOKEN);
  pedidosLista = [];
  pedidosCalendario = [];
  server.use(
    http.get("/api/chat/conversas/calendar", ({ request }) => {
      pedidosCalendario.push(new URL(request.url).searchParams);
      return HttpResponse.json({ [DIA]: 1 });
    }),
    http.get("/api/chat/conversas/search", () => HttpResponse.json(pagina([TODAS[1]]))),
    http.get("/api/chat/conversas", ({ request }) => {
      const q = new URL(request.url).searchParams;
      pedidosLista.push(q);
      if (q.get("from") === "1999-01-01") return HttpResponse.json(pagina([]));
      return HttpResponse.json(pagina(q.get("from") ? [TODAS[0]] : TODAS));
    }),
  );
});
afterEach(() => setApiToken(null));

const botaoDoDia = () => screen.findByRole("button", { name: "10 - 1 conversa(s)" });

describe("ChatHistoricoPage — filtro por dia", () => {
  it("manda o fuso do navegador no calendário e na lista", async () => {
    render(ChatHistoricoPage);
    await screen.findByText("IDEB");
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    expect(pedidosCalendario.at(-1).get("tz")).toBe(tz);
    expect(pedidosLista.at(-1).get("tz")).toBe(tz);
    expect(pedidosLista.at(-1).get("from")).toBeNull();
  });

  it("clicar no dia filtra; clicar de novo volta a todas", async () => {
    render(ChatHistoricoPage);
    await screen.findByText("IDEB");

    await fireEvent.click(await botaoDoDia());
    await waitFor(() => expect(screen.queryByText("IDEB")).toBeNull());
    expect(pedidosLista.at(-1).get("from")).toBe(DIA);
    expect(pedidosLista.at(-1).get("to")).toBe(DIA);
    expect(pedidosLista.at(-1).get("page")).toBe("1");
    expect(screen.getByTestId("historico-filtro-dia")).toHaveTextContent(formatarDia(DIA));
    expect(await botaoDoDia()).toHaveAttribute("aria-pressed", "true");

    await fireEvent.click(await botaoDoDia());
    expect(await screen.findByText("IDEB")).toBeInTheDocument();
    expect(pedidosLista.at(-1).get("from")).toBeNull();
    expect(screen.queryByTestId("historico-filtro-dia")).toBeNull();
    expect(await botaoDoDia()).toHaveAttribute("aria-pressed", "false");
  });

  it("“Ver todas” limpa o filtro", async () => {
    render(ChatHistoricoPage);
    await screen.findByText("IDEB");
    await fireEvent.click(await botaoDoDia());
    await screen.findByTestId("historico-filtro-dia");

    await fireEvent.click(screen.getByRole("button", { name: "Ver todas" }));
    expect(await screen.findByText("IDEB")).toBeInTheDocument();
    expect(pedidosLista.at(-1).get("from")).toBeNull();
  });

  it("dia sem conversa mostra a mensagem do dia", async () => {
    server.use(
      http.get("/api/chat/conversas", ({ request }) => {
        const q = new URL(request.url).searchParams;
        pedidosLista.push(q);
        return HttpResponse.json(pagina(q.get("from") ? [] : TODAS));
      }),
    );
    render(ChatHistoricoPage);
    await screen.findByText("IDEB");
    await fireEvent.click(screen.getByRole("button", { name: "11" }));
    expect(await screen.findByText(/Nenhuma conversa salva em \d{2}\/\d{2}\/\d{4}\./)).toBeInTheDocument();
  });

  it("digitar uma busca desliga o filtro do dia", async () => {
    render(ChatHistoricoPage);
    await screen.findByText("IDEB");
    await fireEvent.click(await botaoDoDia());
    await screen.findByTestId("historico-filtro-dia");

    const busca = screen.getByRole("textbox", { name: "Buscar nas conversas salvas" });
    await fireEvent.input(busca, { target: { value: "ideb" } });
    await waitFor(() => expect(screen.queryByTestId("historico-filtro-dia")).toBeNull());
    expect(pedidosLista.at(-1).get("from")).toBeNull();
    expect(await botaoDoDia()).toHaveAttribute("aria-pressed", "false");
  });

  it("escolher um dia limpa a busca", async () => {
    render(ChatHistoricoPage);
    await screen.findByText("IDEB");
    const busca = screen.getByRole("textbox", { name: "Buscar nas conversas salvas" });
    await fireEvent.input(busca, { target: { value: "ideb" } });

    await fireEvent.click(await botaoDoDia());
    await waitFor(() => expect(busca).toHaveValue(""));
    expect(await screen.findByTestId("historico-filtro-dia")).toBeInTheDocument();
    expect(pedidosLista.at(-1).get("from")).toBe(DIA);
  });
});

describe("ChatHistoricoPage — busca única", () => {
  it("há um só campo de busca, e ele filtra a lista pelo servidor", async () => {
    render(ChatHistoricoPage);
    await screen.findByText("Matrículas");
    expect(screen.getAllByRole("textbox")).toHaveLength(1);

    const busca = screen.getByRole("textbox", { name: "Buscar nas conversas salvas" });
    await fireEvent.input(busca, { target: { value: "ideb" } });
    expect(await screen.findByText("IDEB")).toBeInTheDocument();
    expect(screen.queryByText("Matrículas")).toBeNull();
  });

  it("com busca ativa, a paginação da lista completa some", async () => {
    server.use(
      http.get("/api/chat/conversas", () =>
        HttpResponse.json({ items: TODAS, total: 45, total_pages: 3, page: 1, per_page: 20 }),
      ),
    );
    render(ChatHistoricoPage);
    expect(await screen.findByRole("navigation", { name: "Paginação" })).toBeInTheDocument();

    await fireEvent.input(screen.getByRole("textbox", { name: "Buscar nas conversas salvas" }), {
      target: { value: "ideb" },
    });
    await waitFor(() => expect(screen.queryByRole("navigation", { name: "Paginação" })).toBeNull());
  });
});
