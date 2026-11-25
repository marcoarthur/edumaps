# Nota técnica 280: a listagem de redes e a conta que some no meio (#593)

Correção no modo autônomo autorizado pelo developer (até 25/11, 9h). Um PR:
#594. Sem avaliação de persona: não muda o que nenhum público vê.

## O problema

- `t/04-api/rede/acesso.t` falhou uma vez no CI do `main` depois do #581: a
  listagem das contas de rede do admin devolveu 404; o rerun passou.
- A listagem lê os ids das contas e depois carrega cada uma. Com `-j4`, os
  testes de custos, painel e indicadores de rede apagam as suas contas no
  fim; se isso cai entre as duas leituras, a carga da conta apagada morre
  com 404 e leva a listagem inteira junto.
- O mesmo vale fora dos testes: um admin que apaga uma conta enquanto outro
  abre a listagem.

## Decisões

- **Pular só a conta que sumiu:** o 404 de conta inexistente é ignorado na
  listagem; qualquer outro erro continua subindo (não esconder falha real).
- **Teste determinístico:** em vez de depender da corrida do `-j4`, o teste
  de modelo apaga a segunda conta durante a carga da primeira. Falha sem a
  correção, passa com ela.

## Validação

- Perl, 212 arquivos (1.897 testes), PASS local; CI do PR verde.
- Imagens locais do backend e dos dois minions reconstruídas; md5 de
  `Rede.pm` no contêiner igual ao do repositório.
