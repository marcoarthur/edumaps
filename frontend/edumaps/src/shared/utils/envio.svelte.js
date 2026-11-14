import { uuid } from "./uuid.js";
import { comChaveDeEnvio } from "@/shared/api/client.js";

// Trava de envio: um botão de salvar/criar só manda um pedido por vez.
//
// Entre o clique e a resposta da API (o toast), o botão continuava clicável e
// um segundo clique criava uma réplica. Uso:
//
//   const envio = criarEnvio();
//   const salvar = envio.travar(async () => { await api.create(...) });
//   <button onclick={salvar} disabled={envio.ocupado}>
//     {envio.ocupado ? "Salvando…" : "Salvar"}
//   </button>
//
// O segundo clique (ou Enter) é ignorado na hora, sem esperar a tela
// redesenhar o `disabled`. A trava solta ao fim, com sucesso ou erro, para a
// pessoa poder tentar de novo.
//
// Chave de idempotência (#416): cada envio leva uma chave (cabeçalho
// Idempotency-Key no primeiro POST). Ela é mantida depois de uma falha de rede
// ou do servidor — a nova tentativa manda a mesma chave e, se a primeira
// chegou, o servidor devolve a resposta dela em vez de criar outra vez — e é
// trocada depois de um envio concluído.
export function criarEnvio() {
  let ocupado = $state(false);
  let chave = null;

  async function rodar(fn, ...args) {
    if (ocupado) return undefined;
    ocupado = true;
    chave ??= uuid();
    const ctx = { chave, usada: false, renovar: false };
    try {
      return await comChaveDeEnvio(ctx, () => fn(...args));
    } finally {
      if (ctx.renovar) chave = null;
      ocupado = false;
    }
  }

  return {
    get ocupado() {
      return ocupado;
    },
    rodar,
    // Embrulha um handler: (...args) => rodar(fn, ...args)
    travar: (fn) => (...args) => rodar(fn, ...args),
  };
}
