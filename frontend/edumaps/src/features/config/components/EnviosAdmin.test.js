// src/features/config/components/EnviosAdmin.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import EnviosAdmin from "./EnviosAdmin.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import {
  resetConfigMockState,
  getEnviosAdminMockState,
  getEnviosAdminChamadas,
} from "../mocks/configHandlers.js";
import { getEnviosAdmin, suspenderEnvios, reativarEnvios } from "../api/configApi.js";

const linhaDe = (nome) => screen.getAllByTestId("env-escola").find((tr) => tr.textContent.includes(nome));

describe("configApi — envios (admin)", () => {
  beforeEach(() => {
    setApiToken(SESSION_TOKEN);
    resetConfigMockState();
  });
  afterEach(() => setApiToken(null));

  it("lista limites e escolas; suspende (201), recusa duplicada (409) e reativa", async () => {
    const res = await getEnviosAdmin();
    expect(res.limites).toMatchObject({ cota_diaria: 500, ritmo_por_minuto: 60 });
    expect(res.escolas.map((e) => e.cod_inep)).toEqual([11000040, 35038751]);

    const { suspensao } = await suspenderEnvios(11000040, "Reclamações de spam");
    expect(suspensao).toMatchObject({ motivo: "Reclamações de spam", suspenso_por: 1 });
    await expect(suspenderEnvios(11000040, "de novo")).rejects.toMatchObject({ status: 409 });
    await expect(suspenderEnvios(11000040, "")).rejects.toMatchObject({ status: 400 });

    expect(await reativarEnvios(11000040)).toEqual({ ok: 1, envios_retomados: 2 });
    await expect(reativarEnvios(11000040)).rejects.toMatchObject({ status: 404 });
  });
});

describe("EnviosAdmin", () => {
  beforeEach(() => {
    setApiToken(SESSION_TOKEN);
    resetConfigMockState();
  });
  afterEach(() => setApiToken(null));

  it("mostra limites e a tabela de escolas com volume e suspensão", async () => {
    render(EnviosAdmin);
    expect(screen.getByText(/Carregando envios/)).toBeInTheDocument();
    expect(await screen.findByTestId("env-enabled")).toHaveTextContent("ativados");
    expect(screen.getByTestId("env-smtp")).toHaveTextContent("disponível");
    expect(screen.getByTestId("env-ritmo")).toHaveTextContent("60 e-mails/min");
    expect(screen.getByTestId("env-cota")).toHaveTextContent("500 e-mails");
    expect(screen.getByTestId("env-max")).toHaveTextContent("2.000 destinatários");

    const linhas = screen.getAllByTestId("env-escola");
    expect(linhas).toHaveLength(2);
    const maria = within(linhas[0]).getAllByRole("cell").map((c) => c.textContent.trim());
    expect(maria.slice(1, 6)).toEqual(["12", "340", "4", "2", "2"]);
    expect(within(linhas[0]).getByTestId("env-suspensao")).toHaveTextContent("—");

    const jardim = linhas[1];
    expect(within(jardim).getByTestId("env-suspensao")).toHaveTextContent("Muitas falhas de entrega");
    expect(within(jardim).getByTestId("env-suspensao")).toHaveTextContent(
      new Date("2026-10-11T18:00:00Z").toLocaleString("pt-BR"),
    );
    expect(within(jardim).getByRole("button", { name: /Reativar envios de EMEF Jardim/ })).toBeInTheDocument();
  });

  it("Suspender exige motivo e, confirmado, recarrega a tabela", async () => {
    render(EnviosAdmin);
    await screen.findByTestId("env-tabela");
    const antes = getEnviosAdminChamadas();

    await fireEvent.click(screen.getByRole("button", { name: /Suspender envios de Escola Estadual/ }));
    const dlg = await screen.findByTestId("suspender-envios-dialog");
    await fireEvent.click(within(dlg).getByRole("button", { name: "Suspender" }));
    expect(within(dlg).getByRole("alert")).toHaveTextContent(/Informe o motivo/);
    expect(getEnviosAdminMockState().escolas[0].suspensao).toBeNull();

    await fireEvent.input(within(dlg).getByRole("textbox"), { target: { value: "  Reclamações de spam " } });
    await fireEvent.click(within(dlg).getByRole("button", { name: "Suspender" }));

    expect(await screen.findByTestId("env-mensagem")).toHaveTextContent(/suspensos/);
    expect(screen.queryByTestId("suspender-envios-dialog")).not.toBeInTheDocument();
    await waitFor(() => expect(getEnviosAdminChamadas()).toBe(antes + 1));
    expect(getEnviosAdminMockState().escolas[0].suspensao.motivo).toBe("Reclamações de spam");
    expect(within(linhaDe("Maria de Lourdes")).getByTestId("env-suspensao")).toHaveTextContent(
      "Reclamações de spam",
    );
  });

  it("Suspender uma escola já suspensa (409) avisa no diálogo", async () => {
    server.use(
      http.post("/api/admin/canais/envios/suspensoes", () =>
        HttpResponse.json({ error: "x" }, { status: 409 }),
      ),
    );
    render(EnviosAdmin);
    await screen.findByTestId("env-tabela");
    await fireEvent.click(screen.getByRole("button", { name: /Suspender envios de Escola Estadual/ }));
    const dlg = await screen.findByTestId("suspender-envios-dialog");
    await fireEvent.input(within(dlg).getByRole("textbox"), { target: { value: "motivo" } });
    await fireEvent.click(within(dlg).getByRole("button", { name: "Suspender" }));
    expect(await within(dlg).findByRole("alert")).toHaveTextContent("Esta escola já está suspensa.");
  });

  it("400 do backend aparece no diálogo", async () => {
    server.use(
      http.post("/api/admin/canais/envios/suspensoes", () =>
        HttpResponse.json({ error: "Motivo longo demais." }, { status: 400 }),
      ),
    );
    render(EnviosAdmin);
    await screen.findByTestId("env-tabela");
    await fireEvent.click(screen.getByRole("button", { name: /Suspender envios de Escola Estadual/ }));
    const dlg = await screen.findByTestId("suspender-envios-dialog");
    await fireEvent.input(within(dlg).getByRole("textbox"), { target: { value: "motivo" } });
    await fireEvent.click(within(dlg).getByRole("button", { name: "Suspender" }));
    expect(await within(dlg).findByRole("alert")).toHaveTextContent("Motivo longo demais.");
  });

  it("Reativar com confirmação informa os envios retomados", async () => {
    render(EnviosAdmin);
    await screen.findByTestId("env-tabela");
    await fireEvent.click(screen.getByRole("button", { name: /Reativar envios de EMEF Jardim/ }));
    const dlg = await screen.findByTestId("reativar-envios-dialog");
    await fireEvent.click(within(dlg).getByRole("button", { name: "Reativar" }));

    expect(await screen.findByTestId("env-mensagem")).toHaveTextContent("1 envio retomado");
    await waitFor(() =>
      expect(within(linhaDe("Jardim")).getByTestId("env-suspensao")).toHaveTextContent("—"),
    );
  });

  it("Reativar sem suspensão ativa (404) avisa e recarrega", async () => {
    server.use(
      http.post("/api/admin/canais/envios/suspensoes/:cod_inep/reativar", () =>
        HttpResponse.json({ error: "x" }, { status: 404 }),
      ),
    );
    render(EnviosAdmin);
    await screen.findByTestId("env-tabela");
    const antes = getEnviosAdminChamadas();
    await fireEvent.click(screen.getByRole("button", { name: /Reativar envios de EMEF Jardim/ }));
    const dlg = await screen.findByTestId("reativar-envios-dialog");
    await fireEvent.click(within(dlg).getByRole("button", { name: "Reativar" }));
    expect(await within(dlg).findByRole("alert")).toHaveTextContent(/não tem suspensão ativa/);
    await waitFor(() => expect(getEnviosAdminChamadas()).toBe(antes + 1));
  });

  it("erro ao carregar", async () => {
    setApiToken(null);
    render(EnviosAdmin);
    expect(await screen.findByRole("alert")).toHaveTextContent(/Faça login/);
  });
});
