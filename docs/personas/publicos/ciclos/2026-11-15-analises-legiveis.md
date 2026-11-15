# Ciclo 2026-11-15: análises públicas legíveis e ausência honesta

- **Período:** 2026-11-14 a 2026-11-15.
- **História:** curadoria P3–P6 das análises públicas
  ([avaliação](../avaliacoes/2026-11-14-analises-publicas.md)) e três issues
  dela: #421 (PR #425), #422 (PR #426) e #423 (PR #424).
- **Avaliação:** a curadoria de 2026-11-14 é a base. Não houve reavaliação
  depois das correções; os vereditos abaixo ficam os mesmos até lá.
- **Engenharia:** nota técnica 200.

## Resumo

As análises públicas deixam de mostrar números errados e passam a explicar a
falta de dado:

- o total no centro das roscas volta a ser o número inteiro ("77.662", não
  "77"; "R$ 8,9 mi", não "NaN");
- os sinais de atenção do perfil respeitam o sentido de cada indicador. Em
  "docentes sem especialização" e "alunos por docente", menor é melhor. O
  sinal só aparece quando a escola está pior que a mediana do grupo;
- as escolas semelhantes têm ao menos uma etapa em comum: creche não aparece
  para escola de fundamental;
- o financeiro e a folha dizem por que falta dado e em quais municípios há
  folha, em vez de "Erro ao carregar".

Uma escola estadual de Cuiabá mostrava a folha inteira da prefeitura como
"Folha da Secretaria". Agora o total da secretaria só aparece para escola
municipal.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**Impacto indireto.** O perfil da escola, que a diretora vê no painel, deixa
de acusar como problema o que é ponto forte (pouca gente sem especialização).
Na folha, a escola sem dado recebe uma explicação e o caminho para o
financeiro.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**Impacto indireto.** O perfil da rede pinta de verde a queda de "docentes sem
especialização" e de "alunos por docente", que são melhoras.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido; sem reavaliação).

**Resolvido:** escolas semelhantes com etapa em comum (AN-03), sem a
"Distância: 0.00" que não dizia nada. **Fica:** a leitura de mercado local
(AN-10), que é a dor central e segue sem tela.

## P4 — Academia (pesquisadora)

**Veredito:** não adotaria por ora (mantido; sem reavaliação).

**Resolvido:** a regra dos sinais está descrita e versionada, e a análise
diz qual versão da regra produziu o perfil. **Fica:** fontes e versão dos dados
na tela (AN-08), agrupamento reprodutível (AN-09) e universo do agrupamento
(AN-05).

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido).

**Resolvido:** o "NaN" do custo (AN-01) e a ausência como erro (AN-04). A
cobertura da folha (3 municípios) agora está escrita na tela (AN-12). O
fiscal sabe que é uma amostra. **Fica:** a cobertura em si; mais municípios
dependem de carga de dados, não de tela.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria com ressalvas, só a comparação de redes (mantido; sem
reavaliação).

**Resolvido:** o total errado da rosca de matrículas (AN-01). **Fica:** o ano
do dado na tela (AN-08) e o ranking de redes (AN-11).

## O que este ciclo ensinou

- Número formatado como texto não pode ir para um campo numérico. Um teste
  agora varre os gráficos para pegar a repetição.
- O "menor é melhor" tem de estar declarado por indicador. Sem isso, a mesma
  tela elogia e acusa a mesma coisa.
- Falta de dado é informação: dizer por que falta (e onde há) vale mais que
  um "Sem dados".
