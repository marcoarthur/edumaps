// src/features/gestor/utils/contatoParser.js
//
// Converte uma colagem de texto em contatos normalizados para o import
// (POST /contatos/import). Formato esperado por linha:
//
//   nome [;|,|\t] email [;|,|\t] telefone [;|,|\t] grupo
//
// Segue a validação do backend (não o duplica): só normaliza a forma.

const SEP = /[;,]+|\t/;

function limparValor(valor) {
  return (valor ?? "").trim().replace(/^['"]|['"]$/g, "");
}

/**
 * Parseia o texto colado em uma lista de contatos.
 * @param {string} texto
 * @returns {{nome: string, email: string|null, telefone: string|null, grupo: string|null}[]}
 */
export function parseContatos(texto) {
  const linhas = texto.split(/\r?\n/).filter((l) => l.trim());
  const out = [];

  for (const linha of linhas) {
    const [nome, email, telefone, grupo] = linha.split(SEP);
    if (!nome || !nome.trim()) continue;
    out.push({
      nome: limparValor(nome),
      email: limparValor(email) || null,
      telefone: limparValor(telefone) || null,
      grupo: limparValor(grupo) || null,
    });
  }

  return out;
}