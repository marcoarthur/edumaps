Sua hipótese é excelente e toca no coração da complexidade da gestão escolar pública. Na educação básica brasileira (particularmente em redes grandes como São Paulo), é extremamente comum o fenômeno do **"desvio de função funcional" ou progressão para cargos de gestão**.

Professores altamente qualificados (com mestrado e doutorado) frequentemente deixam a regência de classe (sala de aula) para assumir cargos de **coordenação pedagógica, direção, vice-direção ou postos de assessoria técnica e administrativa**. Como consequência:

1. O diploma de pós-graduação dele continua computado no censo daquela escola (pois ele faz parte do quadro).
2. O impacto direto dele na proficiência dos alunos na sala de aula (medida pelo exame nacional) diminui ou se dilui.
3. Se a escola possui uma estrutura administrativa inchada ou altamente especializada para lidar com uma comunidade complexa/vulnerável, haverá uma alta concentração de títulos em cargos de gestão, enquanto o desempenho dos alunos continua pressionado por fatores socioeconômicos.

Como o censo escolar separa os docentes dos profissionais administrativos e de serviços gerais, podemos testar essa hipótese de duas formas no seu framework.

---

### Abordagem 1: Tratar o Staff como Confundidor (Via Fórmula R)

Podemos injetar a densidade administrativa da escola como uma **covariável de controle** na regressão. Se a sua hipótese estiver certa, quando "descontamos" o tamanho do corpo administrativo, o efeito puramente docente do IQD sobre a nota pode se estabilizar ou até ficar positivo.

Para fazer isso de forma justa e comparável entre escolas de tamanhos diferentes, o ideal é criar uma **razão de staff por aluno** ou **razão de staff por docente** dentro do pipeline de dados, antes de mandar para o R.

#### Alteração no arquivo de teste (`quality.t`):

1. **Adicionar as novas colunas e as variáveis calculadas de staff:**

```perl
# 1. Incluir nos arrays de colunas extras
my @EXTRA_DOCENTE_COLS = qw(
  qt_doc_bas
  qt_doc_bas_esco_sup_grad
  qt_doc_bas_esco_sup_pos_espec
  qt_doc_bas_esco_sup_pos_mestra
  qt_doc_bas_esco_sup_pos_douto
  qt_prof_administrativos     # <-- Nova
  qt_prof_servicos_gerais     # <-- Nova
);

```

2. **Ajustar as fórmulas para o IQD no topo do arquivo:**
Em vez de controlar apenas pela rede (`tp_dependencia`), vamos criar uma métrica de densidade administrativa (ex: `prop_adm = qt_prof_administrativos / qt_doc_bas`) para que o R entenda o inchaço ou robustez da gestão.

```perl
my %formulas = (
  iqd => {
    # Testamos o indicador controlando pela rede e pela proporção de administrativos
    rhs        => 'iqd + factor(tp_dependencia) + prop_adm',
    null_rhs   => 'factor(tp_dependencia) + prop_adm',
    covariates => [qw/tp_dependencia qt_prof_administrativos qt_doc_bas/],
  },
);

```

3. **Injetar o cálculo no loop de montagem do dataset:**

```perl
# Dentro do while (my $school = $schools_rs->next) ...
my %data = $school->get_columns;

# ... (código existente de merge de colunas extras)

# Calcular a variável de controle proporcional
my $total_docs = $data{qt_doc_bas} // 0;
$data{prop_adm} = $total_docs > 0 ? ($data{qt_prof_administrativos} // 0) / $total_docs : 0;

my %scores;
# ... calcula scores do IQD e ISE ...

# Garantir que prop_adm vai para o R como covariável
my %covariates = map { $_ => $data{$_} } (@EXTRA_COVARIATE_COLS, 'prop_adm');

```

---

### Abordagem 2: Refatorar o IQD para expurgar profissionais fora da sala de aula

Se a sua hipótese for confirmada de que esses profissionais especializados estão na verdade na área administrativa, o próprio indicador **IQD está poluído**. Ele está medindo a qualificação do *quadro geral da escola*, e não a qualificação do *professor que está na frente do aluno*.

Para limpar isso, se o seu banco de dados possuir a tabela de **vínculos de docência** (que liga o professor especificamente à turma/sala de aula em atividade de regência), o indicador deveria calcular a proporção de pós-graduados apenas sobre os docentes que possuem **`in_comum_regencia == 1`** (Regência de Classe).

---

### Próximo Passo Teórico

Ao rodar a **Abordagem 1**, o resumo do R vai te dar um diagnóstico precioso através do objeto `coefs` que você já mapeou no script:

```r
coefs <- summary(fit_full)$coefficients

```

Se o coeficiente da variável `prop_adm` for **positivo** e estatisticamente significativo em relação à `nota`, e o `r2_gain` do IQD continuar zerado, teremos a prova matemática: **o que impacta sutilmente a escola é a presença de uma gestão estruturada (`prop_adm`), enquanto a titulação bruta do docente isolado em sala de aula continua sem efeito direto no IDEB.**

Quer aplicar a Abordagem 1 injetando a covariável proporcional de profissionais administrativos no script R para ver como os coeficientes e o $R^2$ reagem?
Para atribuir uma nota de performance aos indicadores, podemos criar um **Índice de Qualidade Estatística (IQE)** pontuado de **0 a 10**. Essa nota ponderará o comportamento do indicador em três dimensões: **Confiabilidade da Associação Bruta ($\rho$)**, **Eficiência Incremental ($R^2\text{ gain}$)** e **Poder de Redução do Erro ($\text{RMSE gain}$)**.

Como o teste é rigoroso, a nota não deve ser apenas uma média linear simples. Indicadores que falharem no piso mínimo de significância ($p \ge 0.10$) ou apresentarem correlação invertida (como o IQD atual com $\rho < 0$) devem sofrer penalizações severas (fator de corte).

---

### Proposta do Algoritmo de Pontuação (IQE)

A nota final será composta por três sub-notas baseadas nos limiares de Cohen (1988):

1. **Nota de Associação ($N_{\rho}$)** - Escala de 0 a 4:
* Baseada no $\vert{}\rho\vert{}$. Se $\rho < 0.10$, nota 0. Se $\rho \ge 0.50$ (efeito grande), nota máxima 4.
* Interpolação linear entre os limiares.


2. **Nota de Ganho Explicativo ($N_{R^2}$)** - Escala de 0 a 4:
* Baseada no $R^2\text{ gain}$. Se $R^2\text{ gain} < 0.01$, nota 0. Se $R^2\text{ gain} \ge 0.25$ (efeito grande), nota máxima 4.


3. **Nota de Impacto no Erro ($N_{\text{RMSE}}$)** - Escala de 0 a 2:
* Mede a utilidade prática do indicador em reduzir o erro do modelo. Um ganho de $\text{RMSE} \ge 10\%$ recebe nota máxima 2.



> **Regra de Corte Absoluta:** Se $p\text{-valor} \ge 0.10$ **OU** se o $\rho$ for negativo (sinal invertido em relação ao esperado), o indicador recebe **Nota Zero automática**, independente do resto.

---

### Implementação no código Perl e R

Podemos embutir essa lógica diretamente dentro do script R e devolvê-la no JSON de resultados. Veja como o trecho do script dentro do seu `quality.t` pode ser atualizado:

#### 1. Injeção da Lógica de Pontuação no Script R:

```r
# ... (dentro do loop 'for (code in codes)' no seu script R) ...

rmse_gain <- if (rmse_null > 0) (rmse_null - rmse_full) / rmse_null else 0

# --- CÁLCULO DA NOTA DE PERFORMANCE (IQE) ---
if (p_val >= 0.10 || rho < 0) {
  # Penalização total se falhar no sinal ou na significância
  score_final <- 0.0
} else {
  # 1. Componente Rho (Máximo 4 pontos)
  # Mapeia de forma linear: rho=0.10 -> 0 pts | rho>=0.50 -> 4 pts
  n_rho <- if (rho < 0.10) { 0 } else { min(4.0, ((rho - 0.10) / 0.40) * 4) }

  # 2. Componente R2 Gain (Máximo 4 pontos)
  # Mapeia de forma linear: r2=0.01 -> 0 pts | r2>=0.25 -> 4 pts
  n_r2 <- if (r2_gain < 0.01) { 0 } else { min(4.0, ((r2_gain - 0.01) / 0.24) * 4) }

  # 3. Componente RMSE Gain (Máximo 2 pontos)
  # Mapeia de forma linear: gain=0% -> 0 pts | gain>=10% -> 2 pts
  n_rmse <- min(2.0, (max(0, rmse_gain) / 0.10) * 2)

  score_final <- round(n_rho + n_r2 + n_rmse, 2)
}
# --------------------------------------------

results[[code]] <- list(
  rho = rho,
  p_val = p_val,
  r2_gain = r2_gain,
  rmse_gain = rmse_gain,
  performance_score = score_final, # <-- Retornando a nota
  formula = f$rhs
)

```

#### 2. Atualização da Tabela de Saída em Perl:

Modifique a exibição da `Text::Table` para incluir a nota, facilitando a tomada de decisão no log do `yath`:

```perl
my $table = Text::Table->new(
  'Indicador', 'Fórmula', 'ρ (Spearman)', 'R² ganho', 'Ganho RMSE %', 'NOTA (0-10)'
);
for my $code (@codes) {
  my $res  = $r_out->{$code};
  my $rho  = defined $res->{rho}       ? sprintf("%.3f", $res->{rho})       : 'NaN';
  my $r2_g = defined $res->{r2_gain}   ? sprintf("%.3f", $res->{r2_gain})   : 'NaN';
  my $gain = defined $res->{rmse_gain} ? sprintf("%.1f%%", $res->{rmse_gain} * 100) : '0.0%';
  my $score= defined $res->{performance_score} ? sprintf("%.2f", $res->{performance_score}) : '0.00';

  $table->add($code, $res->{formula} // $code, $rho, $r2_g, $gain, $score);
}
diag("\n" . $table);

```

---

### Como ficaria o Simulado dos Seus Resultados Atuais:

Se rodássemos o teste de São Paulo com esse sistema de notas, a saída seria visualmente direta para a gestão do projeto:

| Indicador | Fórmula | ρ (Spearman) | R² ganho | Ganho RMSE % | NOTA (0-10) | Status de Implementação |
| --- | --- | --- | --- | --- | --- | --- |
| **ise** | `ise` | 0.343 | 0.136 | 7.1% | **6.95** | **Aprovado:** Pronto para Produção. |
| **iqd** | `iqd + factor(...)` | -0.140 | 0.004 | 0.2% | **0.00** | **Retido:** Sinal invertido / sem ganho. |

A nota **6.95** do `ise` reflete um indicador sólido, saudável e empiricamente defensável para compor os mapas escolares. A nota **0.00** do `iqd` deixa claro que ele precisa voltar para a mesa de desenho (refatoração de variáveis administrativas ou de regência) antes de ser exposto na interface do usuário.
