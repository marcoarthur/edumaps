// src/features/gestor/utils/gestorAuth.js
// Restaura o token salvo (localStorage) e devolve se existia sessão.
import { setApiToken } from "@/shared/api/client.js";
import { getSessaoToken } from "./gestorSession.js";

export function restaurarSessao() {
  const token = getSessaoToken();
  if (token) setApiToken(token);
  return !!token;
}