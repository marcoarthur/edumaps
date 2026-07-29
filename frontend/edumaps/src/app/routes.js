// src/app/routes.js
import AboutPage from "@/features/about";
import {
  SchoolSearchPage,
  SchoolRankingPage,
  SchoolPayrollPage,
  SchoolPanelPage,
} from "@/features/schools";

export const routes = [
  { path: "/busca", component: SchoolSearchPage },
  { path: "/about", component: AboutPage },
  { path: "/escola/ranking", component: SchoolRankingPage },
  { path: "/escola/payroll", component: SchoolPayrollPage },
  { path: "/escola/panel", component: SchoolPanelPage },
];

export function matchRoute(pathname) {
  return routes.find((r) => r.path === pathname) ?? null;
}
