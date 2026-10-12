# Nota técnica 111 — E-mail e LGPD nas listas com QR (PR #215)

## Resumo

Fase 2 do roadmap das listas com QR (#214). Duas frentes:

1. **E-mail**: cada lista escolhe o que coleta (`telefone`, `email`, `ambos`,
   `qualquer`); o e-mail é confirmado por código enviado por e-mail, e a
   confirmação passa a ser **por contato**, com estado geral `parcial`.
2. **LGPD**: consentimento em versões imutáveis com hash gravado na inscrição;
   exclusão a pedido por link pessoal do titular e pelo gestor; retenção com
   expurgo automático configurável.

Entrega em 3 ondas com contratos congelados por onda e duas trilhas paralelas.
PR #215, merge `a09f3b5`.

## Decisões de design

- **Não destrutivo × direito de exclusão.** A regra das fases anteriores
  ("nunca descartar") continua valendo para dedupe e conflito. Exclusão a
  pedido e retenção são as **únicas** vias que removem PII, sempre auditadas em
  `canal_exclusoes`, que não guarda dado pessoal.
- **Anonimizar, não apagar.** O contato vira `[removido]` sem telefone/e-mail,
  sai de todas as listas da escola, e as inscrições ficam como esqueleto (data,
  lista, versão do consentimento, `anonimizado_em`). Reuniões e relações que
  apontam para o contato não quebram. A anonimização segue um **inventário de
  PII** explícito na spec, e um teste varre todas essas colunas procurando o
  nome, telefone e e-mail em claro.
- **Token de exclusão como capability sem validade**, 128 bits, só o sha256 no
  banco. Consequência aceita: o link não pode ser remontado depois (o e-mail de
  código não o inclui); ele é mostrado ao concluir a inscrição.
- **Consentimento auditável.** Versões publicadas são imutáveis; índice único
  parcial garante uma vigente; a inscrição grava versão + sha256 do texto. A
  página envia a versão que mostrou; desatualizada → 409 com o texto novo, e a
  pessoa aceita de novo. A versão 1.0 reproduz o texto antigo (é o que as
  inscrições anteriores aceitaram); a 1.1 cita e-mail.
- **Retenção conservadora.** Só anonimiza contatos criados pela própria
  autoinscrição; preserva quem confirmou algum contato, quem está em lista
  ativa sem exigência e quem tem inscrição recente. Linha de resumo por regra
  mesmo com zero, para a última execução ser visível. Prazo inválido usa o
  default (nunca "apagar tudo"). Execução avulsa vale mesmo com a diária
  desligada.
- **Contratos só acrescentam campos**; `consentimento_versao` opcional no POST
  (ausente → vigente) para compatibilidade.

## Validação

Backend 74 arquivos / 476 testes (6 pré-falhos idênticos no `main`), frontend
88 / 611, `sqitch verify` + revert/deploy, e2e CDP em dev com varredura de PII
no banco depois das exclusões. Pendente: envio real de e-mail (sem SMTP em dev).
