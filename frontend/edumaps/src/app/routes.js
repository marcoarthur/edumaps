// src/app/routes.js
import AboutPage from "@/features/about";
import {
  SchoolSearchPage,
  SchoolRankingPage,
  SchoolPayrollPage,
} from "@/features/schools";

export const routes = [
  { path: "/busca", component: SchoolSearchPage },
  { path: "/about", component: AboutPage },
  { path: "/escola/ranking", component: SchoolRankingPage },
  { path: "/escola/payroll", component: SchoolPayrollPage },
];

export function matchRoute(pathname) {
  return routes.find((r) => r.path === pathname) ?? null;
}
