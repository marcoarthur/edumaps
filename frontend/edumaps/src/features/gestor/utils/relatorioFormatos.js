// src/features/gestor/utils/relatorioFormatos.js
//
// Formatação dos valores do Assistente de Relatório (issue #219, contrato da
// onda 1). Os formatos vêm do R em cada coluna/indicador:
//   texto | inteiro | decimal1 | decimal2 | percentual (fração 0–1)
// Saída em pt-BR (vírgula decimal, ponto de milhar). Ausente → "—".

export const FORMATOS = ["texto", "inteiro", "decimal1", "decimal2", "percentual"];

const SEM_VALOR = "—";

const numero = (min, max) =>
  new Intl.NumberFormat("pt-BR", {
    minimumFractionDigits: min,
    maximumFractionDigits: max,
    useGrouping: "always",
  });

const FMT = {
  inteiro: numero(0, 0),
  decimal1: numero(1, 1),
  decimal2: numero(2, 2),
  auto: numero(0, 2),
  percentual: new Intl.NumberFormat("pt-BR", {
    style: "percent",
    minimumFractionDigits: 0,
    maximumFractionDigits: 1,
  }),
};

const vazio = (v) => v === null || v === undefined || v === "";

/**
 * Formata um valor segundo o formato do contrato.
 * Formato desconhecido/ausente: número com até 2 casas, ou o texto como veio.
 * @param {unknown} valor
 * @param {string} [formato]
 * @returns {string}
 */
export function formatarValor(valor, formato) {
  if (vazio(valor)) return SEM_VALOR;
  if (formato === "texto") return String(valor);

  const n = typeof valor === "number" ? valor : Number(valor);
  if (!Number.isFinite(n)) return String(valor);

  const fmt = FMT[formato] ?? FMT.auto;
  return fmt.format(n);
}

/** Formatos numéricos alinham à direita nas tabelas. */
export function ehNumerico(formato) {
  return formato !== "texto";
}

// ---------------------------------------------------------------- recorte

/** Código da região (IBGE, 1..5) → sigla do geotag. */
export const REGIAO_SIGLA = { 1: "N", 2: "NE", 3: "SE", 4: "S", 5: "CO" };

/** @param {number|string} coRegiao @returns {string|null} */
export function regiaoSigla(coRegiao) {
  return REGIAO_SIGLA[Number(coRegiao)] ?? null;
}

/** Código IBGE do município como string de 7 dígitos. */
export function codigoMunicipio(coMunicipio) {
  if (vazio(coMunicipio)) return null;
  return String(coMunicipio).padStart(7, "0");
}

export const NIVEIS = [
  { valor: "escola", rotulo: "Minha escola" },
  { valor: "municipio", rotulo: "Município" },
  { valor: "uf", rotulo: "Estado" },
  { valor: "regiao", rotulo: "Região" },
];

// ---------------------------------------------------------------- opções

const ROTULOS_OPCAO = {
  fundamental_i: "Ensino fundamental — anos iniciais",
  fundamental_ii: "Ensino fundamental — anos finais",
  ensino_medio: "Ensino médio",
  publica: "Pública (todas)",
};

/**
 * Normaliza os valores de uma opção do tema: aceita strings (contrato) ou
 * objetos {valor|id, rotulo}.
 * @returns {Array<{valor: string, rotulo: string}>}
 */
export function valoresOpcao(lista) {
  return (lista ?? []).map((item) => {
    if (item && typeof item === "object") {
      const valor = String(item.valor ?? item.id ?? "");
      return { valor, rotulo: item.rotulo ?? ROTULOS_OPCAO[valor] ?? valor };
    }
    const valor = String(item);
    return { valor, rotulo: ROTULOS_OPCAO[valor] ?? valor };
  });
}
