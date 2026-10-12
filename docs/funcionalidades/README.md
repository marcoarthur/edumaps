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
| [Perfil analítico da escola](analise/perfil-escola.md) | Diagnóstico, posição relativa (município/rede/Brasil), benchmarking justo e sinais de atenção. | 🟢 |
| [Ranking de escolas](analise/ranking.md) | Posicionar a escola por indicadores no município e no estado. | 🟢 |
| [Clusters de escolas](analise/clusters.md) | Agrupar escolas por características e geografia. | 🟢 |
| [Comparação de redes](analise/rede-municipal.md) | Comparar as redes (federal, estadual, municipal, privada) de um município. | 🟢 |
| [Painel financeiro](analise/financeiro.md) | Acompanhar recursos e gastos da educação. | 🟢 |
| [Folha de pagamento](analise/folha-pagamento.md) | Ler a remuneração e o perfil dos profissionais. | 🟢 |
| [Assistente do Censo](analise/assistente-censo.md) | Perguntar em linguagem natural e receber números do Censo no escopo da escola. | 🟢 |
| [Histórico de conversas](analise/historico-conversas.md) | Guardar as conversas com o assistente, reencontrá-las por texto ou data e exportá-las em Markdown. | 🟡 |
| [Relatórios do território](analise/relatorios-territorio.md) | Escolher escola, município, estado ou região e um tema, e receber um relatório com números, tabelas, gráficos e texto explicativo; inclui análises aprofundadas (escola a escola, infraestrutura × IDEB, histórico e escolas parecidas). | 🟡 |

### gestor
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Acesso do gestor](gestor/acesso.md) | Entrar ou se cadastrar para gerir a escola. | 🟢 |
| [Painel do gestor](gestor/painel.md) | Central de gestão com o raio-x da escola e os módulos. | 🟢 |
| [Pesquisas com a comunidade](gestor/pesquisas.md) | Ouvir a comunidade e ler os resultados agregados. | 🟢 |
| [Reuniões e atas](gestor/reunioes-atas.md) | Agendar reuniões, gerar convite, registrar ata e anexos. | 🟢 |
| [Contatos e grupos](gestor/contatos-grupos.md) | Organizar a agenda de contatos da escola. | 🟢 |
| [Listas com autoinscrição por QR](gestor/listas-autoinscricao.md) | Publicar uma lista por QR code para a comunidade se inscrever, evitando duplicatas, coletando telefone e/ou e-mail, com confirmação opcional dos contatos, exclusão a pedido, listas dinâmicas (recortes salvos) e funil de conversão (acessos → inscrições → confirmações). | 🟢 |
| [Envios por e-mail para listas](gestor/envios-email.md) | Escrever um e-mail e enviá-lo a uma lista ou lista dinâmica, na hora ou agendado: prévia, teste para si, fila com ritmo e cota, link de saída por lista e resultado de cada envio, sem rastreio de abertura. | 🟢 |
| [Inventário escolar](gestor/inventario.md) | Inventariar recursos e serviços, partindo do Censo. | 🟢 |
| [Relações institucionais](gestor/relacoes-institucionais.md) | Gerir as relações com entidades externas e suas demandas. | 🟢 |
| [Documentos e planos escolares](gestor/documentos-planos.md) | Guardar os documentos e planos da escola em pastas, com versões, tags e histórico. | 🟢 |
| [Equipamentos no entorno](gestor/equipamentos-entorno.md) | Ver no mapa (e atualizar) os equipamentos públicos ao redor da escola. | 🟢 |

### comunidade
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Resposta de pesquisa](comunidade/resposta-pesquisa.md) | A comunidade responde à pesquisa por link público. | 🟢 |

### plataforma
| Capacidade | Resumo | Status |
|------------|--------|--------|
| [Fontes de dados](plataforma/fontes-de-dados.md) | Bases públicas em uso e catálogo curado de fontes candidatas, com prioridade avaliada e justificativa registrada. | 🟢 |
| [Privacidade e LGPD](plataforma/privacidade-lgpd.md) | Tratamento de dados pessoais: termo de consentimento versionado, exclusão a pedido pelo titular (inclusive do histórico de envios), saída das comunicações por lista em um clique, sem rastreio de e-mails, e retenção com expurgo automático. | 🟢 |
| [Canais de comunicação](plataforma/canais-de-comunicacao.md) | Alcançar a comunidade por e-mail, WhatsApp e Telegram, validando endereços, confirmando posse (Telegram e WhatsApp nas listas por QR), enviando e-mail em massa em fila com ritmo e cota, limites e suspensão pela administração, e registrando o histórico e o resultado de cada envio. | 🟡 |
| [Telemetria de sessão](plataforma/telemetria-de-sessao.md) | Reconhecer o visitante por sessão e registrar uso da plataforma em lotes, de forma agregada e privada — do servidor e do navegador (navegação, buscas, login/logout, erros), sem texto digitado. | 🟢 |
| [Painel de Administração](plataforma/painel-administracao.md) | Acompanhar, em tempo quase real, logins de gestores (6/12/24 h), sessões ativas (logadas/anônimas), rotas mais acessadas, buscas e atividade ao longo do tempo — só agregados. | 🟢 |
| [Painel de Configuração](plataforma/painel-configuracao.md) | Categorias e grupos de configurações globais da instalação; hoje as Integrações (Assistente do Censo e Bot Telegram) e os Canais de comunicação (e-mail, WhatsApp, bot público do Telegram, autoinscrição, consentimento, retenção e limites de envio, com painel de volume e suspensão por escola). | 🟡 |
| [Bot Telegram](plataforma/bot-telegram.md) | Enviar notificações e alertas por Telegram — teste manual, envio automático em eventos de ingestão (sucesso, falha, stall) e categoria de envio p/ eventos do sistema por severidade (ex.: login de gestor) — com ações autorizadas configuradas pela administração. | 🟡 |
| [Observabilidade de erros](plataforma/observabilidade.md) | Registro central de falhas (API 5xx, jobs e erros de navegador) com dados pessoais redigidos. | 🟡 |
