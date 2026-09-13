**Análise integrada: Código de Clusterização vs. Resultados Observados**

---

## ✅ O que o código faz bem

1. **Integração Mojolicious + Minion** – Task assíncrona com fila, ideal para processamento pesado.
2. **Validação de entrada** – Uso do `validator` para garantir nomes de tabelas, colunas e parâmetros numéricos, prevenindo injeção SQL e erros de sintaxe.
3. **Tratamento de erros** – `try/catch` captura falhas do R e marca a job como falha, com mensagem descritiva.
4. **Rastreabilidade** – Metadados (tempo, job_id) são salvos no `finish`, permitindo monitoramento.
5. **Configuração centralizada** – Constantes para valores padrão (schema, k, script) facilitam manutenção.
6. **Uso do `EduMaps::Analysis::R::Pipe`** – Abstrai a execução do R, mantendo o código do plugin limpo.

---

## ⚠️ Fragilidades e oportunidades de melhoria

### 1. Localização do script R
```perl
my $paths = c($job->app->renderer->paths->@*)->map(sub { Mojo::File->new });
```
- Usa `renderer->paths` (diretórios de templates) para encontrar `kmeans.R`. Isso pode causar confusão se o script estiver em outro local.
- **Sugestão**: definir um diretório específico (ex: `$app->home->child('share/scripts')`) e adicioná-lo ao `paths` do Pipe.

### 2. Validação restrita para `source_file`
```perl
$v->optional('source_file', 'trim')->like(qr/^\w+\.R$/);
```
- Impede que o usuário passe caminhos com subdiretórios ou nomes com hífen/pontos.
- **Sugestão**: permitir `qr/^[\w\/\-\.]+\.R$/` ou usar `Mojo::File` para resolver.

### 3. Arquivo temporário do Pipe não é removido
- Como discutido anteriormente, o `Pipe` cria um script temporário em `/tmp` mas não o apaga. Em execuções frequentes, isso acumula lixo.
- **Sugestão**: modificar o `Pipe` para incluir `unlink` no `_run` (após capturar saída) ou usar `File::Temp` com `UNLINK => 1`.

### 4. Falta de logs detalhados
- O código não registra início/fim da execução R, nem a saída (stdout/stderr) capturada.
- **Sugestão**: usar `$job->app->log->info` para marcar etapas e, se o Pipe for modificado para retornar a saída, registrá-la.

### 5. Conexão com banco de dados via R
- O script R usa `RPostgres::Postgres()` com `service = "$args->{db_service}"`. Isso presume que o arquivo `~/.pg_service.conf` ou equivalente está configurado.
- **Sugestão**: validar a conexão antes de chamar o R (ex: usando o DBI do Perl) para falhar rápido e com mensagem clara.

### 6. `Time::Piece` para medição
- Funciona, mas `Time::HiRes` seria mais preciso se o job for muito curto.
- **Sugestão**: usar `Time::HiRes::time` para maior precisão.

### 7. Ausência de testes automatizados
- O código não possui testes unitários ou de integração para a task.
- **Sugestão**: criar testes que mockem o `Pipe` e verifiquem validação, construção de argumentos e tratamento de erros.

---

## 🔗 Relação com os clusters gerados

Os clusters observados (`cluster_id` de 1 a 5) refletem exatamente o que o código e o script R produzem:

- **Cluster 1**: Escolas com grande volume de fundamental e nenhum médio → resultado do k-means separando instituições sem oferta de médio.
- **Cluster 2**: Escolas com ensino fundamental e médio equilibrados → uma transição.
- **Cluster 3**: Escolas particulares com médio presente → agrupadas por perfil de porte.
- **Cluster 4**: Escolas municipais com fundamental forte e médio incipiente → outro perfil.
- **Cluster 5**: Pequenas unidades (creches, EMEIs, escolas rurais) → extremo oposto.

Isso indica que as features escolhidas (`qt_doc_*` e `qt_mat_*`) são discriminativas e o k-means (com `k=5`) produziu agrupamentos interpretáveis.

---

## 🛠️ Sugestões concretas de código

### 1. Ajustar localização do script R
```perl
my $script_dir = $job->app->home->child('share/scripts');
my $script_file = $script_dir->child($args->{source_file} // KMEANS_SCRIPT);
croak "Script not found" unless -f $script_file;

# Passar o caminho absoluto ao Pipe
$rpipe->run({
    paths       => [$script_dir->to_abs],
    source_file => $script_file->basename,
    script      => ...,
});
```

### 2. Melhorar validação de `source_file`
```perl
$v->optional('source_file', 'trim')->like(qr/^[\w\/\-\.]+\.R$/);
```

### 3. Adicionar logs
```perl
$job->app->log->info("Starting k-means on $args->{schema}.$args->{table_name}, k=$args->{clusters}");
$job->app->log->debug("R script: $args->{source_file}");
```

### 4. Verificar conexão DB antes do R (opcional)
```perl
use DBI;
my $dbh = DBI->connect("dbi:Pg:service=$args->{db_service}") or croak "Cannot connect";
$dbh->disconnect;
```

### 5. Melhorar tratamento de erros
```perl
catch($err) {
    $job->app->log->error("R error: $err");
    $job->fail("R k-means failed: $err");
    return;  # evita continuar
}
```

---

## 📝 Conclusão

O módulo `EduMaps::Task::Kmeans` é uma implementação funcional e bem estruturada, que aproveita corretamente o ecossistema Mojolicious/Minion e o `EduMaps::Analysis::R::Pipe`. Os clusters gerados são coerentes e úteis para análise de perfil de escolas.

Com pequenas melhorias em:
- Localização de scripts,
- Limpeza de arquivos temporários,
- Logging,
- Validação mais flexível,
- Testes automatizados,

o código se tornará mais robusto e adequado para produção em larga escala.

Se desejar, posso ajudar a implementar qualquer uma dessas melhorias ou a criar testes para o módulo.

# Aplicando ao Rio de Janeiro

Com base nos centroides gerados pelo K‑means para os dados do Rio de Janeiro, temos **5 clusters** que representam diferentes perfis de estabelecimentos de ensino, considerando a quantidade de docentes e matrículas nos níveis básico (fundamental) e médio.

A tabela abaixo resume cada grupo:

| Cluster | N.º de escolas | Soma quadrados intra‑cluster | Média docentes básico | Média docentes médio | Média matrículas básico | Média matrículas médio |
|--------:|---------------:|-----------------------------:|----------------------:|---------------------:|------------------------:|-----------------------:|
| 1       | 436            | 444,8                        | 31,0                  | 18,8                 | 322,4                   | 127,7                  |
| 2       | 143            | 892,0                        | 62,5                  | 39,0                 | 923,3                   | 430,2                  |
| 3       | 63             | 975,4                        | 105,0                 | 94,4                 | 1.436,7                 | 1.235,5                |
| 4       | 767            | 582,3                        | 27,1                  | 0,3                  | 610,9                   | 2,9                    |
| 5       | 2.466          | 541,1                        | 10,9                  | 0,5                  | 152,9                   | 2,0                    |

---

### Interpretação dos perfis

- **Cluster 5 (maior grupo, ~61% das escolas)**  
  Escolas de **pequeno porte**, com reduzido número de docentes (≈11 no fundamental, <1 no médio) e matrículas modestas (≈153 no fundamental, apenas 2 no médio).  
  → Provavelmente são **escolas exclusivas de anos iniciais do fundamental** ou unidades muito pequenas, localizadas em áreas rurais ou periferias com baixa densidade populacional.

- **Cluster 4 (segundo maior, ~19%)**  
  Apresenta **médias razoáveis no fundamental** (27 docentes, 611 matrículas), mas praticamente **zero no ensino médio**.  
  → Trata‑se de **escolas de ensino fundamental (anos finais)** sem oferta de médio, de porte médio‑pequeno.

- **Cluster 1 (~11%)**  
  Perfil **intermediário**: docentes (31 no básico, 19 no médio) e matrículas (322 no básico, 128 no médio).  
  → Escolas que oferecem **ambos os níveis**, com turmas de tamanho moderado, típicas de bairros urbanos consolidados.

- **Cluster 2 (~3,5%)**  
  Escolas de **grande porte**, com médias elevadas (62 docentes no básico, 39 no médio; 923 matrículas no básico, 430 no médio).  
  → Provavelmente **colégios estaduais de grande movimento** ou instituições de referência regional.

- **Cluster 3 (menor grupo, ~1,5%)**  
  **Megae-escolas** com médias altíssimas: 105 docentes no fundamental, 94 no médio; 1.437 matrículas no fundamental e 1.236 no médio.  
  → Geralmente **campi de grande porte** que concentram várias etapas de ensino, possivelmente com ensino profissionalizante ou diurno/noturno.

---

### Observações relevantes

- **Distribuição assimétrica:** mais de 80% das escolas estão concentradas nos clusters 4 e 5, que têm baixa ou nenhuma oferta de médio. Isso reflete a estrutura educacional fluminense, onde a maioria das unidades atende apenas o fundamental.
- **Inércia intra‑cluster** (quarta coluna) é maior nos clusters 2 e 3, indicando que esses grupos têm maior variabilidade interna (escolas grandes, porém com tamanhos distintos). Os clusters 1, 4 e 5 são mais homogêneos.
- A separação entre básico e médio é nítida: os clusters 4 e 5 praticamente ignoram o médio, enquanto os clusters 1, 2 e 3 integram ambos os níveis, com proporções diferentes.

---

### Potenciais usos desses centroides

- **Políticas de alocação de recursos** – identificar regiões com predominância de escolas pequenas (cluster 5) para planejar fusões ou programas de apoio.
- **Oferta de ensino médio** – os clusters 4 e 5 indicam carência de vagas no médio; podem orientar a expansão da rede estadual.
- **Monitoramento de desempenho** – cruzar esses perfis com indicadores de rendimento (IDEB, taxa de abandono) para entender quais tamanhos de escola têm melhores resultados.
- **Segmentação para intervenções** – adaptar projetos pedagógicos conforme o porte da escola (ex.: formação de professores, infraestrutura).

Se desejar, posso aprofundar a análise estatística (ex.: testar diferenças entre clusters, visualizar em gráficos, ou sugerir novos agrupamentos com outros atributos como localização ou rede administrativa).
