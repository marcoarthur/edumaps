# Reavaliação: P4 e as escolas similares do perfil (2026-11-18)

Vigésima primeira rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima rodada:

| Entrega | O quê |
|---|---|
| #494 | grupo de referência do perfil pelo contexto; INSE sem sinal; N por indicador (RI-01 a RI-03) |

- **Avaliou:** só a P4.
- **Material:**
  - a ajuda `escolas-semelhantes.md`;
  - a seção "Escolas similares" do perfil da escola
    (`/api/school/:inep/profile`) de 38 escolas de Salvador e 11 de São
    Paulo;
  - o código (`.school_profile_fallback_peers`);
  - o banco local, só leitura.
- **O trabalho que ela faria:** o mesmo da décima sétima rodada, agora pelo
  perfil: escolher pares de estudo de caso com "contexto parecido,
  resultado diferente". O perfil passou a ter um grupo de referência pelo
  contexto (#494), e as escolas similares ficam na mesma tela, logo abaixo.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A ajuda.** Depois da #494, a pergunta frequente de
   `escolas-semelhantes.md` diz que as similares do Perfil "ainda usam os
   indicadores do perfil, inclusive o IDEB e a nota SAEB". Ela foi medir o
   efeito.
2. **O IDEB escolhe as similares.** Nas 37 escolas de Salvador com IDEB:
   - a correlação entre o IDEB da escola e a mediana do IDEB das dez
     similares é de **0,97**;
   - em média, as similares estão a 0,23 ponto de IDEB da escola;
   - a similaridade vai de 82% a 98% (mediana de 94%).

   As similares do perfil são escolas de **resultado igual**. Para "contexto
   parecido, resultado diferente" elas não servem, e na mesma tela o grupo de
   referência agora é formado pelo contexto. As duas listas usam critérios
   opostos.
3. **Só uma parte do município entra.** O código compara a escola só com as
   primeiras 299 escolas do município que têm os mesmos indicadores
   preenchidos (`head(others, max_schools - 1)`, sem ordem definida no SQL).
   - Em **São Paulo**, as 110 similares de 11 escolas sorteadas caem todas
     entre os INEPs 35000243 e 35044428. Nessa faixa ficam 334 das 1.014
     escolas com IDEB dos anos iniciais.
   - A escola 35906591 recebe como "mais parecidas" escolas do primeiro
     terço da lista. Dois terços do município nunca são considerados.
   - Em Salvador, 173 escolas distintas preenchem as 380 vagas, e a mesma
     escola aparece como similar de 8 das 38.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem as escolas similares do perfil | as similares são escolhidas pelo IDEB (correlação 0,97), ao contrário do grupo de referência da mesma tela, e só entre as primeiras 299 escolas do município (RH-01, RH-02) |

## O que funciona

- **O grupo de referência pelo contexto** (#494), na mesma tela.
- **A ajuda honesta:** depois da #494, ela diz que as similares do Perfil
  usam o IDEB.
- **A similaridade em porcentagem**, com o IDEB de cada similar ao lado.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RH-01 | atrapalha | **As escolas similares do perfil são escolhidas pelo IDEB.** O Gower usa os indicadores do perfil, inclusive o IDEB e a nota SAEB. Na mesma tela, o grupo de referência é formado pelo contexto. Pedido: as similares pelo contexto, como o grupo (as mais próximas dele), com o IDEB de cada uma ao lado para mostrar a diferença. | Salvador, 37 escolas: correlação de 0,97 entre o IDEB da escola e a mediana das similares; distância média de 0,23 ponto | P4, P1, P6 |
| RH-02 | atrapalha | **Só as primeiras 299 escolas do município entram na comparação.** O pool é `head(others, 299)`, na ordem em que o banco devolve. Pedido: comparar com o município inteiro (a distância de uma escola contra todas já existe, #494). | São Paulo: as similares de 11 escolas estão todas entre os INEPs 35000243 e 35044428 (334 de 1.014 escolas com IDEB) | P4, P1 |

## Encaminhamento

Aguardando a aprovação do developer para abrir a issue.
