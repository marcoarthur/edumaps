# Nota técnica 231: folha contada pela pessoa, por ano e na base de análise (#491)

Achados RJ-01, RJ-02 e RJ-03 da décima nona avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-18-p4-folha.md`).
Um PR: #492 (merge `29949a1`).

## O problema

- **RJ-01 (atrapalha).** O painel financeiro e a folha detalhada contavam
  os profissionais com `COUNT(DISTINCT cpf)`.
  - O SIOPE publica o CPF mascarado (`xxx.NNN.NNN-xx`). Dos seis dígitos,
    o último é a região fiscal, quase sempre a mesma no município (Cuiabá:
    12.546 de 13.547 com o dígito 1). Sobram cerca de 100 mil combinações.
  - Resultado: Cuiabá 2025 tinha 10.120 em vez de 10.557 (−4,1%), e Alta
    Floresta D'Oeste 2024, −11,4%. 125 das 234 escolas com folha ficavam
    com menos profissionais.
  - O perfil da cidade (`City::Profile`) já contava por nome e CPF.
- **RJ-02 (atrapalha).** "Custo total (período)" e o custo por categoria
  somavam todos os meses carregados. Na EMEB 51037343 eram 14 meses (2025 e
  jan–fev/2026), com o 13º no meio e sem o período escrito.
- **RJ-03 (atrapalha).** A folha não saía para várias escolas. "Salário
  docente × IDEB" só se respondia por SQL (r = 0,23 em 50 escolas de
  Cuiabá).

## Decisões

- **A pessoa é `(cpf, nome_profissional)`** (`$PESSOA` em
  `Roles/Business/School/Finance.pm`), nas seis contagens. Grafias
  diferentes do mesmo nome contariam duas vezes. Em Cuiabá 2025, porém,
  `DISTINCT (cpf, nome)` dá 10.557 e `DISTINCT nome` dá 10.535: a chave
  composta erra muito menos que o CPF sozinho.
- **O painel é de um ano.** `financial_summary` recebe `ano`, calcula os
  anos com folha da origem (escola ou Secretaria) e filtra a série, as
  categorias e o total de profissionais.
  - Sem o ano, vale o mais recente: o gestor quer o ano corrente, e o
    cartão diz "jan a fev (2 meses)".
  - Ano sem folha → 400, com a lista `anos`.
  - `periodo` = primeiro e último mês e quantos meses; o frontend escreve
    (`periodoTexto`).
  - A rota não passa pelo cache.
- **O bloco `remuneracao` da base de análise** (`$SQL_FOLHA` em
  `EduMaps::BaseAnalise`) agrega primeiro por pessoa e mês e depois por
  escola, porque a mesma pessoa pode ter dois vínculos na escola no mesmo
  mês. Os salários e as cargas desses vínculos se somam.
  - **Magistério:** `tipo = 'Profissionais do magistério'`.
  - **Médias sem dezembro**, por causa do 13º. O gasto do ano inclui
    dezembro.
  - **Salário para 40 horas:** média de `s / ch × 40` nos meses com carga
    maior que zero.
  - **Valores em reais inteiros:** o CSV escreve números não inteiros com 6
    dígitos significativos, e um gasto de 8 milhões sairia em notação
    científica. A carga horária tem uma casa.
  - **O mês é texto, com um caso de latin1 ("Março"):** as três primeiras
    letras bastam para contar os meses e tirar dezembro.
  - **O agregado da Secretaria (99999999) fica fora:** não é escola.
- **O ano padrão da base é o último completo**: o ano com 12 meses em algum
  município, senão o mais recente (`anos_siope`).
  - Na base local, 2025, porque 2026 só tem dois meses.
  - O ano vai em `ano_siope`, no nome do arquivo (`-siope2025`) e no
    dicionário.
- **Sem nomes nem CPF na base.** A folha nominal já é pública por decisão do
  developer (2026-11-09), mas a base é para análise e não precisa deles.
- **Ponto e vírgula fora das descrições** do dicionário: o CSV usa `;`, e o
  teste lê o arquivo sem parser de aspas.

## Validação

- Suíte Perl inteira com `-j4`: 199 arquivos e 1.757 testes, todos
  passando. vitest: 1.354 testes, todos passando.
- Local, depois do rebuild:
  - a EMEB 51037343 abre em 2026 (jan a fev, 81 profissionais);
  - em 2025, mostra 12 meses e 127 profissionais;
  - a base de Cuiabá, rede municipal, sai como
    `…-censo2025-siope2025.csv`, com 167 de 171 escolas com folha;
  - a EMEB tem 89 profissionais do magistério, R$ 6.949, R$ 11.922 para 40
    horas e R$ 7.955.641 no ano, igual à soma dos 12 meses do painel.
- CI do PR verde.

## Pendências

- A cobertura do SIOPE (quatro municípios locais) depende de carga. Não há
  como a pesquisadora pedir um município novo; o gestor da escola pode,
  pelo painel.
