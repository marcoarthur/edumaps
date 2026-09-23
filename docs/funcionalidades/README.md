# Catálogo de Funcionalidades — EduMaps

> Ponto central da **documentação funcional** do EduMaps. Lista, em alto nível, o
> que a plataforma possibilita — **sem** rotas, arquivos ou funções. É a fonte
> para sínteses (PDF, wiki, apresentações) e para entender rapidamente o produto.
>
> **Manutenção**: sempre que uma funcionalidade **mudar** ou uma **nova** for
> criada, atualize o arquivo da capacidade em `docs/funcionalidades/<módulo>/` e
> este índice. Ver o passo "Documentação funcional" no `AGENTS.md`.

## Como usar

- Cada **capacidade** é um arquivo markdown curto com front-matter YAML
  (`titulo`, `modulo`, `status`, `audiencia`, `relacionadas`).
- O **status** indica o momento no roadmap: 🟢 ativo · 🟡 parcial ·
  ⚪ planejado · 🔴 descontinuado.
- Para sintetizar (ex.: gerar um PDF ou alimentar uma wiki), use o front-matter
  e a tabela abaixo; o corpo de cada arquivo traz resumo, público, o que o
  sistema permite e valor.
- Novo documento: copie `_template.md`.

## Módulos

| Módulo | O que reúne |
|--------|-------------|
| **busca** | Encontrar escolas, similares, análises e pessoas. |
| **analise** | Leitura analítica: raio-x, ranking, clusters, rede, finanças, folha. |
| **gestor** | Gestão escolar: acesso, painel, pesquisas, reuniões, contatos, inventário, relações. |
| **comunidade** | Participação da comunidade (resposta pública). |
| **plataforma** | Fontes de dados e privacidade que sustentam tudo. |

## Índice de capacidades

### busca
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Busca de escolas](busca/escolas.md) | Encontrar escolas por nome/município, com contato, mapa e atalhos de acesso. | 🟢 |
| [Escolas similares](busca/similaridade.md) | Identificar escolas semelhantes para comparação e troca de experiências. | 🟢 |
| [Busca de análises](busca/analises.md) | Explorar as análises disponíveis por tema, recorte e indicador. | ⚪ |
| [Busca de pessoas](busca/pessoas.md) | Localizar profissionais da educação por escola, função e rede. | ⚪ |

### analise
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Painel da escola](analise/painel-escola.md) | Raio-x da escola: matrículas, docentes, infraestrutura, desempenho e similares. | 🟢 |
| [Ranking de escolas](analise/ranking.md) | Posicionar a escola por indicadores no município e no estado. | 🟢 |
| [Clusters de escolas](analise/clusters.md) | Agrupar escolas por características e geografia. | 🟢 |
| [Comparação de redes](analise/rede-municipal.md) | Comparar as redes (federal, estadual, municipal, privada) de um município. | 🟢 |
| [Painel financeiro](analise/financeiro.md) | Acompanhar recursos e gastos da educação. | 🟢 |
| [Folha de pagamento](analise/folha-pagamento.md) | Ler a remuneração e o perfil dos profissionais. | 🟢 |
| [Assistente do Censo](analise/assistente-censo.md) | Perguntar em linguagem natural e receber números do Censo no escopo da escola. | 🟢 |

### gestor
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Acesso do gestor](gestor/acesso.md) | Entrar ou se cadastrar para gerir a escola. | 🟢 |
| [Painel do gestor](gestor/painel.md) | Central de gestão com o raio-x da escola e os módulos. | 🟢 |
| [Pesquisas com a comunidade](gestor/pesquisas.md) | Ouvir a comunidade e ler os resultados agregados. | 🟢 |
| [Reuniões e atas](gestor/reunioes-atas.md) | Agendar reuniões, gerar convite, registrar ata e anexos. | 🟢 |
| [Contatos e grupos](gestor/contatos-grupos.md) | Organizar a agenda de contatos da escola. | 🟢 |
| [Inventário escolar](gestor/inventario.md) | Inventariar recursos e serviços, partindo do Censo. | 🟢 |
| [Relações institucionais](gestor/relacoes-institucionais.md) | Gerir as relações com entidades externas e suas demandas. | 🟢 |

### comunidade
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Resposta de pesquisa](comunidade/resposta-pesquisa.md) | A comunidade responde à pesquisa por link público. | 🟢 |

### plataforma
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Fontes de dados](plataforma/fontes-de-dados.md) | Censo Escolar, IDEB/SAEB, SIOPE e IBGE sustentam os indicadores. | 🟢 |
| [Privacidade e LGPD](plataforma/privacidade-lgpd.md) | Tratamento de dados pessoais e princípios de privacidade. | 🟢 |
