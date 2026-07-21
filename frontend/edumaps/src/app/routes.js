// src/app/routes.js
//
// Tabela de rotas. Este arquivo só mapeia path -> componente de página;
// não conhece detalhes internos de nenhuma feature — cada feature expõe
// sua própria "page" via index.js (ver features/about/index.js).
import AboutPage from "@/features/about";

export const routes = [{ path: "/about", component: AboutPage }];

export function matchRoute(pathname) {
  return routes.find((r) => r.path === pathname) ?? null;
}
