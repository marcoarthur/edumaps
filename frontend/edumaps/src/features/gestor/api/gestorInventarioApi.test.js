// src/features/gestor/api/gestorInventarioApi.test.js
// Exercita a camada API do inventário contra os handlers MSW.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_INVENTARIO } from "../mocks/inventarioFixtures.js";
import {
  getInventario,
  importarCenso,
  createCategoria,
  createFornecedor,
  createItem,
  listItens,
  uploadAnexo,
  downloadAnexo,
} from "./gestorInventarioApi.js";

describe("gestorInventarioApi", () => {
  beforeEach(() => {
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    setSessaoToken(null);
  });

  it("carrega censo, categorias, fornecedores e itens", async () => {
    const data = await getInventario(INEP_INVENTARIO);
    expect(data.ano).toBe(2025);
    expect(data.censo.grupos.some((g) => g.key === "dispositivos")).toBe(true);
    expect(data.categorias.length).toBeGreaterThan(0);
    expect(data.itens.length).toBeGreaterThan(0);
  });

  it("importa o baseline do Censo (idempotente)", async () => {
    const res = await importarCenso(INEP_INVENTARIO);
    expect(res.importados).toBeGreaterThan(0);
    const again = await importarCenso(INEP_INVENTARIO);
    expect(again.importados).toBe(0);
  });

  it("cria categoria, item e fornecedor", async () => {
    const cat = await createCategoria(INEP_INVENTARIO, { tipo: "recurso", nome: "Material de limpeza" });
    expect(cat.origem).toBe("manual");

    const forn = await createFornecedor(INEP_INVENTARIO, { nome: "Limpa Tudo", tipo_servico: "limpeza" });
    expect(forn.id).toBeTruthy();

    const item = await createItem(INEP_INVENTARIO, {
      categoria_id: cat.id,
      nome: "Desinfetante",
      quantidade: 5,
      unidade: "litro",
      valor: 9.9,
      fornecedor_id: forn.id,
      atributos: { fragrancia: "lavanda" },
    });
    expect(item.categoria_nome).toBe("Material de limpeza");
    expect(item.fornecedor_nome).toBe("Limpa Tudo");
    expect(item.atributos.fragrancia).toBe("lavanda");

    const lista = await listItens(INEP_INVENTARIO, { categoria_id: cat.id });
    expect(lista.some((i) => i.id === item.id)).toBe(true);
  });

  it("faz upload e download de anexo do item", async () => {
    const cat = await createCategoria(INEP_INVENTARIO, { tipo: "recurso", nome: "Anexáveis" });
    const item = await createItem(INEP_INVENTARIO, { categoria_id: cat.id, nome: "Item com nota" });

    const file = new File(["%PDF-1.4 nota"], "nota.pdf", { type: "application/pdf" });
    const up = await uploadAnexo(INEP_INVENTARIO, item.id, file);
    expect(up.anexos.at(-1).nome_original).toBe("nota.pdf");

    const { blob, filename } = await downloadAnexo(INEP_INVENTARIO, item.id, up.anexos.at(-1).id);
    expect(filename).toBe("nota.pdf");
    expect(await blob.text()).toBe("conteudo-do-anexo-mock");
  });
});
