package EduMaps::Schema::Result::CanalListaMembro;
use Mojo::Base 'DBIx::Class::Core', -signatures;
use utf8;

# Pertencimento de um contato a uma lista (desacoplado de contato_grupos).

__PACKAGE__->table('clean.canal_lista_membros');
__PACKAGE__->add_columns(
  id         => { data_type => 'bigint', is_auto_increment => 1 },
  lista_id   => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 0 },
  contato_id => { data_type => 'bigint', is_foreign_key => 1, is_nullable => 0 },
  origem     => { data_type => 'text', is_nullable => 0, default_value => 'qrcode' },
  validado   => { data_type => 'boolean', is_nullable => 0, default_value => \'false' },
  created_at => { data_type => 'timestamptz', is_nullable => 0, default_value => \'now()' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw/lista_id contato_id/]);

__PACKAGE__->belongs_to(lista => 'EduMaps::Schema::Result::CanalLista', 'lista_id');

1;