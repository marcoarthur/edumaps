---
titulo: "Folha de pagamento por escola"
publico: [gestor]
modulo: gestor
nivel: intermediario
status: ativo
relacionadas: [financeiro-e-folha, painel-da-escola]
funcionalidade: ../../funcionalidades/analise/folha-pagamento.md
ultima_revisao: 2026-11-24
---

# Folha de pagamento por escola

> **Para quem:** Gestor que quer conhecer o quadro de profissionais pagos com recursos da educação  
> **Tempo de leitura:** ~4 min

## Em 30 segundos

Quando o município informa ao **SIOPE** a remuneração por escola, o EduMaps
mostra a **folha detalhada** da unidade: cada profissional, categoria, carga
horária, situação e salários do mês escolhido. Quando o município informa a
folha no total da Secretaria, sem escola, a folha detalhada do total da
Secretaria lista essas pessoas, com o aviso de que o SIOPE não diz em que
unidade cada uma trabalha e de que pode haver pagamentos parciais. Ela abre
pelo painel da Secretaria ("Ver folha completa") e, quando o município tem
gente só no total da Secretaria, pelo painel da escola ("Ver a folha do
total da Secretaria"). Listas grandes têm busca pelo nome e páginas de 100.

## Passo a passo

1. **Onde ir:** no **Painel financeiro** da escola, escolha o mês em **Ver
   folha completa (detalhes)** e clique em **Ver folha completa →**.
2. **Se o botão estiver desabilitado:** o município não detalha a folha por
   escola (ver *Limitações*).
3. **O que ver:** a tabela **Folha de Pagamento – Profissionais da Educação**,
   com **Profissional, Categoria, Carga Horária, Situação, Salário Base,
   Salário Total, Mês e Ano**. Clique no título de uma coluna para ordenar.
4. **Como saber que deu certo:** o título mostra *"N profissional(is)
   listado(s)"*.

## Entendendo os números

- **Salário Base** é o vencimento; **Salário Total** inclui os demais valores
  pagos no mês.
- **Categoria** e **Situação** vêm como o município declarou ao SIOPE.
- Um valor vazio aparece como **—**: não informado, nunca zero.
- **Profissionais** são contados pela pessoa (CPF mascarado e nome), como no
  Painel financeiro.
- O mês exibido é o escolhido no Painel financeiro; meses diferentes podem ter
  quadros diferentes (contratações, afastamentos).

## Limitações conhecidas

- **Município sem detalhamento por escola:** em muitos municípios o SIOPE
  registra a folha só na Secretaria. Nesse caso o Painel financeiro avisa
  *"Painel da rede municipal — não desta escola"* e os números são o total da
  rede; a folha detalhada do total da Secretaria existe, mas não é possível
  saber quem atua nesta unidade.
- Os dados chegam com o atraso de publicação do SIOPE.
- Profissionais pagos por outras fontes (fora dos recursos declarados ao
  SIOPE) não aparecem.
- **Nome com "?":** em alguns municípios, o arquivo do SIOPE traz os nomes
  com os acentos quebrados. A plataforma corrige esses nomes. Quando a letra
  já veio perdida, ela é recuperada de outro mês do mesmo profissional, e o
  que não volta aparece como "?" (ex.: "PE?ANHA"). A tela avisa quando
  algum nome está assim. Em Cuiabá, isso ficou em 26 profissionais da
  folha de 2025.

## Privacidade

A folha detalhada traz **nomes e salários** de pessoas. São dados que o
município publica no SIOPE por obrigação de transparência, e o EduMaps os
reproduz como estão. Mesmo assim:

- use-os para planejamento de pessoal, não para expor pessoas;
- não copie a tabela para planilhas ou mensagens fora do ambiente de trabalho;
- o CPF não é exibido.

## Perguntas frequentes

- **Um profissional da escola não está na lista.** Ele pode ser pago por outra
  fonte, estar lotado em outra unidade no SIOPE, ou o mês escolhido pode ser
  anterior à sua entrada.
- **Aparece "Não há folha de pagamento desta escola para este mês".**
  Não há folha detalhada da escola no período. O link para o Painel
  financeiro leva à explicação do motivo e à lista de municípios com folha.

## Veja também

- [Financeiro e Folha (SIOPE)](financeiro-e-folha.md)
- [Glossário](../_glossario.md)
- Ficha da funcionalidade: [Folha de pagamento](../../funcionalidades/analise/folha-pagamento.md)
