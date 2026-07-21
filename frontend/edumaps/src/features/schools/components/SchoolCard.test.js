// src/features/schools/components/SchoolCard.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import SchoolCard from "./SchoolCard.svelte";

const school = {
  escola: "EMEF Paulo Freire",
  codigo_inep: 35123456,
  endereco: "Rua das Flores, 123",
  telefone: "12981234567",
  municipio: "Ubatuba",
  uf: "SP",
  osm: "https://www.openstreetmap.org/?mlat=1&mlon=2",
  whatsapp: "https://wa.me/5512981234567",
  modalidades: ["Ensino Fundamental", "EJA"],
  tipo: "Municipal",
};

describe("SchoolCard", () => {
  it("mostra nome, INEP e localização", () => {
    render(SchoolCard, { props: { school } });
    expect(screen.getByText("EMEF Paulo Freire")).toBeInTheDocument();
    expect(screen.getByText(/INEP: 35123456/)).toBeInTheDocument();
    expect(screen.getByText(/Ubatuba - SP/)).toBeInTheDocument();
  });

  it("formata o telefone corretamente", () => {
    render(SchoolCard, { props: { school } });
    expect(screen.getByText("(12) 98123-4567")).toBeInTheDocument();
  });

  it("lista as modalidades de ensino", () => {
    render(SchoolCard, { props: { school } });
    expect(screen.getByText("Ensino Fundamental")).toBeInTheDocument();
    expect(screen.getByText("EJA")).toBeInTheDocument();
  });

  it("mostra aviso quando não há telefone", () => {
    render(SchoolCard, { props: { school: { ...school, telefone: null } } });
    expect(screen.getByText("Telefone não informado")).toBeInTheDocument();
  });
});
