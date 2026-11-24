# Reavaliação: P5 prepara a fiscalização do piso em Cuiabá (2026-11-24)

Quinta rodada da P5 (órgãos de controle e conselhos), a pedido do
developer. A quarta (2026-11-24, o conselheiro do CACS-Fundeb em Ubatuba)
teve o veredito **não adotaria** (registro), e os achados viraram a #553
(folha por fonte) e a #554 (fechamento da folha), entregues. Desde então,
na folha:

| Entrega | O quê |
|---|---|
| #557, #558 | o mês incompleto e os meses só da Secretaria |
| #561 | o gasto dos meses completos |
| #563 | o salário base e a contagem abaixo do piso |
| #564 | o registro da carga (e a recarga: setembro e outubro de 2025 em Cuiabá faltam na própria fonte) |
| #571, #572 | o salário da rede inteira, com a Secretaria, e a carga que não parece em horas |

- **Avaliou:** só a P5. Ela continua só como registro.
- **Material:** a base da rede municipal de Cuiabá (Remuneração, 2025 e
  2026), o painel financeiro de uma escola, `/fontes` e as ajudas.
- **O trabalho que ele faria:** o auditor do TCE-MT monta a matriz de
  achados da fiscalização da folha do magistério de Cuiabá: o piso, a
  qualidade da declaração ao SIOPE e a folha sem escola.
- ⚠️ Simulação: não substitui um auditor de verdade.

## O que ele fez

1. **O piso em 2025:** a base dá o piso do ano (R$ 4.867,77) e, por
   escola, quem fica abaixo no mês típico: 47 na soma das escolas (40
   pessoas, segundo a ajuda). O aviso de que não é a verificação legal está
   lá. Ele anota como indício a apurar.
2. **O piso em 2026:** a soma das escolas dá 157. Mas o painel avisa que,
   de março a agosto, a folha foi declarada só no total da Secretaria, e
   que 3.141 dos 6.578 profissionais do magistério estão só lá.
   - Conferido no banco, com a mesma regra (mês típico, sem dezembro), a
     rede inteira tem 1.780 pessoas com o salário base para 40 horas abaixo
     do piso de 2026; 1.637 delas estão só no total da Secretaria, fora da
     contagem da base.
   - 1.774 dessas pessoas ficam abaixo até do piso de 2025: não é só o
     reajuste pago com atraso.
   - A plataforma não diz isso em lugar nenhum: a contagem do piso existe
     só por escola, e a linha do salário da rede (#571) não tem a contagem.
     Ele pode subestimar o achado em dez vezes.
   - Pode haver pagamentos parciais (férias, rescisão) no total da
     Secretaria; a plataforma não distingue. Também por isso a contagem
     precisa vir com o aviso.
3. **A declaração ao SIOPE:** setembro e outubro de 2025 aparecem como
   incompletos. O aviso diz "pode ser a declaração do município ao SIOPE
   ou a carga". A recarga de hoje (#564) mostrou que a planilha do SIOPE
   traz os meses assim; a carga está registrada com a data e o SHA-256.
   Para a matriz, ele precisa escrever "o SIOPE publica assim", e o aviso
   ainda deixa a dúvida.
4. **Citar:** a data da carga e o arquivo (com o SHA-256) estão em
   `/fontes`. Com isso a evidência fica rastreável.

## O que funciona para ele

- O piso do ano e a regra do mês típico, com o aviso de que não é a
  verificação legal.
- Os avisos da folha sem escola e dos meses incompletos.
- A carga registrada, com a data e o SHA-256 do arquivo.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QH-01 | atrapalha | **A contagem abaixo do piso deixa de fora a folha da Secretaria.** Ela existe só por escola, na base. Onde o município declara a folha sem escola, a maior parte da rede fica fora, e nada avisa. Pedido: a contagem do piso também na rede inteira (com a Secretaria), na linha do salário da rede, separando quantos estão só no total da Secretaria, com o aviso de que não é a verificação legal e de que o total da Secretaria pode ter pagamentos parciais. | Cuiabá 2026: 157 na soma das escolas; 1.780 na rede inteira, 1.637 deles só na Secretaria; 1.774 abaixo até do piso de 2025 | P5, P6, P2 |
| QH-02 | incomoda | **O aviso do mês incompleto não usa o registro da carga.** Ele diz "pode ser a declaração do município ao SIOPE ou a carga", mesmo quando a carga registrada mostra que a planilha baixada do SIOPE traz o mês assim. Pedido: quando o mês incompleto está numa carga registrada, dizer "a planilha do SIOPE baixada em 24/11/2026 traz este mês assim", com o link para a carga em `/fontes`. | Cuiabá 2025, setembro e outubro: iguais na recarga de 24/11/2026 (#564); o aviso ainda divide a causa | P5, P2 |

Continua aberto: AN-12 (comparação de gasto; sem a receita do Fundeb).

## Veredito

**Não adotaria** (registro; mantido). A matriz de achados sai quase
inteira: o piso, a folha sem escola e a declaração incompleta, com a fonte
rastreável. O que falta pode mudar o tamanho do achado principal: a
contagem do piso fora da Secretaria (QH-01).

## Encaminhamento

Issues **#575** (QH-01) e **#576** (QH-02), abertas com a aprovação do developer.

## Andamento

- 2026-11-24: #575 (PR #577) mergeado: QH-01 resolvido. Cuiabá 2026: 1.559
  abaixo do piso na rede inteira, 1.421 só na Secretaria (entre quem
  recebeu 3 meses ou mais), na tela da base e no painel da Secretaria.
- 2026-11-24: #576 (PR #578) mergeado: QH-02 resolvido. Com a carga
  registrada, o aviso diz "a planilha do SIOPE baixada em 24/11/2026 traz
  estes meses assim: a falta está na fonte, e não na carga".
