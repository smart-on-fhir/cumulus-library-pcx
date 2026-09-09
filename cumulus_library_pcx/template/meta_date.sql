CREATE  TABLE   {{ prefix }}__meta_date AS
with study_period as
(
    select
        min(period_start_day)   as min_date,
        max(period_end_day)     as max_date
    FROM
        {{ prefix }}__cohort_study_period
)
select  min_date,
        -- CASE rather than LEAST because the engines disagree on NULL
        -- handling when max_date is NULL
        CASE WHEN max_date > CURRENT_DATE
             THEN CURRENT_DATE
             ELSE max_date
        END                                 as max_date
FROM    study_period;
