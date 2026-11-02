---
titulo: "Ver os equipamentos públicos no entorno da escola"
publico: [gestor]
modulo: gestor
nivel: basico
status: parcial
relacionadas: [area-de-influencia, ivet, painel-da-escola]
funcionalidade: ../../funcionalidades/gestor/equipamentos-entorno.md
ultima_revisao: 2026-11-02
---

# Ver os equipamentos públicos no entorno da escola

> **Para quem:** gestor que quer saber o que existe ao redor da escola (ônibus, saúde, cultura, segurança…).
> **Tempo de leitura:** ~3 min

## Em 30 segundos

No painel do gestor, você escolhe que tipos de equipamento procurar e a que
distância da escola. O sistema busca esses pontos no OpenStreetMap (um mapa
público e colaborativo), desenha tudo num mapa e conta quantos há de cada tipo.

## Passo a passo

1. **Onde ir:** menu **Gestor** → **Ir para o painel** → atalho
   **Equipamentos (OSM)**, ou desça até a seção **Equipamentos no entorno
   (OSM)**. É preciso estar conectado como gestor desta escola; caso contrário,
   a seção pede que você entre.
2. **Escolher os catálogos:** em **Catálogos**, marque **Todos os equipamentos
   públicos** ou só os que interessam: **Transporte**, **Saúde**, **Educação**,
   **Assistência social**, **Cultura e lazer**, **Segurança**, **Administração
   pública**. Marcar um catálogo específico desmarca “Todos”, e vice-versa.
3. **Escolher a distância:** em **Raio do buffer** (o raio do círculo em volta
   da escola), arraste de 100 m a 10.000 m (10 km), de 100 em 100 m. O padrão
   é 1.000 m.
4. **Buscar:** clique em **Buscar equipamentos no entorno**. Uma barra mostra
   o andamento em %. Você pode sair da página: a busca continua, e o painel
   volta a acompanhá-la quando você retorna.
5. **Se os dados forem recentes:** quando a última busca tem menos de 7 dias,
   aparece **Os dados são recentes**. **Atualizar mesmo assim** refaz a busca
   e substitui a anterior; **Cancelar** mantém o que já existe.
6. **Ler o resultado:** o mapa mostra a escola, o círculo do raio e cada
   equipamento colorido por categoria; clique num ponto para ver o nome (quando
   o mapa o tem) e o tipo. Em **Equipamentos encontrados (N)**, cada categoria
   aparece com sua cor e quantidade; desmarque a caixa para escondê-la do mapa.
7. **Como saber que deu certo:** aparece o aviso “Equipamentos do entorno
   atualizados.” e, ao lado do botão, **Atualizado em** com a data e a hora da
   busca.

## Entendendo os números

- **N** em **Equipamentos encontrados (N)** é o total de pontos achados no
  raio, para os catálogos da última busca. Cada linha da lista é a contagem de
  uma categoria (ex.: Ponto de ônibus, Farmácia, Parque).
- **O resultado mostra o que está mapeado, não tudo o que existe.** O
  OpenStreetMap é preenchido por voluntários e a cobertura varia muito entre
  bairros e cidades. Uma categoria ausente, ou um total pequeno, não quer dizer
  que o serviço não exista: pode apenas não estar no mapa. Ausência nunca é
  zero.
- “Nenhum equipamento carregado ainda.” significa que ainda não houve busca
  (ou que ela não encontrou nada mapeado): não é uma medida do bairro.
- Ao abrir a seção, os catálogos e o raio voltam a ser os da última busca, e
  os números se referem a ela.

## Limitações conhecidas

- **A medida de confiabilidade do mapa ainda não aparece na tela.** A
  plataforma sabe calcular quanto das ruas do entorno está mapeado (um sinal de
  quanto confiar nos equipamentos encontrados), mas esse indicador ainda não é
  mostrado nesta seção. Até lá, desconfie de totais baixos em áreas que você
  sabe serem movimentadas.
- Cada nova busca **substitui** a anterior: não há histórico de buscas nem
  comparação entre datas.
- Os resultados são da escola, não de cada gestor: uma busca feita por outro
  gestor da escola também substitui a sua.
- Muitos pontos não têm nome no mapa; nesses casos aparece só o tipo.
- O mapa depende da localização da escola no Censo. Sem ela, só a lista
  aparece.
- Ver os resultados também exige estar conectado como gestor da escola.

## Privacidade

Os dados vêm de um mapa público e descrevem lugares (pontos de ônibus,
postos de saúde, praças), não pessoas. Nenhum dado pessoal é usado ou exibido.

## Perguntas frequentes

- **Sei que há um posto de saúde perto e ele não aparece.** Provavelmente ele
  não está cadastrado no OpenStreetMap, ou está fora do raio escolhido. Tente
  um raio maior.
- **Qual raio usar?** Para o que os alunos alcançam a pé, 500 m a 1.000 m.
  Para serviços que atendem o bairro todo, 2.000 m ou mais. Raios grandes
  demoram mais e trazem mais pontos.
- **A busca falhou.** A mensagem de erro aparece na própria seção. Espere
  alguns minutos e tente de novo.

## Veja também

- [Área de influência](area-de-influencia.md)
- [IVET](ivet.md)
- [Painel da escola](painel-da-escola.md)
- Ficha da funcionalidade: [Equipamentos no entorno](../../funcionalidades/gestor/equipamentos-entorno.md)
