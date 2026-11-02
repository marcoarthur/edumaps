---
titulo: Acesso do gestor
modulo: gestor
status: ativo
audiencia: [gestor]
relacionadas: [painel, pesquisas]
---

# Acesso do gestor

> Módulo: `gestor` · Status: 🟢 ativo · Público: gestor

## Resumo

A plataforma oferece ao gestor um caminho direto para entrar ou se cadastrar e
assumir a gestão da sua escola, a partir da própria escola buscada.

## Para quem

Diretores, coordenadores e demais gestores escolares.

## O que o sistema permite

- Sistema pode cadastrar o gestor informando a escola e seus dados. O
  cadastro só cria contas: um e-mail que já tem conta (com maiúsculas ou não)
  não é recadastrado nem alterado por ali; a pessoa é orientada a entrar com a
  senha.
- Sistema pode autenticar o gestor e manter a sessão. A senha é guardada só
  como resumo calculado com um método propositalmente lento e resistente a
  adivinhação em massa (Argon2id); contas antigas passam a esse método no
  próximo acesso, sem precisar trocar a senha.
- Sistema pode levar o gestor direto ao painel da sua escola após entrar.

## Valor

Remove a barreira de entrada: encontrar a escola e começar a gerir em poucos
passos.

## Nota

Neste momento **não há validação de titularidade** (se quem se cadastra é de fato
o gestor); essa verificação é uma evolução prevista.

## Relacionadas

- [Painel do gestor](painel.md)
- [Pesquisas com a comunidade](pesquisas.md)
