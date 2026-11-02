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
- Sistema pode deixar o gestor criar uma senha nova quando esquece a atual,
  por um link enviado ao e-mail da conta: o link vale por pouco tempo e uma
  vez só, a tela não revela se o e-mail tem conta, e a troca encerra o acesso
  em todos os aparelhos. Depende do envio de e-mail da plataforma estar
  configurado.
- Sistema pode frear tentativas repetidas de adivinhar senhas: depois de
  várias senhas erradas para o mesmo e-mail, ou de muitas tentativas vindas da
  mesma rede, o acesso fica suspenso por alguns minutos e a tela diz quanto
  esperar. A resposta é a mesma exista ou não uma conta com aquele e-mail, e
  o registro das tentativas não guarda e-mail nem endereço de rede legíveis.
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
