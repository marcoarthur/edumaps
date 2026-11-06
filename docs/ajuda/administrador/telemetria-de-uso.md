---
titulo: "Telemetria de uso: o que é registrado"
publico: [administrador]
modulo: administrador
nivel: intermediario
status: ativo
relacionadas: [painel-de-administracao, lgpd-e-pii]
funcionalidade: ../../funcionalidades/plataforma/telemetria-de-sessao.md
ultima_revisao: 2026-11-06
---

# Telemetria de uso: o que é registrado

> **Para quem:** Administrador que acompanha o uso da plataforma e responde por ele na LGPD  
> **Tempo de leitura:** ~4 min

## Em 30 segundos

O EduMaps registra, de forma agregada, **como a plataforma é usada**: quantas
sessões, de visitantes anônimos ou de gestores logados, quais telas são mais
acessadas, quantas buscas e como a ajuda guiada é usada. Ele **não** registra o
que a pessoa digita. Os números aparecem no
[Painel de administração](painel-de-administracao.md).

## Passo a passo

1. **Onde ir:** menu **Administração**, entrando com um gestor que tenha perfil
   de administrador. Os outros veem *"Esta área é restrita a administradores da
   instalação"*.
2. **Escolher a janela:** 6 h, 12 h, 24 h (padrão), Hoje, 7 dias ou 30 dias.
3. **Ler os blocos:** logins de gestores, atividade na janela, atividade ao
   longo do tempo, rotas mais acessadas e ajuda guiada. A leitura de cada um
   está no [Painel de administração](painel-de-administracao.md).
4. **Como saber que está funcionando:** com a plataforma em uso, **Eventos** e
   **Sessões ativas** sobem; a tela se atualiza sozinha a cada 30 segundos.

## O que é registrado

- **Sessão do visitante:** um identificador guardado num cookie do navegador,
  criado na primeira visita, sem exigir cadastro. Quando o gestor entra, a
  sessão passa a ser ligada à conta dele.
- **Interações:** navegação entre telas, buscas (só o **tamanho** do texto e o
  número de resultados), entrada e saída do gestor, erros e uso da ajuda
  guiada. Os tipos e campos aceitos são controlados por uma lista no servidor;
  um evento com algo fora do padrão é descartado inteiro.
- **IP e data da sessão:** guardados por pouco tempo. Para análises longas,
  o IP é trocado por um código (hash com chave diária) que não permite
  recuperá-lo.

## O que não é registrado

- O texto digitado em buscas, formulários ou no Assistente.
- O conteúdo das telas visitadas além do nome da rota.
- Um IP informado pelo próprio navegador: só vale o IP visto pelo servidor web
  da plataforma.

## Privacidade

- O painel mostra **apenas agregados**: nenhuma sessão, IP ou pessoa aparece
  individualmente.
- O IP é dado pessoal: o período curto de guarda e a troca por código fazem
  parte das medidas da plataforma. Veja [LGPD e PII](lgpd-e-pii.md).
- Não compartilhe capturas do painel fora da equipe que cuida da plataforma
  sem necessidade.

## Limitações conhecidas

- Visitante que apaga os cookies ou usa janela anônima conta como nova sessão.
- Bloqueadores de rastreamento no navegador podem impedir parte dos eventos.
- Os registros chegam em lotes: pode haver alguns segundos de atraso.

## Perguntas frequentes

- **Os números do painel caíram para zero de repente.** Confira a janela
  escolhida; se a plataforma ficou sem uso no período, o painel mostra
  *"Sem eventos registrados nesta janela"*.

## Veja também

- [Painel de administração](painel-de-administracao.md)
- [LGPD e PII](lgpd-e-pii.md)
- Ficha da funcionalidade: [Telemetria de sessão](../../funcionalidades/plataforma/telemetria-de-sessao.md)
