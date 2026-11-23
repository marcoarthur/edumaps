# Reavaliação: P3 escolhe onde abrir uma unidade de educação infantil (2026-11-23)

Terceira rodada da P3 (rede privada), a pedido do developer. A anterior,
no mesmo dia (concorrentes locais em Franca), teve o veredito **não
adotaria, mais perto**, e o QR-01 virou a #531 (CEP, bairro e endereço,
entregue). Desde então, para a educação infantil:

| Entrega | O quê |
|---|---|
| #531 | CEP, bairro e endereço na base |
| #533, #535 | taxa de atendimento da creche e da pré-escola por município, no ranking e na comparação de redes |
| #545 | conveniadas do DF |
| #547 | vagas que faltam para a meta, por município e por recorte |

- **Avaliou:** só a P3.
- **Material:**
  - o ranking da creche em SP, nos municípios de 100 a 500 mil habitantes,
    e o CSV com as vagas e as conveniadas;
  - a comparação de redes de Pindamonhangaba (SP);
  - a base de análise das escolas privadas de lá (Etapas, Matrículas e
    Parceria).
- **O trabalho que ele faria:** o diretor de um grupo com 8 unidades no
  interior de SP escolhe a cidade e o bairro para uma unidade de educação
  infantil: onde falta vaga de creche, quem já atende e se vale abrir.
- ⚠️ Simulação: não substitui um mantenedor de verdade.

## O que ele fez

1. **Onde falta vaga:** no ranking da creche (SP, 100 a 500 mil
   habitantes), 25 das 71 cidades estão abaixo da meta, e faltam 13.021
   vagas no recorte. Ordenando o CSV por `vagas_faltam_meta`:
   - na região metropolitana, Itapevi (1.585), Itaquaquecetuba (1.512) e
     Mauá (1.047);
   - no interior, **Pindamonhangaba**: 8.012 crianças de 0 a 3 anos,
     39,1% atendidas, **877 vagas faltando**, sem nenhuma conveniada.
2. **Um segundo mercado, o convênio:** a coluna das conveniadas mostra
   prefeituras que compram vaga de creche em escola privada:
   Itaquaquecetuba, 4.928 matrículas; Carapicuíba, 2.834; Taboão da
   Serra, 2.108. Para o grupo, é uma linha de negócio que ele não tinha
   como medir.
3. **Quem já atende em Pindamonhangaba:**
   - a rede municipal tem 2.500 matrículas em creche;
   - 23 escolas privadas oferecem creche, todas particulares sem
     convênio, com 629 matrículas no total (27 em média, a maior com 82);
   - elas estão em 16 bairros, e só 2 sem coordenada.

   Pela base, o mercado privado de creche lá é pulverizado, sem uma rede
   grande.
4. **Vale abrir neste bairro?** Aqui a plataforma para:
   - as crianças só existem por município, e não por bairro ou em volta de
     um ponto;
   - a renda das famílias por bairro (quem pode pagar) não existe.

   A tabela de setores do Censo 2022 (crianças de 0 a 4 anos e renda por
   setor) e o job de carga existem, mas a tabela está vazia no banco, e
   nenhuma tela faria a leitura "em volta da unidade". É o AN-10 (#429,
   leitura de mercado local), que espera uma decisão de produto.

## O que funciona para ele

- A triagem de cidades pela demanda não atendida, em vagas, com o porte e
  a região.
- O mercado de convênio (vagas compradas pelas prefeituras) por cidade.
- Os concorrentes privados de creche da cidade, com o tamanho e o bairro.

## Achados novos

Nenhum achado novo que vire issue: a barreira desta rodada é o AN-10
(#429), já aberto. Evidência para lá:
- a triagem por cidade já funciona (Pindamonhangaba, 877 vagas faltando
  e 629 matrículas privadas em 23 escolas);
- o passo seguinte (bairro, renda, raio da unidade) depende da carga dos
  setores do Censo 2022 (download de cerca de 1,5 GB, com permissão) e de
  uma tela de mercado local.

A mesma carga dos setores resolveria o "onde abrir" da P2
(`avaliacoes/2026-11-23-p2-expansao-creche.md`).

## Veredito

**Adotaria, em piloto, para escolher a cidade** (melhorou: era **não
adotaria**). Ressalva: para escolher o bairro, ainda não. Falta a leitura
de mercado local (AN-10, #429).

## Encaminhamento

Comentar a #429 com a evidência desta rodada, se o developer aprovar.
