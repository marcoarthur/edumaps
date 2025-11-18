#!/usr/bin/env perl

use Mojo::Base -strict, -signatures;
use open ':std', ':encoding(UTF-8)';

use Getopt::Long;
use Pod::Usage;

my %options = (
  change  => '@HEAD^',
  target  => 'dev_super',
  skip_verify => 0,
  skip_revert => 0,
  dry_run => 0,
  verbose => 0,
  help    => 0,
);

GetOptions(
  'change=s'    => \$options{change},
  'target=s'    => \$options{target},
  'skip-verify' => \$options{skip_verify},
  'skip-revert' => \$options{skip_revert},
  'dry-run'     => \$options{dry_run},
  'verbose'     => \$options{verbose},
  'help|h'      => \$options{help},
) or pod2usage(2);

pod2usage(1) if $options{help} || !$options{change};

say "🧪 Testando change: $options{change}";
say "🎯 Target: $options{target}";
say "⚡ Dry-run: " . ($options{dry_run} ? 'SIM' : 'NÃO');
say "=" x 50;

if ($options{dry_run}) {
  say "📋 COMANDOS QUE SERIAM EXECUTADOS:";
  say "  sqitch deploy $options{change} --target $options{target}";
  say "  sqitch verify $options{change} --target $options{target}" unless $options{skip_verify};
  say "  sqitch revert $options{change} --target $options{target}" unless $options{skip_revert};
  exit 0;
}

# Verificar target
say "1. 🔍 Verificando target..." if $options{verbose};
system("sqitch target show $options{target} >/dev/null 2>&1") == 0 or
die "❌ Target '$options{target}' não encontrado\n";

# Status inicial
say "2. 📊 Status inicial:" if $options{verbose};
system("sqitch status $options{target}") if $options{verbose};

# Deploy
say "3. 🚀 Executando deploy...";
system("sqitch deploy --target $options{target}") == 0 or
die "❌ Deploy falhou\n";
say "✅ Deploy OK";

# Verify (opcional)
unless ($options{skip_verify}) {
  say "4. 🔍 Executando verify...";
  my $verify_status = system("sqitch verify --target $options{target}");
  if ($verify_status == 0) {
    say "✅ Verify OK";
  } else {
    say "⚠️  Verify falhou (mas continuando)";
  }
}

# Revert (opcional)
unless ($options{skip_revert}) {
  say "5. ↩️  Executando revert...";
  if ( $options{change} =~ /HEAD/ ) {
    $options{change} = "--to " . $options{change};
  }
  system("sqitch revert $options{change} --target $options{target}") == 0 or
  die "❌ Revert falhou\n";
  say "✅ Revert OK";
}

# Status final
say "6. 📊 Status final:" if $options{verbose};
system("sqitch status $options{target}") if $options{verbose};

say "=" x 50;
say "🎉 Teste concluído com sucesso!";

__END__

=head1 NAME

test-change-advanced.pl - Teste avançado de changes Sqitch

=head1 SYNOPSIS

# Teste básico
perl bin/test-change-advanced.pl --change raw_escolas

# Pular verify (útil se verify estiver com problemas)
perl bin/test-change-advanced.pl --change raw_escolas --skip-verify

# Apenas deploy (para debugging)
perl bin/test-change-advanced.pl --change raw_escolas --skip-revert

# Dry-run (apenas mostrar comandos)
perl bin/test-change-advanced.pl --change raw_escolas --dry-run

# Verbose (mais detalhes)
perl bin/test-change-advanced.pl --change raw_escolas --verbose

=head1 OPTIONS

=over 4

=item B<--change>=I<change_name>

Nome da change (obrigatório)

=item B<--target>=I<target_name>

Target (padrão: dev)

=item B<--skip-verify>

Pular teste de verify

=item B<--skip-revert>

Pular teste de revert (útil para debugging)

=item B<--dry-run>

Apenas mostrar comandos, não executar

=item B<--verbose>

Mostrar mais detalhes

=item B<--help>

Ajuda

=back
