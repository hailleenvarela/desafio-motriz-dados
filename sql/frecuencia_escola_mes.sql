-- 1. Frequência por Escola e Mês
-- Origem: Silver consolidada, já tratada pelo Notebook 01.
-- Destino: motriz_gold.frequencia_escola_mes

SELECT
  rede,
  LPAD(CAST(codigo_inep AS STRING), 8, '0') AS codigo_inep,
  mes,
  COUNT(*) AS registros_validos,
  SUM(presencas) AS presencas,
  ROUND(SAFE_DIVIDE(SUM(presencas), COUNT(*)) * 100, 2) AS frequencia_pct
FROM
  `motriz-desafio-dados.motriz_silver.frequencia_todas_redes`
GROUP BY
  rede, codigo_inep, mes
ORDER BY
  rede, codigo_inep, mes;