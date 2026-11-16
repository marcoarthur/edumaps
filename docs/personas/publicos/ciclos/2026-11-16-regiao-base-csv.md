# Ciclo 2026-11-16: região na base e recorte nos CSVs do ranking

- **Período:** 2026-11-16.
- **História:** #448 (PR #450), achados RG-01 e RG-02 da
  [quarta avaliação da P4](../avaliacoes/2026-11-16-p4-ranking-regiao.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 210.

## Resumo

- A base de análise traz a região de cada escola. Juntar as UFs de uma
  região, ou as 27, não pede mais tabela auxiliar.
- Os CSVs do ranking dizem em cada linha o recorte em que a posição foi
  calculada:
  - nas redes: UF, região ou Brasil, o porte e o mínimo de escolas;
  - nas escolas: o município e a rede.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora não monta base
nem junta arquivos de ranking.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** o
CSV das escolas do município leva o município e a rede, e a planilha que
circula na secretaria não perde o contexto.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RG-01 e RG-02.
- A comparação entre regiões sai da base juntada sem mapa à mão.
- Os rankings de recortes diferentes se juntam sem misturar quintos.

**Fica:** RG-03 (#449, achar um município na lista de redes).

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Sem impacto direto.**

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** o CSV que vai para a
redação diz o recorte da posição. "Primeiro lugar" fica com o "entre quem"
ao lado.

## O que este ciclo ensinou

- Todo número relativo (posição, quinto) carrega o recorte. Se o arquivo
  pode sair da tela, o recorte vai junto, na linha.
