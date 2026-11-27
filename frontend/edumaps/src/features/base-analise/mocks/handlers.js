// src/features/base-analise/mocks/handlers.js
import { http, HttpResponse } from "msw";
import { BASE_ANALISE_FIXTURE } from "./fixtures.js";

export const baseAnaliseHandlers = [
  http.get("*/api/base-analise", ({ request }) => {
    const p = new URL(request.url).searchParams;
    const total = !p.get("uf") ? null : p.get("codigo_ibge") ? 41 : p.get("rede") === "municipal" ? 1200 : 3010;
    // #512: SP com folha só em 2026 (Ubatuba); as demais UFs sem folha.
    const folha = !p.get("uf") ? null
      : p.get("uf") === "SP"
        ? { padrao: 2026, escolas: { 2026: 48 },
            municipios: [
              { codigo_ibge: "3554102", municipio: "Taubaté", uf: "SP", anos: [{ ano: 2026, meses: 8, escolas: 0,
                fechamento: { total: 163254335, escolas_base: 0, secretaria: 163254335, fora_total: 0, fora: [] },
                salario_magisterio: { pessoas: 2961, total: 6975, base: 2669, carga_comum: 18 } }] },
              { codigo_ibge: "3555406", municipio: "Ubatuba", uf: "SP", anos: [{ ano: 2026, meses: 8, escolas: 48,
                incompletos: [{ mes: 7, nome: "julho", registros: 500, categorias: 5, registros_habitual: 1200, categorias_habitual: 9 }],
                fechamento: { total: 67696409, escolas_base: 55590647, secretaria: 11838003, fora_total: 267757,
                  por_fonte: { fundeb_70: 63980190, fundeb_30: 208437, outras: 3507782 },
                  fora: [{ inep: "35659605", escola: "JOSE LIBORIO - SEU FRANCA EM", valor: 267757 }] },
                salario_magisterio: { pessoas: 1374, total: 7186, base: 5572, carga_comum: 31, carga_suspeita: false,
                  piso: 5130.63, abaixo_piso: 6, abaixo_piso_so_secretaria: 3, abaixo_piso_diferenca_mensal: 3200.5,
                  // #604: a folha de 2026 não se compara à de 2025
                  comparacao_ano_anterior: { ano_anterior: 2025, comparavel: false, motivos: ["secretaria"], magisterio: 1374,
                    magisterio_anterior: 1300, so_secretaria: 400, so_secretaria_anterior: 20, pct_so_secretaria: 29,
                    pct_so_secretaria_anterior: 2, abaixo_piso_anterior: 1 } } }] },
            ] }
        : { padrao: null, escolas: {}, municipios: [] };
    return HttpResponse.json({ ...BASE_ANALISE_FIXTURE, total, folha });
  }),
];
