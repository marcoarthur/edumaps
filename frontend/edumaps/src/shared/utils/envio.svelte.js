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
export function criarEnvio() {
  let ocupado = $state(false);

  async function rodar(fn, ...args) {
    if (ocupado) return undefined;
    ocupado = true;
    try {
      return await fn(...args);
    } finally {
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
