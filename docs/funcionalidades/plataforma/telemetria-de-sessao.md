---
titulo: Telemetria de sessão
modulo: plataforma
status: ativo
audiencia: [gestor, admin]
relacionadas: [privacidade-lgpd, observabilidade]
---

# Telemetria de sessão

> Módulo: `plataforma` · Status: 🟢 ativo · Público: gestor, admin

## Resumo

A plataforma pode reconhecer cada visitante (anônimo ou gestor logado) numa
sessão de navegação — sem depender de cadastro — para registrar, de forma
agregada e privada, o ritmo de uso: quando o visitante chega, quantas
interações faz e com quais áreas da plataforma. Isso alimenta decisões de
produto (o que é usado, o que não é) sem vigiar o conteúdo do que cada pessoa
faz.

## Para quem

Quem pensa o produto (gestão da plataforma e administração da instalação) e
precisa de evidências quantitativas de uso para priorizar melhorias.

## O que o sistema permite

- Sistema pode identificar o visitante na primeira visita e reconhecê-lo nas
  visitas seguintes, em navegador (cookie de sessão) — sem exigir login.
- Sistema pode registrar cada interação com as áreas da plataforma num
  repositório central, em lotes (nunca um registro por clique), preservando o
  ritmo de resposta.
- Sistema pode distinguir visitante anônimo de gestor logado, ligando a mesma
  sessão à identidade do gestor quando ele entra.
- Sistema pode registrar o IP e a data de cada sessão por um período curto de
  retenção, e anonimizar o IP (hash com chave diária) para análises de longo
  prazo — sem nunca gravar o texto digitado pelo visitante.
- Sistema pode registrar eventos de interesse vindos do navegador
  (navegação entre telas, buscas — contagem, não o texto —, login/logout de
  gestor e erros de API), com tipos e campos autorizados por uma lista
  controlada no servidor.

## Nota de status

A telemetria está **ativa nas duas pontas**. No servidor, a sessão do visitante
é identificada por cookie nos requests de API e as interações são persistidas
em lotes. No navegador, um rastreador envia — também em lotes — os eventos de
navegação entre telas, buscas (só a contagem de caracteres e o total de
resultados, nunca o texto digitado), login/logout de gestor e erros de API.
Os tipos e campos aceitos são controlados por uma lista no servidor; o IP cru
fica só na dimensão de sessão, com anonimização por hash diário para análises
de longo prazo. Detalhes de implementação e limites de privacidade em
`docs/new_ideas/...` (notas técnicas dos ciclos).

## Valor

Entender o uso real da plataforma — frequência de visitas, áreas mais e menos
acessadas, adesão de gestores — para priorizar o que importa às escolas e
redes, com respeito à privacidade (sem texto digitado, sem IP cru de longo
prazo).

## Relacionadas

- [Privacidade e LGPD](privacidade-lgpd.md)
- [Observabilidade de erros](observabilidade.md)