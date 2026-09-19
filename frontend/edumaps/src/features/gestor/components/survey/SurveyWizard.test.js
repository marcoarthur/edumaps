// src/features/gestor/components/survey/SurveyWizard.test.js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import SurveyWizard from "./SurveyWizard.svelte";
import { addToast } from "@/shared/stores/toastStore.js";
import {
  upsertGestor,
  createPesquisa,
  updatePesquisa,
  finalizarPesquisa,
} from "../../api/gestorPesquisasApi.js";

vi.mock("../../api/gestorPesquisasApi.js", () => ({
  upsertGestor: vi.fn(),
  createPesquisa: vi.fn(),
  updatePesquisa: vi.fn(),
  finalizarPesquisa: vi.fn(),
}));

vi.mock("@/shared/stores/toastStore.js", () => ({
  addToast: vi.fn(),
}));

beforeEach(() => {
  vi.clearAllMocks();
});

const GESTOR = {
  id: 7,
  cod_inep: "11000040",
  nome: "Marina Souza",
  email: "marina@edu.gov.br",
  telefone: "(69) 99999-0001",
  cargo: "Diretora",
  cpf_masc: "***.***.***-123",
};

function serverSurvey({ id, titulo, perguntas = [], status = "rascunho" }) {
  return {
    id,
    cod_inep: "11000040",
    gestor_id: GESTOR.id,
    titulo,
    descricao: "Levantamento de percepção.",
    status,
    created_at: "2026-09-19T10:00:00",
    updated_at: "2026-09-19T10:01:00",
    gestor: { nome: GESTOR.nome, email: GESTOR.email },
    perguntas: perguntas.map((p, i) => ({
      id: 100 + i + 1,
      ordem: i + 1,
      texto: p.texto,
      tipo: p.tipo,
      obrigatoria: !!p.obrigatoria,
      opcoes: p.opcoes ?? null,
    })),
  };
}

describe("SurveyWizard — nova pesquisa sem gestor salvo", () => {
  it("começa pela etapa 'Seus dados' e avança ao salvar o gestor", async () => {
    upsertGestor.mockResolvedValue(GESTOR);
    render(SurveyWizard, { props: { inep: "11000040",} });

    expect(
      screen.getByText(/Quem está montando a pesquisa?/),
    ).toBeInTheDocument();

    await fireEvent.input(screen.getByPlaceholderText("Seu nome completo"), {
      target: { value: "Marina Souza" },
    });
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.input(screen.getByPlaceholderText("Crie uma senha"), {
      target: { value: "senha123" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar e começar" }));

    await waitFor(() => expect(upsertGestor).toHaveBeenCalled());
    expect(upsertGestor).toHaveBeenCalledWith({
      cod_inep: "11000040",
      nome: "Marina Souza",
      email: "marina@edu.gov.br",
      senha: "senha123",
    });
    expect(
      screen.getByRole("heading", { name: "Dados da pesquisa" }),
    ).toBeInTheDocument();
  });

  it("mantém o botão desabilitado com nome curto ou senha curta", async () => {
    render(SurveyWizard, { props: { inep: "11000040" } });
    await fireEvent.input(screen.getByPlaceholderText("Seu nome completo"), {
      target: { value: "M" },
    });
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.input(screen.getByPlaceholderText("Crie uma senha"), {
      target: { value: "123" },
    });
    expect(
      screen.getByRole("button", { name: "Salvar e começar" }).hasAttribute("disabled"),
    ).toBe(true);
  });

  it("avisa quando a senha está faltando", async () => {
    render(SurveyWizard, { props: { inep: "11000040" } });
    await fireEvent.input(screen.getByPlaceholderText("Seu nome completo"), {
      target: { value: "Marina Souza" },
    });
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar e começar" }));

    expect(
      screen.getByText(/Informe nome, e-mail e uma senha/),
    ).toBeInTheDocument();
    expect(upsertGestor).not.toHaveBeenCalled();
  });
});

describe("SurveyWizard — fluxo completo de montagem e publicação", () => {
  it("autosave cria o rascunho, monta perguntas e finaliza", async () => {
    createPesquisa.mockImplementation(async (payload) =>
      serverSurvey({ id: 10, titulo: payload.titulo, perguntas: payload.perguntas }),
    );
    updatePesquisa.mockImplementation(async (id, payload) =>
      serverSurvey({ id, titulo: payload.titulo, perguntas: payload.perguntas }),
    );
    finalizarPesquisa.mockResolvedValue(
      serverSurvey({
        id: 10,
        titulo: "Pesquisa de clima escolar",
        perguntas: [],
        status: "publicada",
      }),
    );

    render(SurveyWizard, {
      props: { inep: "11000040", initialGestor: GESTOR },
    });

    // ETAPA info
    await fireEvent.input(screen.getByPlaceholderText("Ex.: Pesquisa de clima escolar"), {
      target: { value: "Pesquisa de clima escolar" },
    });

    // autosave cria o rascunho (POST) com gestor_id
    await waitFor(
      () => {
        expect(createPesquisa).toHaveBeenCalled();
      },
      { timeout: 2000 },
    );
    const createPayload = createPesquisa.mock.calls[0][0];
    expect(createPayload.gestor_id).toBe(GESTOR.id);

    // adiciona pergunta → editor
    await fireEvent.click(screen.getByRole("button", { name: "+ Adicionar pergunta" }));
    expect(
      screen.getByRole("heading", { name: "Pergunta 1" }),
    ).toBeInTheDocument();

    await fireEvent.input(
      screen.getByPlaceholderText("Ex.: A escola oferece atividades no contraturno?"),
      { target: { value: "Você se sente acolhido?" } },
    );
    await fireEvent.input(screen.getByPlaceholderText("Opção 1"), {
      target: { value: "Sim" },
    });
    await fireEvent.input(screen.getByPlaceholderText("Opção 2"), {
      target: { value: "Não" },
    });

    // autosave do update (PUT)
    await waitFor(
      () => {
        expect(updatePesquisa).toHaveBeenCalled();
      },
      { timeout: 2000 },
    );
    const [updatedId, updatedPayload] = updatePesquisa.mock.calls.at(-1);
    expect(updatedId).toBe(10);
    expect(updatedPayload.perguntas[0].texto).toBe("Você se sente acolhido?");

    // revisão
    await fireEvent.click(screen.getByRole("button", { name: "Ir para revisão →" }));
    expect(
      screen.getByRole("heading", { name: "Revisão e finalizar" }),
    ).toBeInTheDocument();
    expect(screen.getAllByText(/Você se sente acolhido/).length).toBeGreaterThan(0);

    // finalizar
    await fireEvent.click(
      screen.getByRole("button", { name: "Finalizar e publicar" }),
    );
    await waitFor(() =>
      expect(finalizarPesquisa).toHaveBeenCalledWith(10),
    );
    expect(screen.getByText(/Pesquisa publicada!/)).toBeInTheDocument();
  });
});

describe("SurveyWizard — leitura de pesquisa já publicada", () => {
  it("entra direto na tela de publicada (read-only)", () => {
    const published = serverSurvey({
      id: 5,
      titulo: "Semana de ciências: temas de interesse",
      perguntas: [
        {
          texto: "Qual tema você mais quer?",
          tipo: "unica",
          obrigatoria: true,
          opcoes: [1, 2, 3].map((n) => ({ id: `o${n}`, label: `Tema ${n}` })),
        },
      ],
    });
    published.status = "publicada";

    render(SurveyWizard, {
      props: { inep: "11000040", initialSurvey: published },
    });

    expect(screen.getByText(/Pesquisa publicada!/)).toBeInTheDocument();
    expect(screen.queryByText("+ Adicionar pergunta")).not.toBeInTheDocument();
  });

  it("mostra o link público e copia ao clicar", async () => {
    const published = serverSurvey({
      id: 5,
      titulo: "Com clima",
      perguntas: [{ texto: "Q?", tipo: "texto" }],
    });
    published.status = "publicada";
    published.token = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";

    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText },
      configurable: true,
    });

    render(SurveyWizard, {
      props: { inep: "11000040", initialSurvey: published },
    });

    const linkInput = screen.getByLabelText("Link público de resposta");
    expect(linkInput.value).toBe(
      `${window.location.origin}/p/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee`,
    );

    await fireEvent.click(screen.getByRole("button", { name: "Copiar link" }));
    await waitFor(() =>
      expect(writeText).toHaveBeenCalledWith(
        `${window.location.origin}/p/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee`,
      ),
    );
    expect(addToast).toHaveBeenCalledWith(
      "Link de resposta copiado! Compartilhe com a comunidade.",
      "success",
    );
  });
});