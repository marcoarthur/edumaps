// src/features/schools/components/SchoolList.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import SchoolList from "./SchoolList.svelte";

const school = {
  escola: "EMEF Paulo Freire",
  codigo_inep: 1,
  endereco: "Rua X",
  municipio: "Ubatuba",
  uf: "SP",
  modalidades: [],
};

describe("SchoolList", () => {
  it("mostra estado inicial antes de qualquer busca", () => {
    render(SchoolList, { props: { hasSearched: false } });
    expect(screen.getByText(/informe um nome/i)).toBeInTheDocument();
  });

  it("mostra estado de carregamento", () => {
    render(SchoolList, { props: { loading: true, hasSearched: true } });
    expect(screen.getByText(/buscando escolas/i)).toBeInTheDocument();
  });

  it("mostra mensagem de erro", () => {
    render(SchoolList, {
      props: { error: "Falha na busca", hasSearched: true },
    });
    expect(screen.getByText("Falha na busca")).toBeInTheDocument();
  });

  it("mostra estado vazio após busca sem resultados", () => {
    render(SchoolList, { props: { schools: [], hasSearched: true } });
    expect(screen.getByText(/nenhuma escola encontrada/i)).toBeInTheDocument();
  });

  it("renderiza um card por escola encontrada", () => {
    render(SchoolList, { props: { schools: [school], hasSearched: true } });
    expect(screen.getByText("EMEF Paulo Freire")).toBeInTheDocument();
  });
});
