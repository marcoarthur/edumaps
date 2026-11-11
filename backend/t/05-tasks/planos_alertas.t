# t/05-tasks/planos_alertas.t
# #373 (épico #368): resumo diário de prazos dos planos por e-mail.
#
#   * agenda: próximas 07:00 de America/Sao_Paulo;
#   * conteúdo: só planos vigentes, de alertas ligados, com ação não concluída
#     atrasada ou vencendo em 7 dias; vai para a conta do gestor da escola;
#   * idempotência: um por gestor por dia; sem novidade, nada sai; mudou o
#     prazo, sai de novo; e-mail desligado, nada sai.
# SMTP simulado (helper canais_smtp), como em senha_redefinicao.t.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use DateTime;
use ConfigSnapshot;
use EduMaps::Task::PlanosAlertas;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $T = 'EduMaps::Task::PlanosAlertas';

# ---------------------------------------------------------------- agenda
{
  my $em = sub { DateTime->new(year => 2026, month => 3, day => 10, hour => $_[0], minute => 0,
                               time_zone => 'America/Sao_Paulo') };
  is $T->can('segundos_ate_proxima')->($em->(6)), 3_600, '06:00 → daqui a 1 h';
  is $T->can('segundos_ate_proxima')->($em->(7)), 86_400, 'às 07:00 → amanhã';
  is $T->can('segundos_ate_proxima')->($em->(23)), 8 * 3_600, '23:00 → 8 h';
}

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
skip_all('clean.planos_alertas_envio ausente (migration nao aplicada)')
  unless $dbh->selectrow_array("SELECT to_regclass('clean.planos_alertas_envio')");
ConfigSnapshot::guardar($dbh, q{%});    # config restaurada no fim

my @enviados;
$t->app->helper(canais_smtp => sub {
  sub ($cfg, $to, $from, $envelope) { push @enviados, { to => $to, envelope => $envelope }; { ok => 1 } };
});

my $INEP  = '77777772';
my $EMAIL = sprintf 'planos.alerta.%d@edumaps.test', $$;
my $SENHA = 'senha123';
my $BASE  = 'https://edumaps.teste.example';
my $model = $t->app->model('Gestor');

my $limpar = sub {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
};
$limpar->();
END {
  return unless $dbh;
  $limpar->();
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'email' AND destinatario = ?}, {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
}
$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade) VALUES (2025, ?, ?)',
  {}, $INEP, "Escola Alertas $INEP");
$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestora Alertas', email => $EMAIL, senha => $SENHA })->status_is(200);
my $gid = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

# Planos: o vigente entra; rascunho e alertas desligados não.
my $plano = sub {
  my ($titulo, $situacao, $alertas) = @_;
  my $p = $model->plano_criar($INEP, $gid, { tipo => 'acao', titulo => $titulo, situacao => $situacao,
                                             alertas_ativos => $alertas });
  my $o = $model->objetivo_criar($INEP, $gid, $p->{id}, { titulo => 'Objetivo' });
  return ($p->{id}, $o->{id});
};
my ($vig, $ovig) = $plano->('Plano de ação 2026', 'vigente', 1);
my (undef, $orasc) = $plano->('Rascunho', 'rascunho', 1);
my (undef, $ooff)  = $plano->('Sem alertas', 'vigente', 0);

my %acao;
for my $a (
  [ atrasada  => $ovig, 'Comprar livros', '2026-03-09', 'nao_iniciada', 'Coordenação' ],
  [ vencendo  => $ovig, 'Reunião com pais', '2026-03-13', 'em_andamento', undef ],
  [ longe     => $ovig, 'Feira de ciências', '2026-04-30', 'nao_iniciada', undef ],
  [ concluida => $ovig, 'Pintar a sala', '2026-03-01', 'concluida', undef ],
  [ rascunho  => $orasc, 'No rascunho', '2026-03-09', 'nao_iniciada', undef ],
  [ desligado => $ooff, 'Alertas off', '2026-03-09', 'nao_iniciada', undef ],
) {
  my ($k, $obj, $desc, $prazo, $sit, $resp) = @$a;
  my $plano_id = $dbh->selectrow_array('SELECT plano_id FROM clean.planos_objetivos WHERE id = ?', {}, $obj);
  $acao{$k} = $model->acao_criar($INEP, $gid, $plano_id, {
    objetivo_id => $obj, descricao => $desc, prazo => $prazo, situacao => $sit, responsavel => $resp })->{id};
}

subtest 'resumo: só o que vence ou atrasou, nos planos certos' => sub {
  my $r = $model->planos_alertas_resumos(hoje => '2026-03-10');
  my ($g) = grep { $_->{gestor_id} == $gid } @$r;
  ok $g, 'o gestor da escola recebe';
  is [ map { $_->{titulo} } @{ $g->{planos} } ], [ 'Plano de ação 2026' ], 'só o plano vigente de alertas ligados';
  is [ map { $_->{descricao} } @{ $g->{planos}[0]{atrasadas} } ], [ 'Comprar livros' ], 'atrasada';
  is [ map { $_->{descricao} } @{ $g->{planos}[0]{vencendo} } ], [ 'Reunião com pais' ], 'vence em 7 dias';
  is $g->{n_acoes}, 2, 'concluída e prazo distante ficam de fora';
};

sub roda { EduMaps::Task::PlanosAlertas::enviar_resumos($t->app, hoje => $_[0]) }

subtest 'e-mail desligado: nada sai' => sub {
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.email.%'});
  is roda('2026-03-10')->{desligado}, 1, 'sem config de e-mail';
  is scalar @enviados, 0, 'nenhum e-mail';
};

my $cfgm = $t->app->model('AppConfig');
$cfgm->config_put('canais.email.enabled',         'true',                       'teste');
$cfgm->config_put('canais.email.smtp_host',       'smtp.teste.example',         'teste');
$cfgm->config_put('canais.email.from',            'nao-responda@teste.example', 'teste');
$cfgm->config_put('canais.email.public_base_url', $BASE,                        'teste');

subtest 'envio, um por dia, sem novidade, novidade' => sub {
  my $r = roda('2026-03-10');
  my @meus = grep { $_->{to} eq $EMAIL } @enviados;
  is scalar @meus, 1, 'um e-mail para a conta do gestor';
  like $meus[0]{envelope}, qr/Comprar livros — prazo 09\/03\/2026 \(responsável: Coordenação\)/, 'atrasada com prazo e responsável';
  like $meus[0]{envelope}, qr/Reunião com pais — prazo 13\/03\/2026/, 'vencendo';
  like $meus[0]{envelope}, qr{\Q$BASE\E/gestor/planos/$vig}, 'link do plano';
  unlike $meus[0]{envelope}, qr/Alertas off|No rascunho|Feira de ciências/, 'nada de fora do resumo';

  roda('2026-03-10');
  is scalar(grep { $_->{to} eq $EMAIL } @enviados), 1, 'mesmo dia: não reenvia';

  roda('2026-03-11');
  is scalar(grep { $_->{to} eq $EMAIL } @enviados), 1, 'dia seguinte, mesmo conteúdo: sem novidade';

  $model->acao_atualizar($INEP, $gid, $vig, $acao{atrasada}, { situacao => 'concluida' });
  roda('2026-03-12');
  @meus = grep { $_->{to} eq $EMAIL } @enviados;
  is scalar @meus, 2, 'ação concluída mudou o resumo: sai de novo';
  unlike $meus[-1]{envelope}, qr/Comprar livros/, 'a concluída saiu do resumo';

  is $dbh->selectrow_array('SELECT count(*) FROM clean.planos_alertas_envio WHERE gestor_id = ?', {}, $gid), 2,
    'dois envios registrados';
};

done_testing;
