CREATE TABLE pcx__cohort_lab_alt AS 
SELECT DISTINCT * FROM 
 pcx__cohort_study_population_lab , 
pcx__valueset_lab_alt
WHERE
pcx__cohort_study_population_lab.lab_observation_code = pcx__valueset_lab_alt.code and 
pcx__cohort_study_population_lab.lab_observation_system = pcx__valueset_lab_alt.system