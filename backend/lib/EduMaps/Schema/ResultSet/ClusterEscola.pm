package EduMaps::Schema::ResultSet::ClusterEscola;
use Mojo::Base "EduMaps::Schema::ResultSet::Base", -signatures;


sub new_rs($self, $opts) {

  $self->search_rs(
    undef,
    {bind => [$opts->{co_municipio}, $opts->{clusters} || 5]}
  );
}

1;
