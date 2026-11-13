# Nota técnica 195: taxas de rendimento e distorção idade-série do INEP (#376)

Issue #376, parte do épico #368 (planos de gestão). O trabalho foi feito em
modo automático, com as decisões delegadas pelo developer (2026-11-13). Abaixo
estão a medição, as decisões e a carga.

## Medição da fonte (antes do código)

- **Páginas oficiais:** `gov.br/inep/.../indicadores-educacionais/taxas-de-
  rendimento-escolar` e `.../taxas-de-distorcao-idade-serie`. Elas não trazem
  os links no HTML, então as URLs foram achadas por HEAD:
  - `download.inep.gov.br/informacoes_estatisticas/indicadores_educacionais/<ano>/tx_rend_escolas_<ano>.zip`
    (~67–72 MB);
  - `…/<ano>/TDI_<ano>_ESCOLAS.zip` (~29–35 MB).
- **Anos encontrados:** 2019 e 2021–2025.
- **Formato:** cada zip traz um `.xlsx`, um `.ods` e o MD5, que bate com o
  arquivo. Na planilha:
  - 9 linhas de título;
  - a 10ª linha com os códigos das colunas (`NU_ANO_CENSO`, `CO_ENTIDADE`,
    `1_CAT_FUN…` para a aprovação, `2_` para a reprovação, `3_` para o
    abandono, `FUN_CAT_0…` para a distorção);
  - um rodapé "Fonte: …".
- **Grão:** uma linha por escola. Em 2025 são 126.684 escolas no rendimento e
  126.605 na distorção, sem duplicata. As taxas vêm em %, com uma casa, e `--`
  significa sem dado. A planilha traz ruído de ponto flutuante
  (`33.299999999999997`).
- **TLS:** o servidor manda só o certificado folha. O intermediário é o RNP
  ICPEdu GR46 OV TLS CA 2025, da GlobalSign Root R46, e foi obtido pela AIA.
  Sem ele a verificação falha (`certificate verify failed`); com ele e as
  raízes do sistema, passa. O intermediário fica versionado em
  `backend/lib/EduMaps/Ingestion/certs/` (válido até 2030-11-19). **A
  verificação de TLS não é desligada.**

## Decisões

1. **Licença.**
   - **Situação:** a licença do INEP segue não verificada. O e-SIC não foi
     protocolado (`docs/admin/esic-requests.md`).
   - **Precedente seguido:** o do Censo e do IDEB, já carregados — uso
     institucional interno, com a licença "Não verificada" no
     `import_metadata`.
   - **Por que o bloqueio não se aplica:** o stub `INEP` (microdados do
     Censo/IDEB/ENEM) continua bloqueado. As taxas por escola são agregadas e
     não têm dado pessoal, então não carregam o risco de LGPD que motivou o
     bloqueio dos microdados.
2. **Grão:** escola × ano × etapa, com as quatro etapas agregadas
   (fundamental total, anos iniciais, anos finais, ensino médio). As séries
   uma a uma ficam fora: são ruído para meta de plano. A etapa `fun` é
   guardada, mas não entra no catálogo (os planos seguem AI/AF/EM, como o
   IDEB).
3. **Duas tabelas em `clean`**, com GRANT ao `edumaps_leitor`, porque o dado
   é público e agregado.
   - **Rendimento:** as três medidas na mesma linha; pelo menos uma não nula.
   - **Distorção:** `distorcao NOT NULL`.
   - **Ausência:** `--` vira NULL, e a etapa sem nenhum valor não vira linha
     (#154).
4. **Catálogo das metas:** 12 códigos no grupo novo `fluxo`, na unidade `%`.
   - Aprovação sugere "aumentar"; reprovação, abandono e distorção sugerem
     "reduzir".
   - A view `analytics.escola_indicadores_meta` passa a ler as duas tabelas.
   - A tarefa diária `planos_oficiais` (#406) já leva os valores novos às
     metas dos planos vigentes.
5. **Anos padrão do job: 2023–2025.** São o suficiente para a linha de base e
   a tendência. O job aceita `anos=2019,2021-2025`.
6. **Leitura da planilha:** ela é extraída do zip e lida pelo `ogr2ogr`. O
   GDAL 3.6 do contêiner minion não abre o `.xlsx`, que já é um zip, por
   `/vsizip/` dentro de outro zip; o 3.10 do host abre. Achado na primeira
   carga real e corrigido com um teste.
7. **Sugestão de indicador:** "taxa" passa a ser palavra genérica, porque
   está em todos os rótulos de rendimento. Sem isso, "taxa de frequência"
   seria sugerida como taxa de aprovação.

## Carga real (ambiente local, 2026-11-13)

| Ano | Rendimento: escolas lidas | linhas | Distorção: escolas | linhas |
|---|---|---|---|---|
| 2023 | 128.370 | 309.896 | 128.237 | 312.838 |
| 2024 | 128.096 | 308.725 | 127.929 | 311.949 |
| 2025 | 126.684 | 306.550 | 126.605 | 308.345 |

- **Total:** 925.171 linhas de rendimento e 933.132 de distorção, em 172 s.
- **Sem multiplicação:** a chave (escola, ano, etapa) é a PK, e a view tem
  zero duplicatas por (escola, código, ano).
- **Escolas sem linha:** em 2023, 1.262 escolas tinham só `--` no rendimento
  e não viraram linha.
- **Conferência contra a planilha:** os valores da escola 11024372 em 2025
  batem.

## Testes

- **`t/05-tasks/inep_indicadores_loader.t`:**
  - amostra real de 2025 (4 escolas de cada arquivo, com título e rodapé);
  - parse, NULL/0 e uma casa decimal;
  - ano trocado, coluna faltando e escola repetida morrem alto;
  - carga em transação;
  - allowlist real e o bundle TLS;
  - extração do zip.
- **`t/04-api/gestor/planos_indicadores_fluxo.t`:** os 12 códigos no
  catálogo, o último valor por etapa, null quando falta, e a meta "reduzir o
  abandono" com a base sugerida e o histórico oficial.
- **Banco:** migration com deploy, verify e revert limitado por `--to` no
  banco de fixtures; `leitor_grants.t` verde.

## Deploy

- **LXC:** change `inep_rendimento_distorcao` (`deploy_db_dev`), backend e
  minion. Depois, rodar o job uma vez:
  `perl ingestion_runner.pl --job=INEPIndicadores`.
- **Rede:** o LXC precisa alcançar `download.inep.gov.br`. Em 2026-09-30 o
  handshake falhava deste ambiente; era a cadeia incompleta, agora resolvida
  pelo intermediário versionado.
