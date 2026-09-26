package EduMaps::Schema::Result::ChatMensagem;
use Mojo::Base 'DBIx::Class::Core', -signatures;
use utf8;

__PACKAGE__->table('chat_mensagens');
__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_auto_increment => 1 },
  conversa_id => { data_type => 'bigint', is_foreign_key => 1 },
  role => { data_type => 'text', is_nullable => 0 },
  content => { data_type => 'text', is_nullable => 0 },
  meta => { data_type => 'jsonb', is_nullable => 1 },
  created_at => { data_type => 'timestamptz', default_value => \'now()' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(conversa => 'EduMaps::Schema::Result::ChatConversa', 'conversa_id');

1;