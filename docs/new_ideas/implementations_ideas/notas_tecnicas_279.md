# Nota técnica 279: o painel financeiro sem a malha estrangeira (#591)

Achado de desempenho no modo autônomo autorizado pelo developer (até 25/11,
9h). Um PR: #592. Sem avaliação de persona.

## O problema

- `folha_cobertura`, chamado em todo painel financeiro, juntava as 232 mil
  linhas da folha com `raw.br_municipios_2024` para o nome dos municípios.
  A tabela é **estrangeira** (`Foreign Scan`): cada consulta relia o arquivo
  da malha. O painel levava 2,9 s; só essa junção, 2,5 s.
- A cobertura da folha de uma UF calculava o salário da rede (#571) de
  todos os municípios com folha (1,5 s).

## Decisões

- **Agregar antes e juntar com a malha local:** `clean.malha_municipio`
  tem o mesmo nome e UF; a cobertura cai para 0,2 s.
- **`salario_rede` com uma lista:** a cobertura passa os municípios dela.
- **O fallback** de `_cod_municipio_escola` (escola fora do Censo) fica na
  tabela estrangeira: é raro e não está no caminho de toda chamada.
- **Lição para a próxima consulta:** `raw.*` pode ser tabela estrangeira;
  conferir com `EXPLAIN` antes de pôr num caminho quente.

## Validação

- **Tempos locais:** painel financeiro de 2,9 s para 0,3 s; catálogo da
  tela da base (MT) de 4,7 s para 3,7 s (o resto é a contagem e a
  cobertura com os meses; fica para outra rodada, se incomodar).
- **Testes:** Perl, 211 arquivos. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev`.
- O catálogo da base em 3,7 s.
