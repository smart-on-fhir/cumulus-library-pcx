CREATE TABLE pcx__cohort_dx_atrt AS 
SELECT DISTINCT * FROM 
 pcx__cohort_study_population_dx , 
pcx__valueset_dx_atrt
WHERE
pcx__cohort_study_population_dx.dx_code = pcx__valueset_dx_atrt.code and 
pcx__cohort_study_population_dx.dx_system = pcx__valueset_dx_atrt.system