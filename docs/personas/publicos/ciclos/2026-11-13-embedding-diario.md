# Ciclo 2026-11-13: escolas semelhantes do painel em dia e sem zero falso

- **Período:** 2026-11-13. A issue nasceu da reavaliação da #138; o merge foi
  no mesmo dia.
- **História:** #413. PR #414.
- **Avaliação:** não houve rodada das personas. É uma correção de uma
  capacidade existente.
- **Engenharia:** nota técnica 196.

## Resumo

As "Escolas semelhantes" do painel da escola se atualizam sozinhas todo dia.
Antes, um Censo novo deixaria a comparação com as notas antigas. Escola a que
falta alguma nota não é mais comparada como se tivesse nota zero: a tela diz
"Sem dado para comparar".

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**O que mudou para ela:** as escolas sugeridas como parecidas acompanham o
Censo mais recente. Se faltar dado da escola dela, a tela diz isso, em vez de
sugerir pares que só parecem parecidos por causa de um zero.

**Pendente:** a comparação pelo **entorno** (#138) segue em spec, aguardando
as decisões do developer.

## P2 — Secretaria municipal (secretário de educação)

**Sem impacto direto neste ciclo.** O painel da rede não usa esta lente. A
#138 prevê a lente de entorno para a rede numa fase seguinte.

## P3 — Rede privada (mantenedor)

**Sem impacto direto neste ciclo.** O painel é o mesmo para toda escola,
inclusive a privada, e a correção vale para ela. Nada novo para o perfil de
mantenedor.

## P4 — Academia (pesquisadora)

**Sem impacto direto neste ciclo.** A similaridade não é exportada.

## P5 — Órgãos de controle e conselhos

**Sem impacto direto neste ciclo.**

## P6 — Terceiro setor e jornalismo de dados

**Sem impacto direto neste ciclo.** O painel é público, mas a mudança só
corrige o que ele já mostrava.

## O que este ciclo ensinou

- Uma task registrada e nunca enfileirada parece uma capacidade, mas não é.
  Agora a rodada diária fica agendada no boot do worker, o que foi conferido
  no ambiente local; o teste cobre o horário e o modo manual.
- "Ausência não é 0" também vale para vetores. No cosseno, o 0 não é neutro:
  ele muda a direção.
