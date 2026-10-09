package GitHooks::CommitMsg;

# Valida a convenção de commit do EduMaps (AGENTS.md):
#
#   <type>(<scope>): <subject>
#
# Bloqueia: formato inválido e `type` fora da lista.
# Avisa (não bloqueia): `scope` desconhecido, subject > MAX_SUBJECT, ponto final.
# Mensagens geradas pelo próprio git (Merge/Revert/fixup!/squash!) são isentas.
#
# Sem dependências externas (só core Perl): o hook corre em qualquer máquina com
# `perl`, sem o ambiente do backend.

use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(validate_message known_scopes);
our $MAX_SUBJECT = 50;

our @TYPES = qw(feat fix test refactor docs chore perf ci);

# Scopes canónicos (AGENTS.md) + os que já aparecem no histórico. Um scope fora
# desta lista apenas **avisa** — não se bloqueia o fluxo por uma escolha
# razoável de agrupamento.
our @KNOWN_SCOPES = qw(
  backend frontend data_pipeline data analytics analysis db
  infra docker deploy docs memory diagramas e2e tools workflow ci
  admin clients chat
);
my %KNOWN_SCOPES = map { $_ => 1 } @KNOWN_SCOPES;

# Mensagens criadas pelo próprio git não seguem a convenção.
my $EXEMPT = qr/^(?:Merge\b|Revert\b|(?:fixup|squash)!|Initial commit\b)/;

sub known_scopes { return @KNOWN_SCOPES }

sub validate_message {
  my ($message) = @_;
  $message = '' unless defined $message;

  my ($subject) = grep { /\S/ && !/^\s*#/ } split /\r?\n/, $message;
  $subject //= '';
  $subject =~ s/^\s+//;
  $subject =~ s/\s+$//;

  if ($subject eq '') {
    return {
      ok       => 0,
      subject  => '',
      errors   => ['mensagem de commit vazia'],
      warnings => [],
    };
  }

  if ($subject =~ $EXEMPT) {
    return { ok => 1, subject => $subject, errors => [], warnings => [], exempt => 1 };
  }

  if ($subject !~ /^(?<type>[a-z]+)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?: (?<desc>.+)$/) {
    return {
      ok      => 0,
      subject => $subject,
      errors  => [
        'formato inválido: esperado "<type>(<scope>): <subject>" '
          . '(ex.: "fix(backend): corrige X", "docs: atualiza Y")',
      ],
      warnings => [],
    };
  }

  my %m = %+;
  my (@errors, @warnings);

  if (!grep { $_ eq $m{type} } @TYPES) {
    push @errors, sprintf 'type "%s" inválido (use: %s)', $m{type}, join(', ', @TYPES);
  }

  if (defined $m{scope} && length $m{scope} && !$KNOWN_SCOPES{ lc $m{scope} }) {
    push @warnings, sprintf 'scope "%s" fora da lista conhecida (aviso; ver AGENTS.md)', $m{scope};
  }

  if (length($subject) > $MAX_SUBJECT) {
    push @warnings, sprintf(
      'subject com %d caractere(s) (recomendado <= %d; aviso, não bloqueia)',
      length($subject), $MAX_SUBJECT,
    );
  }

  if ($m{desc} =~ /\.$/) {
    push @warnings, 'subject não deve terminar em ponto final';
  }

  return {
    ok       => (@errors ? 0 : 1),
    subject  => $subject,
    type     => $m{type},
    scope    => $m{scope},
    errors   => \@errors,
    warnings => \@warnings,
  };
}

1;
