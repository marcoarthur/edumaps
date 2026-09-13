
# Uso do R para gráficos

Avalie a arquitetura para integrar ao EduMaps uma plataforma gráfica baseada no
plotly e ggplot2, portanto código R, fonte gráfica, Perl + Database como fonte
de dados, Seguindo as seguintes premissas:

1. Os scripts R são here docs (Perl) ou templates (Perl).
2. Os gráficos são gerados on-the-fly na requisição e armazenados (o json para
o gráfico, advindo da chamada 
`json_string <- plotly_json(p, jsonedit = FALSE)
cat(json_string)`
3. O perl captura esse conteúdo e fornece ao frontend.
4. A camada perl armazena o conteúdo no banco de dados, com metadados,
acelerando uma próxima chamada.
5. O frontend entende o conteúdo via biblioteca plotly.js e renderiza no cliente
os gráficos.


# Deep Seek

Escreva a user history do EduMaps para um gestor escolar interessado em conhecer
as escolas similares a sua baseado em um conjunto de indicadores selectionado por ele

Um exemplo. O diretor da escola municipal Dom Pedro II seleciona os seguintes indicadores:

- Infraestrutura
- Capacidade docente
- Nota média ideb

E quer buscar similaridade com as escolas do seu municipio/estado ou país.
