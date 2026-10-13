CREATE TABLE pcx__qa_union AS 
SELECT COUNT(*) AS cnt, 'pcx__qa_study_period_bounds' AS test 
 FROM pcx__qa_study_period_bounds
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__qa_study_population_utilization' AS test 
 FROM pcx__qa_study_population_utilization