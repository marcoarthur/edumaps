// src/shared/tour/index.js
//
// Instância única da ajuda guiada do app + catálogo de tours.
// Novo tour: criar em ./tours/, registrar abaixo e pôr os `data-tour` nos
// componentes-alvo.
import { driver } from "driver.js";
import "driver.js/dist/driver.css";
import "./tour.css";
import { router } from "@/app/router.svelte.js";
import { eventBus, EVENTS } from "@/shared/events";
import { TourManager } from "./tourManager.svelte.js";
import buscaEscola from "./tours/buscaEscola.js";
import primeiroAcesso from "./tours/primeiroAcesso.js";
import painelGestor from "./tours/painelGestor.js";
import analises from "./tours/analises.js";
import gestorRelatorios from "./tours/gestorRelatorios.js";
import gestorContatos from "./tours/gestorContatos.js";
import gestorListas from "./tours/gestorListas.js";
import gestorEnvios from "./tours/gestorEnvios.js";
import gestorSegmentos from "./tours/gestorSegmentos.js";
import gestorPesquisas from "./tours/gestorPesquisas.js";
import gestorReunioes from "./tours/gestorReunioes.js";
import gestorInventario from "./tours/gestorInventario.js";
import gestorRelacoes from "./tours/gestorRelacoes.js";
import gestorDocumentos from "./tours/gestorDocumentos.js";
import assistenteCenso from "./tours/assistenteCenso.js";
import adminPainel from "./tours/adminPainel.js";
import configPainel from "./tours/configPainel.js";
import pesquisaAssistente from "./tours/pesquisaAssistente.js";
import pesquisaResultados from "./tours/pesquisaResultados.js";
import reuniaoAssistente from "./tours/reuniaoAssistente.js";
import reuniaoDetalhe from "./tours/reuniaoDetalhe.js";
import relacaoDetalhe from "./tours/relacaoDetalhe.js";
import relatoriosSalvos from "./tours/relatoriosSalvos.js";
import relatorioSalvo from "./tours/relatorioSalvo.js";
import consentimentoVersoes from "./tours/consentimentoVersoes.js";
import historicoAssistente from "./tours/historicoAssistente.js";

export const tourManager = new TourManager({
  router,
  criarDriver: driver,
  local: () => window.localStorage,
  sessao: () => window.sessionStorage,
  // Telemetria: o bus leva ao tracker (src/app/telemetry.js), que aplica a
  // allowlist e envia em lote.
  aoEvento: (evento) => eventBus.emit(EVENTS.TOUR, evento, { source: "tour" }),
}).registrar(
  primeiroAcesso,
  buscaEscola,
  painelGestor,
  analises,
  gestorRelatorios,
  gestorContatos,
  gestorListas,
  gestorEnvios,
  gestorSegmentos,
  gestorPesquisas,
  gestorReunioes,
  gestorInventario,
  gestorRelacoes,
  gestorDocumentos,
  assistenteCenso,
  adminPainel,
  configPainel,
  // telas secundárias (rotas com :id e listas — ver rotaCasa)
  pesquisaAssistente,
  pesquisaResultados,
  reuniaoAssistente,
  reuniaoDetalhe,
  relacaoDetalhe,
  relatoriosSalvos,
  relatorioSalvo,
  consentimentoVersoes,
  historicoAssistente,
);

export { default as BotaoAjuda } from "./BotaoAjuda.svelte";
