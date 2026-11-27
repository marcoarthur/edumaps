// #610 (QE-01 da P2): os textos do painel da rede municipal inteira (a
// escola não tem folha própria no SIOPE): por que é o painel da rede, conforme
// como o município declarou no ano, e de onde vem o total.
import { faixasMeses, brlAprox } from "@/features/fontes/utils.js";
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

const pct1 = (v) => `${Number(v).toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`;
const receitaDe = (f) => `${formatBRLCompact(Number(f.receita))}${Number(f.complementacao) > 0 ? `, com ${formatBRLCompact(Number(f.complementacao))} da complementação da União` : ""}`;

/**
 * #611 (QE-02 da P2): a folha e o Fundeb, a pergunta do conselho e a do
 * prefeito. Devolve as frases do bloco: [a parte paga, a adequação ao piso].
 * Ano com receita: "Em 2025, a rede pagou R$ 457,2 mi da remuneração pela
 * parcela de 70% do Fundeb: 77,8% da receita do Fundeb do ano (R$ 588,0 mi,
 * …)". Ano sem receita (referencia): a adequação contra o último ano.
 */
export function textosFolhaFundeb(f, ano) {
  if (!f || !(Number(f.receita) > 0)) return [];
  const out = [];
  const custo = Number(f.custo_piso_ano) || 0;
  const custoTxt = custo > 0 ? `cerca de ${brlAprox(custo)} no ano (13 salários, pelo piso proporcional à carga)` : "";
  if (!f.referencia) {
    if (f.pago_70 != null && f.parte_70 != null) {
      const meses = Number(f.meses_folha) || 0;
      out.push(`Em ${f.ano_receita}, a rede pagou ${formatBRLCompact(Number(f.pago_70))} da remuneração pela parcela de 70% do Fundeb: ${pct1(f.parte_70)} da receita do Fundeb do ano (${receitaDe(f)}).`
        + (meses > 0 && meses < 12 ? ` A folha do SIOPE tem só ${meses} ${meses === 1 ? "mês" : "meses"} do ano: a parte do ano inteiro é maior.` : ""));
    }
    if (custo > 0 && f.parte_70_com_piso != null)
      out.push(Number(f.parte_70_com_piso) === Number(f.parte_70)
        ? `Pôr todos no piso somaria ${custoTxt}: a parte paga pela parcela de 70% ficaria praticamente a mesma (${pct1(f.parte_70_com_piso)} da receita).`
        : `Pôr todos no piso somaria ${custoTxt}: a parte paga pela parcela de 70% iria a ${pct1(f.parte_70_com_piso)} da receita.`);
    return out;
  }
  out.push(`A receita do Fundeb${ano ? ` de ${ano}` : " deste ano"} ainda não foi publicada: o balanço anual (DCA) sai até 30 de abril do ano seguinte. A última publicada é a de ${f.ano_receita}: ${receitaDe(f)}.`);
  if (custo > 0 && f.parte_custo_piso != null)
    out.push(`Pôr todos no piso custaria ${custoTxt}, o equivalente a ${pct1(f.parte_custo_piso)} da receita do Fundeb de ${f.ano_receita}.`);
  return out;
}

