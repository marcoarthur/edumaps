# help-wiki

Valida `docs/ajuda/` e gera o site de ajuda publicado no GitHub Pages
(<https://marcoarthur.github.io/edumaps/>). Local, fora do deploy.

## Uso

```bash
python3 tools/help-wiki/export.py       # valida (sai com 1 se houver erro)
python3 tools/help-wiki/build_pages.py  # gera o site em _site/ (ignorado pelo git)
```

Dependências: `pip install markdown pyyaml`.

## O que o validador confere (`export.py`)

- front-matter obrigatório e enums (`publico/modulo/nivel/status`);
- `funcionalidade` aponta para uma ficha que existe;
- `status: parcial` tem a seção "Limitações conhecidas";
- **links relativos quebrados**, na ajuda e nas fichas de `docs/funcionalidades/`
  (as duas vão para o site);
- **páginas órfãs**: toda página de um perfil aparece no `README.md` do perfil;
- cobertura (informativa): fichas `ativo` sem página de ajuda.

## O site (`build_pages.py`)

O site repete a estrutura de `docs/`, para que os links relativos funcionem
sem reescrita:

| No repositório | No site |
|---|---|
| `docs/ajuda/gestor/x.md` | `/ajuda/gestor/x.html` |
| `docs/funcionalidades/analise/y.md` | `/funcionalidades/analise/y.html` |
| qualquer outro caminho do repo | link para o arquivo no GitHub |

- O título da página vem do `titulo` do front-matter.
- `README.md` de cada pasta vira também o `index.html` dela.
- A raiz do site e os endereços antigos (ajuda na raiz, até 2026-11) redirecionam
  para `/ajuda/`.

## CI

`.github/workflows/docs-pages.yml`: em PR que toque `docs/ajuda/`,
`docs/funcionalidades/` ou `tools/help-wiki/`, roda a validação e o build
(sem publicar). No push em `main`, valida, gera e publica.
