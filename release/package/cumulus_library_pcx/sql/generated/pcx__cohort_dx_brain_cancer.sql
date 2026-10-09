CREATE TABLE pcx__cohort_dx_brain_cancer AS 
SELECT DISTINCT * FROM 
 pcx__cohort_study_population_dx , 
pcx__valueset_dx_brain_cancer
WHERE
pcx__cohort_study_population_dx.dx_code = pcx__valueset_dx_brain_cancer.code and 
pcx__cohort_study_population_dx.dx_system = pcx__valueset_dx_brain_cancer.system