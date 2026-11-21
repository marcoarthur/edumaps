# Ciclo 2026-11-21: folha da base de análise por UF e educação infantil

- **Período:** 2026-11-21.
- **História:** #512 (PR #513), achados QZ-01 a QZ-03 da
  [vigésima nona avaliação da P4](../avaliacoes/2026-11-21-p4-remuneracao-base.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 241.

## Resumo

- **O ano da folha segue a UF:** é o último ano completo dela. As bases de
  SP (2026) e de RO (2024) não saem mais vazias no padrão.
- **A tela diz quem tem folha:**
  - os municípios da UF, os anos e os meses de cada um;
  - quantas escolas do recorte têm folha no ano escolhido, com um aviso
    quando nenhuma tem;
  - `/fontes` lista todos os municípios com folha.
- **Colunas novas:** os profissionais do magistério por mês e os auxiliares
  e assistentes educacionais (pessoas e salário), que na educação infantil
  podem ser quem trabalha com as crianças. O dicionário diz que
  `prof_magisterio` não é o número de docentes.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto relevante:** a base de
análise não é a tela dela.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:**
a folha da rede dele sai na base pelo ano carregado, e as creches mostram os
auxiliares que a folha paga.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto:** a folha do SIOPE é
só da rede municipal.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora com a remuneração em todos os
municípios carregados. **Resolvido:** QZ-01 a QZ-03. Nenhum achado aberto da
vigésima nona avaliação.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** a lista
dos municípios com folha em `/fontes` diz o que a plataforma tem.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** "o salário dos
professores de X" não sai mais vazio pelo ano errado, e
"professores por escola" não sai de `prof_magisterio`.

## O que este ciclo ensinou

- Um padrão global numa fonte de cobertura local deixa a maior parte das
  bases vazia. O padrão tem de vir do recorte, e a tela tem de dizer o que
  o recorte tem.
