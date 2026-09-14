package EduMaps::Presets;
use Mojo::Base -signatures;

use constant {
  # Tabela denormalizada usada na clusterização multi-tabela (censo + docentes
  # + IDEB). Populada dinamicamente pelo job clusterization.
  INDICATORS_TABLE => 'school_indicators',
};

# Presets curados de indicadores. "year_filter" indica que o preset depende do
# ano IDEB/SAEB escolhido pelo usuário (obrigatório no request_cluster).
# As features são colunas de clean.school_indicators; os rótulos/comments
# aparecem no GET /api/cluster/columns. A ordem de @PRESET_IDS é a de exibição.
my @PRESET_IDS = qw(infraestrutura docencia desempenho);

my $PRESETS = {
  desempenho => {
    id          => 'desempenho',
    name        => 'Desempenho dos alunos',
    description => 'Proficiências SAEB, IDEB observado e aprovação (escolha o ano)',
    year_filter => 1,
    features    => [qw(
      nota_media nota_matematica nota_portugues ideb_observado aprovacao_si_4
    )],
  },
  docencia => {
    id          => 'docencia',
    name        => 'Qualidade de docência',
    description => 'Formação (licenciatura/mestrado/doutorado), efetividade e especialização dos docentes',
    year_filter => 0,
    features    => [qw(
      prop_licenciatura prop_mestrado prop_doutorado prop_efetivos prop_sem_especializacao
    )],
  },
  infraestrutura => {
    id          => 'infraestrutura',
    name        => 'Infraestrutura escolar',
    description => 'Água, energia, esgoto, banheiros, biblioteca, laboratórios, quadra, internet e acessibilidade',
    year_filter => 0,
    features    => [qw(
      in_agua_potavel in_energia_rede_publica in_esgoto_rede_publica in_lixo_servico_coleta
      in_banheiro in_biblioteca in_laboratorio_ciencias in_laboratorio_informatica
      in_quadra_esportes in_internet in_acessibilidade_rampas
    )],
  },
};

sub presets($cls) {
  return [ map { { %{ $PRESETS->{$_} } } } @PRESET_IDS ];
}

sub get($cls, $id) {
  return unless defined $id && exists $PRESETS->{$id};
  return { %{ $PRESETS->{$id} } };
}

sub presets_by_id($cls) {
  return { %$PRESETS };
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Presets - Presets de indicadores para clusterização

=head1 SYNOPSIS

    use EduMaps::Presets;

    my $all = EduMaps::Presets->presets;         # lista de hashrefs
    my $pre = EduMaps::Presets->get('docencia'); # um preset ou undef

=head1 DESCRIPTION

Define os conjuntos curados de features de clusterização expostos em
C<GET /api/cluster/presets>. Cada preset referencia colunas de
C<clean.school_indicators> (tabela denormalizada populada pelo job
clusterization).

=over

=item * B<desempenho> - proficiências/IDEB, depende do ano (I<year_filter>)

=item * B<docencia> - proporções de formação e vínculo dos docentes

=item * B<infraestrutura> - infraestrutura física da escola

=back

Num próximo ciclo os presets poderão ser definidos/customizados pelo usuário
(armazenados em banco); por ora são fixos neste módulo.

=cut