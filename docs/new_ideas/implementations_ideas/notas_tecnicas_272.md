# Nota técnica 272: o piso na rede inteira, com a Secretaria (#575)

Achado QH-01 da quinta avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-24-p5-piso-cuiaba.md`, a
fiscalização do piso em Cuiabá). Issue aberta com a aprovação do developer;
plano aprovado com as opções A1 e B1. Um PR: #577 (merge `3d93d15`), com
uma correção de desempenho achada na validação.

## O problema

- **QH-01 (atrapalha).** A contagem abaixo do piso (#563) existia só por
  escola, na base. A folha declarada no total da Secretaria ficava de fora.
  Em Cuiabá 2026, a soma das escolas dava 157; a rede inteira tinha mais de
  1.700 pessoas abaixo do piso, quase todas só na Secretaria.

## Decisões

- **A conta na rede inteira:** `salario_rede` (#571) ganhou `piso`,
  `abaixo_piso` e `abaixo_piso_so_secretaria`, pela regra do mês típico, com
  toda a folha (escolas e Secretaria). Sem piso cadastrado ou com a carga
  fora de horas (#572), sem contagem. O piso entra na consulta por um
  `VALUES` gerado de `%PISO_MAGISTERIO`.
- **B1, só quem recebeu 3 meses ou mais** (`$MESES_MIN_PISO`), na rede e na
  coluna por escola da #563, para as duas contas serem a mesma. Medido:
  - Ubatuba 2026: 559 sem o filtro, 6 com ele (553 só na Secretaria,
    pagamentos de julho e agosto);
  - Cuiabá 2026: 1.780 sem, 1.559 com (1.421 só na Secretaria): o achado
    se sustenta;
  - Cuiabá 2025: 43 sem, 6 com; a coluna por escola cai de 47 para 6.
- **A1, onde aparece:** a tela da base (por município, junto do salário da
  rede) e o painel da Secretaria. Não no painel de cada escola, onde a
  diretora leria o número da rede como se fosse da escola.
- **O aviso:** não é a verificação legal; o total da Secretaria pode ter
  pagamentos parciais que a plataforma não distingue.

## Desempenho (achado na validação)

- O catálogo da tela da base levava 31 s em MT. Os 0,6 s que a #575
  acrescentou à cobertura não explicavam.
- Causa: `BaseAnalise->anos` pede o período da população a
  `Fontes->versao`, e `versao` resolvia o catálogo inteiro de fontes, com
  a cobertura da folha de todos os municípios (que ficou mais pesada a cada
  entrega da folha). 6 s por chamada, quatro chamadas no catálogo.
- Correção: `Fontes->resolver($dbh, $so)` resolve só as bases pedidas.
  `anos` em 0,3 s; o catálogo de MT em 4,4 s; a suíte Perl, de 89 s para
  76 s.

## Validação

- **Docker local:** a tela da base de Cuiabá 2026 com "1.559 profissionais
  do magistério, 1.421 deles só no total da Secretaria" e o aviso; o
  catálogo em 4,4 s.
- **Testes:** Perl, 211 arquivos (a rede com a Secretaria; a pessoa de um
  mês fora; a coluna por escola com o filtro); vitest. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- #576 (o aviso do mês incompleto com o registro da carga) segue aberta.
