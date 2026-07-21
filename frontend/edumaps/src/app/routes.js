// src/app/routes.js
import AboutPage from "@/features/about";
import { SchoolSearchPage } from "@/features/schools";

export const routes = [
  { path: "/busca", component: SchoolSearchPage },
  { path: "/about", component: AboutPage },
];

export function matchRoute(pathname) {
  return routes.find((r) => r.path === pathname) ?? null;
}
