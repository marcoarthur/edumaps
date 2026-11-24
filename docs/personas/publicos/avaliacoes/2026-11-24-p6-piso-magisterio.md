# Reavaliação: P6 apura o piso do magistério na folha municipal (2026-11-24)

Terceira rodada da P6 (terceiro setor e jornalismo de dados), a pedido do
developer. A anterior (2026-11-23, creche no Nordeste) teve o veredito
**adotaria**, e o QN-01 virou a #539 (fontes do ranking, entregue). Desde
então, na folha:

| Entrega | O quê |
|---|---|
| #553 | a folha por fonte (Fundeb 70%, 30%, outras) |
| #554 | o fechamento da folha na base |
| #557, #558 | o mês incompleto e os meses só da Secretaria |
| #561 | o gasto dos meses completos, para anualizar |

- **Avaliou:** só a P6.
- **Material:**
  - `/fontes` (o cartão do SIOPE e a cobertura);
  - a base de análise das redes municipais com folha (bloco Remuneração) e
    o dicionário;
  - a folha pública de uma escola (por pessoa e mês);
  - as ajudas da base e de financeiro e folha.
- **A pauta:** o jornalista de um veículo regional quer saber se os
  professores da rede municipal recebem o piso salarial do magistério,
  nos municípios com folha: Alta Floresta D'Oeste (RO, 2024), Cuiabá (MT,
  2025) e Ubatuba (SP, 2026). O piso é sobre o vencimento básico, para 40
  horas semanais (R$ 4.580,57 em 2024; R$ 4.867,77 em 2025).
- ⚠️ Simulação: não substitui um jornalista de verdade.

## O que ele fez

1. **Onde há folha:** `/fontes` lista os quatro municípios, com os anos e
   os meses; o cartão cita o FNDE e o link do SIOPE. Mas a carga aparece
   como "carga não registrada". Para a matéria, "dados do SIOPE baixados
   em…" fica sem data. Cuiabá foi recarregado ontem (#536), e nada diz.
2. **O salário na base:** a coluna `salario_40h_magisterio` é o salário
   **total** médio da escola, por 40 horas. O salário total para 40 horas
   fica bem acima do piso (medianas dos pagamentos: Alta Floresta, R$ 6,7
   mil; Cuiabá, R$ 9,2 mil; Ubatuba, R$ 10,0 mil). Lida às pressas, a base
   diz "todos acima do piso".
3. **O piso é sobre o vencimento básico:** o SIOPE traz, em cada
   pagamento, o salário base e o total (base mais gratificações e
   adicionais). A folha pública da escola mostra o salário base por pessoa
   e mês; a base, não. Conferido no banco, por pessoa e mês, sem dezembro:
   - em Alta Floresta (2024), o salário base para 40 horas fica abaixo do
     piso de 2024 em 7,8% dos pagamentos do magistério, de 45 das 266
     pessoas em algum mês. Pelo salário total, 4,5%;
   - a mediana do salário base para 40 horas é R$ 5.176, e a do total, R$
     6.727;
   - em Cuiabá (2025) e Ubatuba (2026, contra o piso de 2025), o salário
     base abaixo do piso é raro (3% e 0,4% dos pagamentos).
4. **Refazer a conta:** pela folha pública, uma escola por vez (18 em Alta
   Floresta, 167 em Cuiabá), copiando mês a mês. Para Alta Floresta, ele
   faz à mão; para Cuiabá, desiste.
5. **Antes de publicar:** ele sabe que "abaixo do piso" num pagamento não
   prova descumprimento (complemento, jornada, licenças, mês de
   admissão). A pauta é a pergunta à prefeitura, com o número. A plataforma
   não afirma nada, e ele acha certo.

## O que funciona para ele

- A folha por escola e por pessoa, pública, com o salário base e o total.
- A cobertura em `/fontes`, com os meses e os avisos (#557, #558).
- O link do SIOPE para a matéria.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QQ-01 | atrapalha | **A base traz só o salário total; o piso é sobre o salário base.** A coluna `salario_40h_magisterio` soma gratificações e adicionais, e sai bem acima do piso; o salário base, que o SIOPE traz e a folha pública mostra, não está na base. Pedido: o salário base do magistério para 40 horas na base (média e o menor da escola) e quantos profissionais do magistério têm, em algum mês, salário base para 40 horas abaixo de um valor de referência (o piso do ano), com o aviso de que não é a verificação legal (complementos, jornada, admissão). | Alta Floresta 2024: mediana do salário base para 40 h R$ 5.176, do total R$ 6.727; 45 de 266 pessoas com salário base abaixo do piso de 2024 em algum mês (7,8% dos pagamentos) | P6, P5, P4, P2 |
| QQ-02 | incomoda | **A carga da folha não é registrada.** O cartão do SIOPE em `/fontes` diz "carga não registrada", e cada município é carregado (e recarregado) numa data diferente. A matéria não tem a data dos dados. Pedido: registrar cada carga da folha do SIOPE (município, ano, data, arquivo) e mostrar a data por município na cobertura. | `/fontes`: "Folha de pagamento da educação (SIOPE) 2024–2026 (FNDE, carga não registrada)"; Cuiabá recarregado em 2026-11-23 (#536) | P6, P4, P5 |

Continua pendente: #454 (a carga do IDEB registrada).

## Veredito

**Adotaria** (mantido), com ressalva na pauta do piso. A folha pública por
pessoa sustenta a matéria num município pequeno, feita à mão. Para
comparar municípios ou cobrir uma rede grande, falta o salário base na base
(QQ-01) e a data da carga (QQ-02).

## Encaminhamento

Achados QQ-01 e QQ-02 aguardam a aprovação do developer para virar issue.
