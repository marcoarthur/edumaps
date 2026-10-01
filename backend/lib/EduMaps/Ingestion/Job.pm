package EduMaps::Ingestion::Job;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::Log;
use Time::Piece;
use Time::HiRes qw(sleep);

has ua => sub { Mojo::UserAgent->new->connect_timeout(30)->inactivity_timeout(300) };
has log => sub { Mojo::Log->new };
has max_retries => 3;
has backoff_base => 5;  # seconds

sub register ($self, $app, $conf) {
  $app->helper(ingestion_job => sub ($c, $job_name) {
    return $self->new(job_name => $job_name, config => $conf);
  });
}

sub run_with_retry ($self, $operation, $description) {
  my $retries = 0;
  while (1) {
    my $result = eval { $operation->() };
    return $result unless $@;
    
    my $error = $@;
    chomp $error;
    $self->log->warn("[$description] Tentativa $retries falhou: $error");
    
    $retries++;
    if ($retries > $self->max_retries) {
      $self->log->error("[$description] Falhou após $self->max_retries tentativas: $error");
      die "Falha permanente: $error";
    }
    
    my $sleep_time = $self->backoff_base * (2 ** ($retries - 1)) + rand(2);
    $self->log->info("[$description] Aguardando ${sleep_time}s antes de retry $retries/$self->max_retries");
    sleep($sleep_time);
  }
}

sub fetch_with_retry ($self, $url, $headers = {}) {
  return $self->run_with_retry(sub {
    my $tx = $self->ua->get($url => $headers);
    die $tx->error->{message} if $tx->error;
    return $tx->result;
  }, "GET $url");
}

sub download_file ($self, $url, $dest_path, $headers = {}) {
  return $self->run_with_retry(sub {
    my $tx = $self->ua->get($url => $headers);
    die $tx->error->{message} if $tx->error;
    $tx->result->content->asset->move_to($dest_path);
    return $dest_path;
  }, "DOWNLOAD $url -> $dest_path");
}

sub run_r_script ($self, $script_path, $args = []) {
  return $self->run_with_retry(sub {
    my @cmd = ('Rscript', '--vanilla', $script_path, @$args);
    $self->log->info("Executando R: @cmd");
    my $output = `$cmd[0] @cmd[1..$#cmd] 2>&1`;
    my $exit_code = $? >> 8;
    die "R script falhou (exit $exit_code): $output" if $exit_code;
    return $output;
  }, "R script $script_path");
}

sub run_perl_script ($self, $script_path, $args = []) {
  return $self->run_with_retry(sub {
    my @cmd = ('perl', $script_path, @$args);
    $self->log->info("Executando Perl: @cmd");
    my $output = `$cmd[0] @cmd[1..$#cmd] 2>&1`;
    my $exit_code = $? >> 8;
    die "Perl script falhou (exit $exit_code): $output" if $exit_code;
    return $output;
  }, "Perl script $script_path");
}

sub upsert_metadata ($self, $table_name, $source_file, $source_url, $source_license, $row_count, $notes) {
  my $db = $self->app->schema->storage->dbh;
  $db->do(
    q{INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
      VALUES (?, ?, ?, ?, NOW(), ?, ?)
      ON CONFLICT (table_name) DO UPDATE SET
        source_file = EXCLUDED.source_file,
        source_url = EXCLUDED.source_url,
        source_license = EXCLUDED.source_license,
        retrieved_at = NOW(),
        row_count_loaded = EXCLUDED.row_count_loaded,
        notes = EXCLUDED.notes},
    undef, $table_name, $source_file, $source_url, $source_license, $row_count, $notes
  );
}

sub get_latest_snapshot ($self, $table_name) {
  my $db = $self->app->schema->storage->dbh;
  my $sth = $db->prepare("SELECT MAX(dt_snapshot) FROM clean.$table_name");
  $sth->execute;
  return $sth->fetchrow_array;
}

1;