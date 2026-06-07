import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach } from "vitest";
import SearchSchoolPage from "../lib/School/SearchSchoolPage.svelte";
import { fetchSchoolScores } from "../lib/service/school.js";

// 1. Mock do serviço que o ScoresModal vai chamar internamente
vi.mock("../lib/service/school.js", () => ({
  fetchSchoolScores: vi.fn(),
}));

describe("SearchSchoolPage Integration - Fluxo de Scores", () => {
  // Dados simulados da busca de escolas
  const mockEscolasBusca = [
    {
      codigo_inep: "112233",
      escola: "Escola Municipal Paulo Freire",
      municipio: "Ubatuba",
      uf: "SP",
      tipo: "Municipal",
      modalidades: ["Ensino Fundamental"],
    },
  ];

  // Dados simulados do detalhe dos scores
  const mockScoresData = {
    co_entidade: "112233",
    nu_ano_censo: "2026",
    data_atualizacao: "2026-06-07T12:00:00Z",
    score_infraestrutura: "9.0",
  };

  beforeEach(() => {
    vi.clearAllMocks();

    // 2. Mock do fetch global para a busca de escolas da página
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue(mockEscolasBusca),
    });
  });

  it("deve buscar escolas, listar o resultado e abrir o modal de scores ao clicar no botão correspondente", async () => {
    // Renderiza a página principal de busca
    render(SearchSchoolPage);

    // Verifica se a página carregou o cabeçalho básico
    expect(screen.getByText("🔍 Busca de Escolas")).toBeInTheDocument();

    // 3. Simular a busca disparada pelo SearchForm
    // Como o SearchForm está em outro arquivo e dispara o evento 'search',
    // vamos preencher o input de texto e clicar no botão de busca.
    const inputNome = screen.getByLabelText(/Nome da Escola/i);
    await fireEvent.input(inputNome, { target: { value: "Paulo Freire" } });

    const btnBuscar = screen.getByRole("button", { name: /buscar|search/i });
    await fireEvent.click(btnBuscar);

    // 4. Verificar se a API de busca foi chamada e a listagem atualizou
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/school/search/Paulo%20Freire"),
      );
    });

    // Confere se o componente SchList renderizou a escola retornada
    await waitFor(() => {
      expect(
        screen.getByText("Escola Municipal Paulo Freire"),
      ).toBeInTheDocument();
    });

    // 5. Configurar o mock do modal antes do clique
    fetchSchoolScores.mockResolvedValue(mockScoresData);

    // 6. Simular o clique no botão de visualizar scores dentro da lista
    // (Nota: Ajuste o query/texto se o seu botão no SchList usar outro texto ou ícone)
    const btnVerScores = screen.getByRole("button", { name: /pontuação/i });
    await fireEvent.click(btnVerScores);

    // 7. Verificar se o modal abriu exibindo o estado de carregamento e depois os dados
    //expect(screen.getByText("Carregando scores...")).toBeInTheDocument();

    await waitFor(() => {
      expect(fetchSchoolScores).toHaveBeenCalledWith("112233");
      expect(screen.getByText("Scores da Escola")).toBeInTheDocument();
    });

    // 8. Validar se os dados finais do SchoolScores estão visíveis dentro do modal integrado
    expect(screen.getByText("Código: 112233 | Ano: 2026")).toBeInTheDocument();
  });
});
