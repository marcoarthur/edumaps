# t/02-models/leitor_grants.t
# Papel somente-leitura edumaps_leitor (Assistente do Censo e relatórios do
# motor R): toda relação do schema clean tem de ter uma decisão explícita.
#
#   * pública  → a migração da tabela faz GRANT SELECT ... TO edumaps_leitor;
#   * sensível → sem GRANT, e o nome está em %SENSIVEIS abaixo.
#
# Desde a change leitor_grants_explicitos não há SELECT automático em clean:
# tabela nova sem GRANT e fora da lista quebra este teste (esquecimento), e
# tabela da lista com SELECT também (regressão). É um GATE no CI.
use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;
use utf8;

my $dbh = EduMaps::Schema->go->storage->dbh;

skip_all('papel edumaps_leitor ausente')
  unless $dbh->selectrow_array(q{SELECT 1 FROM pg_roles WHERE rolname = 'edumaps_leitor'});

# Internas ou com dados pessoais (mesma lista da change leitor_sem_tabelas_sensiveis).
my %SENSIVEIS = map { $_ => 1 } qw(
  gestores sessoes auth_falhas senha_redefinicoes
  contatos contato_grupos
  canal_confirmacao_refs canal_confirmacoes canal_envio_destinatarios
  canal_envio_suspensoes canal_envios canal_exclusoes canal_inscricoes
  canal_lista_membros canal_listas canal_mensagens canal_optouts
  canal_qr_acessos canal_qrcodes canal_segmentos canal_telegram_estado
  chat_conversas chat_mensagens
  gestor_pesquisas gestor_pesquisas_perguntas gestor_pesquisas_respostas
  gestor_pesquisas_respostas_itens
  relacoes relacoes_categorias relacoes_documentos relacoes_entidades
  relacoes_interacoes relacoes_tarefas
  reunioes reuniao_anexos reunioes_participantes
  inventario_anexos inventario_categorias inventario_fornecedores inventario_itens
  escola_documentos escola_documentos_auditoria escola_documentos_versoes
  pastas_escolares relatorios_salvos consentimento_versoes
  planos_gestao planos_objetivos planos_metas planos_acoes planos_auditoria
  planos_metas_medicoes planos_alertas_envio
  event_store session_tracking
  minion_jobs minion_locks minion_schedules minion_workers mojo_migrations
);

my $rels = $dbh->selectall_arrayref(q{
  SELECT c.relname, has_table_privilege('edumaps_leitor', c.oid, 'SELECT')
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'clean' AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
     AND NOT c.relispartition
   ORDER BY 1
});
ok scalar(@$rels), 'schema clean tem relações';

my (@sem_decisao, @sensivel_legivel);
for my $r (@$rels) {
  my ($nome, $le) = @$r;
  if ($SENSIVEIS{$nome}) { push @sensivel_legivel, $nome if $le }
  elsif (!$le)           { push @sem_decisao, $nome }
}

is \@sensivel_legivel, [], 'nenhuma tabela sensível legível pelo edumaps_leitor'
  or diag 'revogar via change nova: REVOKE ALL ON clean.<t> FROM edumaps_leitor';
is \@sem_decisao, [], 'toda relação pública de clean tem GRANT explícito'
  or diag 'pública: GRANT SELECT na migração; sensível: incluir em %SENSIVEIS';

my $automatico = $dbh->selectrow_array(q{
  SELECT count(*) FROM pg_default_acl d
   CROSS JOIN LATERAL aclexplode(d.defaclacl) a
   WHERE d.defaclnamespace = 'clean'::regnamespace
     AND a.grantee = 'edumaps_leitor'::regrole
});
is $automatico, 0, 'sem SELECT automático para edumaps_leitor em clean';

done_testing;
