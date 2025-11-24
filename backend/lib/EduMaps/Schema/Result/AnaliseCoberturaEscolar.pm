package EduMaps::Schema::Result::AnaliseCoberturaEscolar;
use Mojo::Base "DBIx::Class::Core", -signatures;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('analise_cobertura');

__PACKAGE__->add_columns(
  "codigo_ibge",
  { data_type => "varchar", is_nullable => 0, size => 7 },
  "nome_municipio",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "vazio_educacional",
  { data_type => "geometry", is_nullable => 1, size => "16916,18" },
  "area_coberta",
  { data_type => "geometry", is_nullable => 1, size => "16916,18" },
  "area_municipio",
  { data_type => "geometry", is_nullable => 1, size => "16916,18" },
);

__PACKAGE__->result_source_instance->is_virtual(1);

# bind => [ radius ], e.g, bind => [3000] , given in meters
__PACKAGE__->result_source_instance->view_definition(q[
  WITH escola_cobertura AS (
    SELECT esc.*, ST_Buffer(esc.geometry::geography, ?)::geometry AS area_de_atendimento
    FROM escolas esc
  ),
  cobertura_escolar_municipal AS (
    SELECT m.nome_municipio,
    m.codigo_ibge,
    ST_Union(ec.area_de_atendimento) AS area_coberta
    FROM escola_cobertura ec
         JOIN municipios_sp m ON ST_Contains(m.geometry, ec.geometry)
    GROUP BY m.nome_municipio, m.codigo_ibge
  ),
  analise_escolar_municipal AS (
    SELECT
    m.codigo_ibge,
    m.nome_municipio,
    ST_Difference(m.geometry, cem.area_coberta) AS vazio_educacional, 
    cem.area_coberta,
    m.geometry AS area_municipio
    FROM cobertura_escolar_municipal cem JOIN municipios_sp m ON cem.codigo_ibge = m.codigo_ibge
  )
  SELECT aem.codigo_ibge, aem.nome_municipio, aem.vazio_educacional, aem.area_coberta, aem.area_municipio
  FROM analise_escolar_municipal aem
]);

__PACKAGE__->belongs_to(
  'municipio',
  'EduMaps::Schema::Result::MunicipiosSp',
  { 'foreign.codigo_ibge' => 'self.codigo_ibge' }
);

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

EduMaps::Schema::Result::AnaliseCoberturaEscolar - Análise de cobertura escolar por município

=head1 SYNOPSIS

    my $rs = $schema->resultset('AnaliseCoberturaEscolar')->search(
        {},
        { bind => [3000] }  # raio de 3km
    );
    
    while (my $row = $rs->next) {
        say "Município: " . $row->nome_municipio;
        say "Código IBGE: " . $row->codigo_ibge;
        # ... outros campos
    }

=head1 DESCRIPTION

Esta classe representa uma view do banco de dados que realiza análise espacial da cobertura escolar nos municípios. 
Utiliza operações geográficas para identificar áreas com e sem cobertura educacional baseada na localização das escolas.

A view é virtual e requer um parâmetro de bind (raio em metros) para ser executada.

=head1 TABLE: analise_cobertura

=head1 ACCESSORS

=head2 codigo_ibge

    Data Type: varchar
    Size: 7
    Nullable: 0
    Description: Código IBGE do município (chave primária)

=head2 nome_municipio

    Data Type: varchar  
    Size: 100
    Nullable: 1
    Description: Nome do município

=head2 vazio_educacional

    Data Type: geometry
    Nullable: 1
    Description: Áreas do município sem cobertura escolar (diferença entre área total e área coberta)

=head2 area_coberta

    Data Type: geometry
    Nullable: 1  
    Description: Áreas do município com cobertura escolar (união das áreas de atendimento das escolas)

=head2 area_municipio

    Data Type: geometry
    Nullable: 1
    Description: Geometria completa do município

=head1 VIEW DEFINITION

A view utiliza as seguintes CTEs (Common Table Expressions):

=head2 escola_cobertura

    Calcula a área de atendimento de cada escola aplicando um buffer (raio) em torno da geometria

=head2 cobertura_escolar_municipal

    Agrupa por município e calcula a união de todas as áreas de atendimento das escolas

=head2 analise_escolar_municipal

    Compara a área total do município com a área coberta para identificar vazios educacionais

=head1 RELATIONS

=head2 municipio

Type: belongs_to

Related object: L<EduMaps::Schema::Result::MunicipiosSp>

=head1 METHODS

=head2 result_source_instance

    Configura a view como virtual e define sua estrutura

=head2 view_definition

    Define a query SQL da view com parâmetro bind para o raio de cobertura

=head1 PARAMETERS

A view requer um parâmetro de bind:

    bind => [raio_em_metros]

Exemplo: bind => [3000] para raio de 3km

=head1 SEE ALSO

L<EduMaps::Schema::Result::MunicipiosSp>
L<EduMaps::Schema::Result::Escolas>

=head1 AUTHOR

EduMaps Team

=head1 LICENSE

Este software é código aberto sob a licença MIT.

=cut
