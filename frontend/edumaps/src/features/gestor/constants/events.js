// src/features/gestor/constants/events.js
//
// Eventos (fatos) da feature gestor que interessam além dela — hoje a
// telemetria de sessão. Não carregam e-mail nem senha: o login só informa se
// deu certo (`ok`), nunca as credenciais.
export const GESTOR_EVENTS = {
  LOGIN: "gestor/login",
  LOGOUT: "gestor/logout",
};
