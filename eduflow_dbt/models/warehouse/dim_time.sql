with all_timestamps as (
    select event_timestamp from {{ source('staging', 'stg_application_submitted') }}
    union
    select event_timestamp from {{ source('staging', 'stg_document_submitted') }}
    union
    select event_timestamp from {{ source('staging', 'stg_visa_status_change') }}
    union
    select event_timestamp from {{ source('staging', 'stg_enrollment_confirmed') }}
    union
    select event_timestamp from {{ source('staging', 'stg_term_registration') }}
    union
    select event_timestamp from {{ source('staging', 'stg_opt_cpt_request') }}
    union
    select event_timestamp from {{ source('staging', 'stg_status_change') }}
    union
    select event_timestamp from {{ source('staging', 'stg_graduation') }}
),

unique_dates as (
    select distinct
        date_trunc('day', event_timestamp) as event_date
    from all_timestamps
    where event_timestamp is not null
)

select
    to_char(event_date, 'YYYYMMDD')                    as time_id,
    event_date                                          as full_date,
    extract(year from event_date)::int                  as year,
    extract(month from event_date)::int                 as month,
    extract(day from event_date)::int                   as day,
    to_char(event_date, 'Day')                          as day_of_week,
    extract(quarter from event_date)::int               as quarter,
    case
        when extract(month from event_date) between 1 and 4
            then 'Spring ' || extract(year from event_date)::text
        when extract(month from event_date) between 5 and 7
            then 'Summer ' || extract(year from event_date)::text
        when extract(month from event_date) between 8 and 12
            then 'Fall ' || extract(year from event_date)::text
    end                                                 as academic_term,
    case
        when extract(dow from event_date) in (0, 6) then true
        else false
    end                                                 as is_weekend
from unique_dates
order by event_date