// src/shared/tour/index.js
//
// Instância única da ajuda guiada do app + catálogo de tours.
// Novo tour: criar em ./tours/, registrar abaixo e pôr os `data-tour` nos
// componentes-alvo.
import { driver } from "driver.js";
import "driver.js/dist/driver.css";
import "./tour.css";
import { router } from "@/app/router.svelte.js";
import { TourManager } from "./tourManager.svelte.js";
import buscaEscola from "./tours/buscaEscola.js";
import primeiroAcesso from "./tours/primeiroAcesso.js";

export const tourManager = new TourManager({
  router,
  criarDriver: driver,
  local: () => window.localStorage,
  sessao: () => window.sessionStorage,
}).registrar(primeiroAcesso, buscaEscola);

export { default as BotaoAjuda } from "./BotaoAjuda.svelte";
