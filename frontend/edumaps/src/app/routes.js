// src/app/routes.js
import AboutPage from "@/features/about";
import HomePage from "@/features/home";
import { NetworkComparePage } from "@/features/network-compare";
import { ClusterGeotagPage } from "@/features/cluster-geotag";
import {
  SchoolSearchPage,
  SchoolRankingPage,
  SchoolPayrollPage,
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
  { path: "/escola/panel", component: SchoolPanelPage },
  { path: "/escola/search", component: SchoolSearchPageRx },
];

export function matchRoute(pathname) {
  return routes.find((r) => r.path === pathname) ?? null;
}
