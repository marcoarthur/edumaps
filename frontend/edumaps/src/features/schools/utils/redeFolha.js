// #610 (QE-01 da P2): os textos do painel da rede municipal inteira (a
// escola não tem folha própria no SIOPE): por que é o painel da rede, conforme
// como o município declarou no ano, e de onde vem o total.
import { faixasMeses } from "@/features/fontes/utils.js";
import { formatBRLCompact } from "./transformFinanceData.js";

const n = (v) => Number(v).toLocaleString("pt-BR");
// "em janeiro e fevereiro" / "de março a agosto"
const quando = (ms) => { const t = faixasMeses(ms); return t.startsWith("de ") ? t : `em ${t}`; };

/**
 * "Esta escola não aparece na folha do SIOPE de 2025, embora o município
 * declare por escola (167 escolas). Os números abaixo são de toda a rede
 * municipal e não permitem identificar quem atua nesta unidade."
 */
export function textoMotivoRede(rede, ano) {
  const fim = "Os números abaixo são de toda a rede municipal (escolas e total da Secretaria) e não permitem identificar quem atua nesta unidade.";
  const noAno = ano ? ` de ${ano}` : "";
  if (!rede) return `Esta escola não tem folha própria no SIOPE. ${fim}`;
  const esc = Number(rede.escolas_com_folha) || 0;
  if (rede.declaracao === "escola")
    return `Esta escola não aparece na folha do SIOPE${noAno}, embora o município declare por escola (${n(esc)} ${esc === 1 ? "escola" : "escolas"}). ${fim}`;
  if (rede.declaracao === "misto")
    return `${ano ? `Em ${ano}, o` : "O"} município declarou a folha por escola ${quando(rede.meses_escola)} e só no total da Secretaria, sem separar as escolas, ${quando(rede.meses_secretaria)}; esta escola não aparece nos meses por escola. ${fim}`;
  return `${ano ? `Em ${ano}, o` : "O"} município declarou a folha só no total da Secretaria, sem separar as escolas. ${fim}`;
}

/**
 * "Desse total, R$ 472,4 mi nas escolas da lista do Censo, R$ 17,1 mi no total
 * da Secretaria (sem escola) e R$ 28,2 mil em escolas que o Censo não lista."
 */
export function textoPartesRede(rede) {
  const p = rede?.partes;
  if (!p) return "";
  const partes = [
    [p.escolas, "nas escolas da lista do Censo"],
    [p.secretaria, "no total da Secretaria (sem escola)"],
    [p.fora, "em escolas que o Censo não lista"],
  ].filter(([v]) => Number(v) > 0).map(([v, r]) => `${formatBRLCompact(Number(v))} ${r}`);
  if (partes.length < 2) return "";
  return `Desse total, ${partes.slice(0, -1).join(", ")} e ${partes.at(-1)}.`;
}
