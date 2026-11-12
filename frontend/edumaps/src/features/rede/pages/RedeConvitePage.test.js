// src/features/rede/pages/RedeConvitePage.test.js — convite da conta de rede (#394).
import { describe, it, expect, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import RedeConvitePage from "./RedeConvitePage.svelte";
import { resetRedeMock } from "../mocks/redeHandlers.js";
import { CONVITE_VALIDO, CONVITE_USADO, CONVITE_VENCIDO } from "../mocks/redeFixtures.js";

const abrir = (token) => render(RedeConvitePage, { token });

describe("RedeConvitePage", () => {
  beforeEach(() => resetRedeMock());

  it("define a senha com um convite válido", async () => {
    abrir(CONVITE_VALIDO);
    expect(await screen.findByText(/Convite para/)).toHaveTextContent("Técnica da Rede");
    await fireEvent.input(screen.getByLabelText("Senha nova"), { target: { value: "segredo123" } });
    await fireEvent.input(screen.getByLabelText("Repita a senha"), { target: { value: "segredo123" } });
    await fireEvent.click(screen.getByRole("button", { name: "Definir senha" }));
    expect(await screen.findByRole("status")).toHaveTextContent("Senha definida");
    expect(screen.getByRole("link", { name: "Entrar" })).toHaveAttribute("href", "/gestor");
  });

  it("confere a senha antes de enviar", async () => {
    abrir(CONVITE_VALIDO);
    await screen.findByText(/Convite para/);
    await fireEvent.input(screen.getByLabelText("Senha nova"), { target: { value: "123" } });
    await fireEvent.input(screen.getByLabelText("Repita a senha"), { target: { value: "123" } });
    await fireEvent.click(screen.getByRole("button", { name: "Definir senha" }));
    expect(screen.getByRole("alert")).toHaveTextContent("ao menos 6 caracteres");
    await fireEvent.input(screen.getByLabelText("Senha nova"), { target: { value: "segredo123" } });
    await fireEvent.input(screen.getByLabelText("Repita a senha"), { target: { value: "segredo124" } });
    await fireEvent.click(screen.getByRole("button", { name: "Definir senha" }));
    expect(screen.getByRole("alert")).toHaveTextContent("não são iguais");
  });

  it("convite já usado leva ao login", async () => {
    abrir(CONVITE_USADO);
    expect(await screen.findByRole("alert")).toHaveTextContent("já foi usado");
    expect(screen.getByRole("link", { name: "Entrar" })).toBeInTheDocument();
    expect(screen.queryByLabelText("Senha nova")).not.toBeInTheDocument();
  });

  it("convite vencido pede um novo", async () => {
    abrir(CONVITE_VENCIDO);
    expect(await screen.findByRole("alert")).toHaveTextContent("Peça um novo ao administrador");
  });

  it("convite inexistente", async () => {
    abrir("Z".repeat(43));
    expect(await screen.findByRole("alert")).toHaveTextContent("Convite não encontrado.");
  });
});
