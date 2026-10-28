# Case Motriz — Pipeline de frequência escolar

Desafio técnico de Engenharia de Dados Pleno. Solução executada no Google Colab e BigQuery Sandbox, sem serviços pagos.

## Arquivos principais

- `01_ingestao_tratamento_validacao_motriz_v3_manifesto.ipynb`: ingestão das fontes, normalização, validações, regras R1–R10, relatório de qualidade e arquivos de resultados.
- `02_carga_modelagem_bigquery_motriz_corrigido.ipynb`: carga idempotente no BigQuery, validação da presença das três redes e geração das tabelas Gold.
- `sql/`: consultas BigQuery Standard SQL.
- `resultados/`: arquivos exigidos pelo enunciado e relatório de qualidade.
- `dados/`: arquivos de entrada. Não versionar dados brutos se houver risco de exposição; no repositório público, manter somente código e documentação.

## Como executar no Google Colab

1. Faça upload dos dados no Notebook 01: `calendario_letivo_2026.csv`, `rede_a_dump.sql`, `alunos_rede_b.ndjson` e `rede_c.zip` contendo os 12 CSVs.
2. Execute o Notebook 01 do início ao fim. Ele cria as pastas `bronze/`, `silver/` e `resultados/` no Google Drive, além de `pipeline_manifest.json` somente após concluir a execução com as três redes e os três resultados obrigatórios.
3. Revise `resultados/relatorio_qualidade.md`, `resultados/resumo_qualidade.csv` e `resultados/motivos_descarte.csv`.
4. Abra o Notebook 02 e execute-o do início ao fim. Informe o Project ID do seu projeto Google Cloud e autorize a conta Google quando solicitado.
5. Confirme que a camada Silver e cada tabela Gold contêm as redes A, B e C. O Notebook 02 falha deliberadamente se o manifesto estiver ausente, as contagens forem divergentes ou uma rede não chegar à camada analítica.

### Região BigQuery

O notebook está configurado para `southamerica-east1` (São Paulo). A localização do dataset é imutável após sua criação. Para evitar colisão com os datasets `motriz_bronze`, `motriz_silver` e `motriz_gold` que podem ter sido criados anteriormente em `US`, esta versão usa os nomes novos `motriz_bronze_br`, `motriz_silver_br` e `motriz_gold_br`. Os datasets antigos não são apagados.

## Arquitetura

- **Bronze (`motriz_bronze_br`)**: tabelas extraídas do dump relacional da Rede A, presenças expandidas do NDJSON da Rede B e os 12 CSVs originais da Rede C.
- **Silver (`motriz_silver_br`)**: registros de frequência padronizados e válidos, com uma linha por aluno/turma/dia letivo e campos tipados. A tabela principal é particionada por `data` e clusterizada por `rede`, `codigo_inep` e `turma`.
- **Gold (`motriz_gold_br`)**: `frequencia_escola_mes`, `frequencia_turma_mes` e `alunos_abaixo_75`, calculadas em BigQuery Standard SQL.

As cargas usam `WRITE_TRUNCATE` para substituir cada tabela com o conteúdo da execução atual, evitando duplicação em reexecuções. A tabela consolidada Silver é sempre reconstruída a partir dos três arquivos por rede; o manifesto evita reaproveitar silenciosamente uma execução parcial antiga.

## Integração das fontes e identificação das escolas

### Rede A — PostgreSQL

O dump em texto é lido pelos blocos `COPY` sem precisar subir um servidor PostgreSQL. A frequência é relacionada ao cadastro de alunos por `aluno_id`, à matrícula por `aluno_id + turma_id`, à turma por `turma_id` e à escola por `escola_id`. O código INEP e o nome da escola vêm do cadastro de escola. A validação descarta registros com aluno/turma/escola não encontrados. No dump fornecido há referências órfãs e registros sem presença informada; eles são contabilizados no relatório de qualidade.

### Rede B — NDJSON

Cada documento de aluno é expandido em matrícula e presença. O INEP, o nome da escola e os dados da turma vêm do objeto aninhado em cada matrícula. Datas no formato estendido do MongoDB são convertidas para datas ISO. Os dados de responsáveis/telefone são excluídos porque não são necessários para os indicadores.

### Rede C — CSV

Os 12 CSVs são lidos com tentativas de codificação e separador, e cabeçalhos diferentes são mapeados para um esquema comum. Os registros da Rede C preservam o INEP e o nome de escola informados nas próprias planilhas.

Não existe um cadastro mestre compartilhado de escolas entre as três redes no material fornecido. Por isso, a integração **não** tenta juntar escolas diferentes somente pelo nome. Os indicadores são agrupados por `rede + codigo_inep` (e turma quando aplicável), evitando colisões entre códigos de turma iguais em escolas distintas. Na Rede A, a existência da escola é verificada por relacionamento real no dump; em B e C, a validação de escola é estrutural, usando INEP de oito dígitos e nome preenchido. Essa limitação deve ser considerada na interpretação.

## Regras de negócio

- **R1 — Período e calendário:** somente 03/08/2026 a 30/10/2026, inclusive, e datas com `dia_letivo = S`.
- **R2 — Registro válido:** exige data, aluno, turma, escola e situação identificados.
- **R3 — Frequência:** presença = 1; falta e falta justificada = 0 no numerador, mas contam no denominador; situação ausente/desconhecida é descartada.
- **R4 — Identidade:** nome normalizado (caixa, acentos e espaços) + data de nascimento, dentro da própria rede. O identificador analítico é um hash estável dessa chave.
- **R5 — Unicidade:** deduplicação por rede, identidade do aluno, INEP, turma normalizada e data.
- **R6 — Matrícula:** quando há início/fim informados, a aula deve estar dentro do intervalo inclusivo. A fonte A fornece início, mas não fim; B fornece ambos; C não fornece vigência.
- **R7 — INEP:** normalizado para oito dígitos.
- **R8 — Agregação:** soma das presenças dividida pela soma dos registros válidos, nunca média de percentuais.
- **R9 — Busca ativa:** frequência estritamente inferior a 75,00% no período completo, somando todas as matrículas da pessoa dentro da mesma rede.
- **R10 — Mês:** derivado da data da aula em `AAAA-MM`.

## Entregáveis esperados

- `resultados/frequencia_escola_mes.csv`
- `resultados/frequencia_turma_mes.csv`
- `resultados/alunos_abaixo_75.csv`
- `resultados/relatorio_qualidade.md`

Os três CSVs mantêm a ordem e os nomes das colunas obrigatórias do enunciado. Frequência é exportada com duas casas decimais.

## Qualidade e limitações conhecidas

- Os motivos de descarte podem se sobrepor; o total de registros descartados conta cada registro uma única vez.
- A Rede A contém referências órfãs de aluno/escola e chamadas sem situação. A Rede B contém situações ausentes/desconhecidas. A Rede C tem variações de cabeçalho, separador, codificação e algumas linhas com situação inválida. O relatório de qualidade registra os descartes.
- A validação independente de existência de escola/turma só é possível na Rede A, porque não foi fornecido cadastro mestre para B/C.
- O pipeline precisa ser executado novamente do início ao fim após substituir qualquer fonte; não considere outputs antigos como finais.
- O BigQuery Sandbox tem limites próprios de armazenamento/consulta; o projeto não depende de serviços pagos.



