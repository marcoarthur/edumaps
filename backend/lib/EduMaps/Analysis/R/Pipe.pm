package EduMaps::Analysis::R::Pipe;
use Mojo::Base -base, -signatures;
use Mojo::File qw(path tempfile);
use Mojo::Collection qw(c);
use Carp qw(croak);
use IPC::Run;

has engine       => 'Rscript';
has default_opts => sub { [qw/--vanilla/] };
has [qw(paths source_file script cmd_str cmd_args script_tmp full_cmd)];

sub run ($self, $args) {
  $self->_set_args($args)
  ->_resolve_cmd
  ->_mount_final_script
  ->_run;
}

sub _set_args ($self, $args) {
  $self->paths(c($args->{paths}->@*)->map(sub { path($_) }));

  my $target_name = path($args->{source_file})->basename;

  # Busca o script R iterando de forma segura pelas rotas de paths
  my $file = $self->paths->map(
    sub ($dir) {
      return unless -d $dir;
      $dir->list_tree->first(sub ($f) { $f->basename eq $target_name });
    }
  )->grep(sub { defined $_ && -e $_ })->first;

  croak "R Script '$target_name' not found in paths" unless $file;

  $self->source_file($file);
  $self->script($args->{script});
  $self;
}

sub _resolve_cmd ($self) {
  $self->cmd_str($self->engine);
  $self->cmd_args(c($self->default_opts->@*));
  $self->script_tmp(tempfile( DIR => '/tmp' ));
  $self;
}

sub _mount_final_script ($self) {
  $self->script_tmp->spew(
    sprintf qq{source("%s")\n%s},
    $self->source_file->to_abs->to_string,
    $self->script
  );

  $self->full_cmd(c($self->cmd_str, $self->cmd_args->@*, $self->script_tmp));
  $self;
}

sub _run ($self) {
  my ($out, $err);
  my $ok = IPC::Run::run($self->full_cmd->to_array, \undef, \$out, \$err);

  # Força o unlink do arquivo temporário imediatamente após o término da execução
  if ($self->script_tmp && -e $self->script_tmp) {
    unlink $self->script_tmp;
  }

  croak "Rscript failed: $err" unless $ok;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Analysis::R::Pipe - Pipeline de execução isolada e dinâmica de scripts R via IPC::Run

=head1 SYNOPSIS

    use EduMaps::Analysis::R::Pipe;

    my $rpipe = EduMaps::Analysis::R::Pipe->new;
    $rpipe->run({
        paths       => [qw(/path/to/r/scripts)],
        source_file => 'analytics_script.R',
        script      => 'custom_r_function(arg1 = "value")'
    });

=head1 DESCRIPTION

O módulo L<EduMaps::Analysis::R::Pipe> gerencia o ciclo de vida de subprocessos C<Rscript>. Ele localiza dinamicamente arquivos de origem dentro dos caminhos especificados, injeta comandos customizados em tempo de execução e garante o expurgo de arquivos temporários em disco.

=head1 SEE ALSO

L<IPC::Run>, L<Mojo::File>, L<EduMaps::Task::Kmeans>

=cut
