// src/app/routes.js
import AboutPage from "@/features/about";
import { SchoolSearchPage, SchoolRankingPage } from "@/features/schools";

export const routes = [
  { path: "/busca", component: SchoolSearchPage },
  { path: "/about", component: AboutPage },
  { path: "/escola/ranking", component: SchoolRankingPage },
];

export function matchRoute(pathname) {
  return routes.find((r) => r.path === pathname) ?? null;
}
