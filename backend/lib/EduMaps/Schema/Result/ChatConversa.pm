package EduMaps::Schema::Result::ChatConversa;
use Mojo::Base 'DBIx::Class::Core', -signatures;
use utf8;

__PACKAGE__->table('chat_conversas');
__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_auto_increment => 1 },
  gestor_id => { data_type => 'bigint' },
  titulo => { data_type => 'text', is_nullable => 1 },
  created_at => { data_type => 'timestamptz', default_value => \'now()' },
  updated_at => { data_type => 'timestamptz', default_value => \'now()' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(mensagens => 'EduMaps::Schema::Result::ChatMensagem', 'conversa_id', { cascade_delete => 1 });

1;