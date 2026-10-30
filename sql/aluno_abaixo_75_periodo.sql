-- 3. Alunos abaixo de 75% no período completo
-- Agrupa pelo identificador de aluno produzido na Silver dentro de cada rede.
-- Destino: motriz_gold_br.alunos_abaixo_75


WITH frequencia_aluno AS (
  SELECT
    rede,
    identificador_aluno,
    ARRAY_AGG(nome_aluno IGNORE NULLS ORDER BY data LIMIT 1)[SAFE_OFFSET(0)] AS nome_aluno,
    ARRAY_AGG(data_nascimento IGNORE NULLS ORDER BY data LIMIT 1)[SAFE_OFFSET(0)] AS data_nascimento,
    COUNT(*) AS registros_validos,
    SUM(presencas) AS presencas,
    ROUND(SAFE_DIVIDE(SUM(presencas), COUNT(*)) * 100, 2) AS frequencia_pct
  FROM
    `motriz-desafio-dados.motriz_silver.frequencia_todas_redes`
  GROUP BY
    rede, identificador_aluno
)
SELECT
  rede,
  identificador_aluno,
  nome_aluno,
  data_nascimento,
  registros_validos,
  presencas,
  frequencia_pct
FROM frequencia_aluno
WHERE frequencia_pct < 75.00
ORDER BY rede, frequencia_pct, nome_aluno;