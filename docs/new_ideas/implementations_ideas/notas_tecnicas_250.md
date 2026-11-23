# Nota técnica 250: CEP, bairro e endereço na base (#531)

Achado QR-01 da segunda avaliação da P3
(`docs/personas/publicos/avaliacoes/2026-11-23-p3-concorrentes-locais.md`).
A issue foi aberta com a aprovação do developer; o plano (opções A e A) foi
aprovado e a implementação seguiu sozinha durante a noite. Um PR: #532
(merge `f03656e`).

## O problema

- **QR-01 (atrapalha).** A base só localizava a escola pela latitude e
  longitude, que faltam em 23,3% das privadas de SP (6,9% das municipais e
  1,1% das estaduais). Em Franca, faltam em 16 das 136 privadas, entre elas
  as duas bilíngues.
- O Censo traz o CEP, o bairro e o endereço de todas as escolas, mas a base
  não os entregava. O mantenedor que quer os concorrentes do bairro ficava
  sem a escola.

## Decisões

- **CEP formatado (`00000-000`).** Com o hífen, o Excel abre o CEP como
  texto e não perde o zero do começo. Fica vazio se o Censo não trouxer
  oito dígitos.
- **Endereço incluído.** `endereco` é "logradouro, número", e o número
  entra só se tiver algum dígito diferente de zero, então "S/N" e "0" caem.
  `bairro` sai sem espaços sobrando e vazio quando o Censo traz vazio.
- **Posição:** as três colunas vão no fim da identificação, depois da
  longitude, sem mexer na posição das colunas antigas.
- **Dicionário:** latitude e longitude dizem a cobertura por rede no Brasil
  (cerca de 1 em cada 3 privadas sem coordenada, 16% das municipais e 12%
  das estaduais) e mandam usar o CEP, o bairro e o endereço quando a
  coordenada falta.
- **Ajuda:** nova seção "Escolas próximas", com o código R (haversine sobre
  a base) e o que fazer com as escolas sem coordenada.

## Validação

- **O bloco R da ajuda** rodou na base de Franca: 60 escolas a até 2 km da
  unidade de referência (37 com pré-escola ou anos iniciais), 18 sem
  coordenada (16 privadas) e 1 no mesmo bairro (Cidade Nova).
- **Tela:** a página da base mostra a identificação com 13 colunas e o
  texto novo.
- **Docker local, depois do merge:** imagens `backend`, `minion` e
  `minion-analytics` reconstruídas; o md5 do `BaseAnalise.pm` bate com o
  `main`.
- **Testes:** Perl (cabeçalho, CEP formatado, CEP inválido vazio, "S/N"
  fora do endereço, dicionário); CI do PR verde (Perl e build; R e vitest
  não rodam sem mudança nessas áreas).

## Pendências

- No LXC: `deploy_backend_dev` (sem change nova).
- AN-10 (#429, mercado local) segue aberto: o endereço ajuda a achar os
  concorrentes, mas não diz nada sobre preço ou procura.
