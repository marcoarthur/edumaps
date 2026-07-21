// src/app/router.svelte.js
//
// Roteador mínimo baseado em runes, sem dependência externa.
// Motivo: `svelte-routing` não tem compatibilidade comprovada com Svelte 5
// (ainda usa o padrão de instanciação legado nos próprios exemplos).
// Se o app crescer e precisar de rotas aninhadas, parâmetros dinâmicos
// complexos ou guards, trocar por uma lib dedicada é uma mudança
// localizada apenas neste arquivo — nenhuma feature depende disso direto.

class Router {
  path = $state(window.location.pathname);

  constructor() {
    window.addEventListener("popstate", () => {
      this.path = window.location.pathname;
    });
  }

  navigate(to) {
    if (to === this.path) return;
    window.history.pushState({}, "", to);
    this.path = to;
  }
}

export const router = new Router();

/**
 * Svelte action: <a href="/about" use:link>
 * Intercepta o clique para navegar via history API em vez de recarregar
 * a página inteira. Links externos e cliques com modificador (ctrl/cmd/etc)
 * continuam funcionando normalmente.
 */
export function link(node) {
  function handleClick(event) {
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }

    const href = node.getAttribute("href");
    if (!href || href.startsWith("http") || href.startsWith("//")) return;

    event.preventDefault();
    router.navigate(href);
  }

  node.addEventListener("click", handleClick);

  return {
    destroy() {
      node.removeEventListener("click", handleClick);
    },
  };
}
