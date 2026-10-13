CREATE TABLE pcx__cohort_lab_ast AS 
SELECT DISTINCT * FROM 
 pcx__cohort_study_population_lab , 
pcx__valueset_lab_ast
WHERE
pcx__cohort_study_population_lab.lab_observation_code = pcx__valueset_lab_ast.code and 
pcx__cohort_study_population_lab.lab_observation_system = pcx__valueset_lab_ast.system