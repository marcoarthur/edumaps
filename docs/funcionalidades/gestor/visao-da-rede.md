---
titulo: Visão da rede (secretaria)
modulo: gestor
status: parcial
audiencia: [gestor, administrador]
relacionadas: [planos-gestao, painel]
---

# Visão da rede (secretaria)

> Módulo: `gestor` · Status: 🟡 parcial · Público: secretaria municipal ou estadual, administrador

## Resumo

A secretaria acompanha as escolas da sua rede numa conta própria, separada da
conta de escola. O administrador da plataforma cria a conta, envia um convite e
liga a conta às redes (municipal ou estadual, por município). A conta de rede
só lê: não altera nada do que a escola cadastra.

## O que o sistema permite

- **Conta de rede por convite:** o administrador cria a conta (nome, e-mail,
  cargo) e copia um link de convite que vale uma vez, por 7 dias. A pessoa
  define a própria senha por esse link; ninguém mais a conhece. Um convite
  novo invalida o anterior.
- **Redes por município:** cada conta pode ter uma ou mais redes, cada uma uma
  dependência (municipal ou estadual) e um município. Uma diretoria regional
  vira várias redes, uma por município.
- **Escolas da rede pelo Censo mais recente:** a escola entra na rede pela
  situação mais recente dela no Censo Escolar (dependência e município). Uma
  escola municipalizada ou estadualizada muda de rede junto.
- **Acesso conferido a cada pedido:** revogar uma rede tira o acesso na hora.
  A conta de rede não entra nas telas da escola, e a conta de escola não entra
  nas da rede.
- **Histórico:** criar a conta, gerar convite, definir a senha, conceder e
  revogar redes ficam registrados, com quem fez e quando.
- **Painel da rede:** cada escola com o plano de gestão vigente, o andamento
  das metas ("N de M medidas"; sem medida não é 0%), as ações atrasadas e as
  que vencem em 7 dias, e as evidências; totais da rede, filtros (sem plano,
  com atrasadas, sem andamento) e ordenação para achar quem precisa de apoio.
- **Relatório de cada escola:** o mesmo relatório de acompanhamento que a
  escola imprime, aberto pela rede só para leitura, com o cargo de quem o
  emitiu.

- **Metas comparáveis:** as metas que seguem o mesmo indicador oficial
  aparecem juntas, com quantas escolas têm a meta, quantas mediram, o
  andamento médio e a lista das escolas (base ajustada pela escola marcada).
  Metas manuais ficam à parte. Na escola, a tela sugere o indicador oficial
  quando a descrição de uma meta manual lembra um deles.

## Ainda não disponível

- Custo previsto e executado por fonte de recurso na rede (#398).

## Valor

É o primeiro passo do que o plano de negócios chama de alvo principal: a
secretaria governando com evidência, sem pedir uma planilha a cada escola.

## Relacionadas

- [Planos de gestão acompanháveis](planos-gestao.md)
- [Painel do gestor](painel.md)
