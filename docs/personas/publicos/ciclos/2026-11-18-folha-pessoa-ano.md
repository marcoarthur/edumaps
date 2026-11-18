# Ciclo 2026-11-18: folha contada pela pessoa, um ano por vez e na base de análise

- **Período:** 2026-11-18.
- **História:** #491 (PR #492), achados RJ-01, RJ-02 e RJ-03 da
  [décima nona avaliação da P4](../avaliacoes/2026-11-18-p4-folha.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 231.

## Resumo

- O painel financeiro conta **cada profissional uma vez**, pela pessoa (CPF
  mascarado e nome). Antes contava só pelo CPF mascarado do SIOPE, que junta
  pessoas diferentes: Cuiabá 2025 tinha 10.120 em vez de 10.557.
- O painel mostra **um ano por vez**, com os meses no cartão ("Custo total
  em 2025 (jan a dez)") e o aviso do 13º. Antes somava 2025 e dois meses de
  2026 num total só.
- A **base de análise** ganha o bloco **Remuneração (SIOPE)**: por escola e
  por ano, os profissionais do magistério, o salário médio, a carga
  horária, o salário para 40 horas e o gasto com pessoal, sem nomes nem CPF.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto direto:** o painel financeiro da
escola diz o quadro certo e o custo do ano, sem misturar anos.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:** a
base traz a folha de todas as escolas da rede numa planilha, para comparar
salário, jornada e gasto por escola.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto:** o SIOPE é só da rede
municipal (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com a folha. **Resolvido:**
RJ-01, RJ-02 e RJ-03. **Fica:** a cobertura do SIOPE (quatro municípios na
base local), que depende de carga.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** a
contagem de profissionais da folha deixa de ficar abaixo do real.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** "quanto ganha o
professor de cada escola" sai da base, com o ano no arquivo.

## O que este ciclo ensinou

- Um identificador mascarado não é chave: o CPF do SIOPE tem seis dígitos, e
  um deles é a região fiscal. O perfil da cidade já contava por nome e CPF;
  o painel financeiro não.
- Um total sem período não se cita: o cartão "Custo total (período)" somava
  o que estivesse carregado.
