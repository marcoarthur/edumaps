// src/app/routes.js
import AboutPage from "@/features/about";
import HomePage from "@/features/home";
import { NetworkComparePage } from "@/features/network-compare";
import { ClusterGeotagPage } from "@/features/cluster-geotag";
import { ChatPage } from "@/features/chat";
import { ConfigPage } from "@/features/config";
import { PublicaRespostaPage } from "@/features/resposta";
import {
  GestorAcessoPage,
  GestorPanelPage,
  GestorPesquisasPage,
  GestorPesquisasWizardPage,
  GestorPesquisasResultadosPage,
  GestorContatosPage,
  GestorReunioesPage,
  GestorReunioesWizardPage,
  GestorReuniaoDetailPage,
  GestorInventarioPage,
  GestorRelacoesPage,
  GestorRelacaoDetailPage,
  GestorDocumentosPage,
} from "@/features/gestor";
import {
  SchoolSearchPage,
  SchoolRankingPage,
  SchoolPayrollPage,
  SchoolFinancePage,
  SchoolPanelPage,
  SchoolSearchPageRx,
} from "@/features/schools";

export const routes = [
  { path: "/", component: HomePage },
  { path: "/about", component: AboutPage },
  { path: "/municipio/compare", component: NetworkComparePage },
  { path: "/cluster/geotag", component: ClusterGeotagPage },
  { path: "/escola/ranking", component: SchoolRankingPage },
  { path: "/escola/payroll", component: SchoolPayrollPage },
  { path: "/escola/financeiro", component: SchoolFinancePage },
  { path: "/escola/panel", component: SchoolPanelPage },
  { path: "/gestor", component: GestorAcessoPage },
  { path: "/gestor/painel", component: GestorPanelPage },
  { path: "/gestor/pesquisas", component: GestorPesquisasPage },
  { path: "/gestor/pesquisas/nova", component: GestorPesquisasWizardPage },
  { path: "/gestor/pesquisas/editar", component: GestorPesquisasWizardPage },
  { path: "/gestor/pesquisas/resultados", component: GestorPesquisasResultadosPage },
  { path: "/chat/censo", component: ChatPage },
  { path: "/config", component: ConfigPage },
  { path: "/gestor/contatos", component: GestorContatosPage },
  { path: "/gestor/reunioes", component: GestorReunioesPage },
  { path: "/gestor/reunioes/nova", component: GestorReunioesWizardPage },
  { path: "/gestor/reunioes/:id", component: GestorReuniaoDetailPage },
  { path: "/gestor/reunioes/:id/editar", component: GestorReunioesWizardPage },
  { path: "/gestor/inventario", component: GestorInventarioPage },
  { path: "/gestor/relacoes", component: GestorRelacoesPage },
  { path: "/gestor/relacoes/:id", component: GestorRelacaoDetailPage },
  { path: "/gestor/documentos", component: GestorDocumentosPage },
  { path: "/p/:token", component: PublicaRespostaPage },
  { path: "/escola/search", component: SchoolSearchPageRx },
];

/**
 * Encontra a rota correspondente ao pathname.
 *
 * O roteador do projeto é de rotas exatas, mas a fase 2 precisou de um
 * segmento dinâmico: o link público de resposta (`/p/:token`). O match é feito
 * segmento a segmento e cada `:param` captura exatamente um segmento.
 *
 * @param {string} pathname
 * @returns {{path: string, component: object, params: Record<string,string>}|null}
 */
export function matchRoute(pathname) {
  const clean = (p) => p.split("?")[0].replace(/\/+$/, "") || "/";

  for (const route of routes) {
    const pattern = clean(route.path).split("/").filter(Boolean);
    const path = clean(pathname).split("/").filter(Boolean);

    if (pattern.length !== path.length) continue;

    const params = {};
    let ok = true;
    for (let i = 0; i < pattern.length; i += 1) {
      if (pattern[i].startsWith(":")) {
        params[pattern[i].slice(1)] = decodeURIComponent(path[i]);
      } else if (pattern[i] !== path[i]) {
        ok = false;
        break;
      }
    }
    if (ok) return { path: route.path, component: route.component, params };
  }

  return null;
}