# Nota técnica 163 — site de ajuda: fichas publicadas, links validados e ajuda do gestor (#304)

PR #332 (merge `abc4640`, 2026-11-02). Só documentação, ferramenta e CI: sem
deploy de aplicação; o GitHub Pages publica no merge
(<https://marcoarthur.github.io/edumaps/>).

## Ponto de partida

A epic #304 parecia aberta, mas a maior parte já existia: 34 páginas em
`docs/ajuda/`, validador de front-matter e publicação no Pages desde
2026-10-26. O que faltava não aparecia na checklist da issue:

- os links da ajuda para as fichas (`../../funcionalidades/...`) davam **404**
  no site, porque só `docs/ajuda/` era publicado;
- o validador não olhava links: havia **15 quebrados** (o mais comum,
  `_glossario.md` sem `../` em páginas de subpasta);
- os índices de perfil diziam "em construção" e não listavam nada;
- títulos das páginas vinham do nome do arquivo ("Historico Do Assistente");
- 16 funcionalidades ativas sem página de ajuda, e 3 páginas apontando para
  a ficha errada (a "lista com QR" descrevia pesquisa, não autoinscrição).

## Decisões

- **Publicar as fichas no mesmo site** (escolha do developer), em vez de
  apontar para o GitHub. O site passou a **espelhar `docs/`**
  (`/ajuda/...`, `/funcionalidades/...`): assim os links relativos funcionam
  sem reescrita, e o que é válido no repositório é válido no site. Os links
  para qualquer outro caminho do repo viram links do GitHub. Endereços antigos
  (ajuda na raiz) ganharam páginas de redirecionamento.
- **Wiki alvo = GitHub Pages**: a decisão pendente da epic já tinha sido
  tomada na prática; registrada aqui.
- **Uma só resposta para "para onde aponta este link"**: `tools/help-wiki/links.py`
  é usado pelo validador e pelo gerador, para que os dois não divirjam.
- **Página órfã é erro**: toda página de um perfil precisa estar no `README.md`
  do perfil. Sem isso, o índice volta a apodrecer em silêncio.
- **CI em PR, publicação só em `main`**: o mesmo workflow valida e gera em
  PR (sem `configure-pages`/`deploy`), e publica no push.
- **Escopo do conteúdo**: as 11 lacunas do gestor neste ciclo; análise e
  telemetria (6) ficam para o próximo.

## O CI pegou o que o validador local deixava passar

`desenvolvedor/visao-geral.md` tinha links `/home/itaipu/.../AGENTS.md`:
existem na máquina de quem escreveu, então a validação local passava, e
quebravam no CI e no site. O validador passou a recusar caminho absoluto.

## Fichas corrigidas pela verificação contra a tela

As páginas foram escritas conferindo cada rótulo no código do frontend. Isso
expôs fichas que prometiam mais que a tela: busca por tag (não existe),
"prazos" no inventário (não há campo), a pausa da cota de e-mail (na verdade
o envio que não cabe é recusado antes; a pausa só ocorre no meio), leituras
por raio da área de influência (só população e densidade), e a completude da
malha viária, calculada mas não exibida (ficha → 🟡 parcial).

## Achados fora do escopo

- 🔴 **Segurança**: achado no cadastro do gestor, reportado ao developer;
  correção em ciclo próprio.
- #154 na tela: "0 (0%)" em resultados de pesquisa sem resposta; faixa etária
  sem dado vira 0 no gráfico do painel do gestor.
- Pesquisa publicada não pode ser encerrada; documentos sem caminho de volta à
  raiz; ✕ de anexo do inventário apaga sem confirmar.

## Pendências

- Páginas de ajuda: clusters, folha de pagamento, perfil da escola, rede
  municipal, similaridade, telemetria de sessão.
- Decisões da epic ainda abertas: perfil professor (segue `planejado`),
  alcance de "comunidade".
- Corrigir o achado de segurança no cadastro do gestor.
