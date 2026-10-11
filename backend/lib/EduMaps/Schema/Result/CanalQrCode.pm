package EduMaps::Schema::Result::CanalQrCode;
use Mojo::Base 'DBIx::Class::Core', -signatures;
use utf8;

# Token público (UUID v4) de inscrição de uma lista. O token é gerado pela
# aplicação (sem default no banco). `token` é uuid no Postgres e chega ao Perl
# serializado como string de 36 chars.

__PACKAGE__->table('clean.canal_qrcodes');
__PACKAGE__->add_columns(
  id          => { data_type => 'bigint', is_auto_increment => 1 },
  lista_id    => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 0 },
  token       => { data_type => 'uuid', is_nullable => 0 },
  status      => { data_type => 'text', is_nullable => 0, default_value => 'ativo' },
  expira_em   => { data_type => 'timestamptz', is_nullable => 1 },
  max_usos    => { data_type => 'integer', is_nullable => 1 },
  usos        => { data_type => 'integer', is_nullable => 0, default_value => 0 },
  criado_por  => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 0 },
  created_at  => { data_type => 'timestamptz', is_nullable => 0, default_value => \'now()' },
  revogado_em => { data_type => 'timestamptz', is_nullable => 1 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw/token/]);

__PACKAGE__->belongs_to(lista      => 'EduMaps::Schema::Result::CanalLista', 'lista_id');
__PACKAGE__->has_many(inscricoes  => 'EduMaps::Schema::Result::CanalInscricao', 'qrcode_id', { cascade_delete => 0 });

1;