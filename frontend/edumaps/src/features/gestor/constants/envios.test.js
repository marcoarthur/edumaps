// src/features/gestor/constants/envios.test.js
import { describe, it, expect } from "vitest";
import { ApiError } from "@/shared/api/client.js";
import {
  OPERACOES,
  seloEnvio,
  mensagemMotivo,
  mensagemErroEnvio,
  localParaIsoUtc,
} from "./envios.js";

describe("constants/envios", () => {
  it("tem as seis operações do contrato", () => {
    expect(OPERACOES.map((o) => o.valor)).toEqual([
      "aviso",
      "informacao",
      "pedido",
      "convite",
      "lembrete",
      "alerta",
    ]);
  });

  it("selo do pausado_cota diz que é a cota do dia", () => {
    expect(seloEnvio("pausado_cota").rotulo).toBe("Pausado (cota do dia)");
    expect(seloEnvio("xyz").rotulo).toBe("xyz");
  });

  it("tem mensagem para todos os motivos do 409", () => {
    for (const motivo of [
      "status",
      "smtp_indisponivel",
      "envio_desligado",
      "escola_suspensa",
      "alvo_inexistente",
      "sem_destinatarios",
      "acima_do_teto",
      "cota_insuficiente",
      "sem_email_gestor",
    ]) {
      expect(mensagemMotivo({ motivo })).toBeTruthy();
    }
    expect(mensagemMotivo({ motivo: "cota_insuficiente", saldo: 3 })).toContain("restam 3");
    expect(mensagemMotivo({ motivo: "acima_do_teto", teto: 10 })).toContain("10 destinatários");
    expect(mensagemMotivo({ motivo: "outro" })).toBeNull();
  });

  it("mensagemErroEnvio: 401 → null, 409 desconhecido usa a mensagem do servidor", () => {
    expect(mensagemErroEnvio(new ApiError("x", { status: 401 }))).toBeNull();
    expect(mensagemErroEnvio(new ApiError("Do servidor", { status: 409, data: {} }))).toBe("Do servidor");
    expect(mensagemErroEnvio(new Error("rede"), "padrão")).toBe("padrão");
  });

  it("converte datetime-local (hora local) para ISO UTC sem milissegundos", () => {
    const valor = "2026-11-03T08:30";
    const esperado = new Date(2026, 10, 3, 8, 30).toISOString().replace(".000Z", "Z");
    expect(localParaIsoUtc(valor)).toBe(esperado);
    expect(localParaIsoUtc("")).toBeNull();
    expect(localParaIsoUtc("lixo")).toBeNull();
  });
});
