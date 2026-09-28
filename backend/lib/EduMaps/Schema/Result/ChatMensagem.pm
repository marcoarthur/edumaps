package EduMaps::Schema::Result::ChatMensagem;
use Mojo::Base 'DBIx::Class::Core', 'DBIx::Class::InflateColumn', -signatures;
use Mojo::JSON qw(encode_json decode_json);
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

# `meta` é jsonb, mas o DBIx::Class 0.0828 não tem inflator json/jsonb. Sem isto
# o Postgres entrega a coluna já serializada e o `$m->meta` sai como texto: a
# API devolvia uma string JSON onde o contrato (e o ChatMessage.svelte, que
# lê meta.timestamp / meta.sql / meta.origem) espera um objeto.
#
# O deflate é obrigatório: sem ele o DBIC estoura ("No deflator found") sempre
# que a coluna recebe uma ref, que é justamente o que queremos gravar.
#
# O decode nunca deve estourar: um valor gravado por fora do schema (SQL cru)
# pode não ser JSON, e uma exceção aqui viraria erro do DBIC no meio da
# leitura. Nesse caso devolvemos o valor cru, que é o comportamento de antes.
__PACKAGE__->inflate_column(
  meta => {
    inflate => sub {
      my ($value) = @_;
      return $value if !defined $value || ref $value;
      my $decoded = eval { decode_json($value) };
      return defined $decoded ? $decoded : $value;
    },
    deflate => sub {
      my ($value) = @_;
      return $value if !defined $value || !ref $value;
      return encode_json($value);
    },
  }
);

1;