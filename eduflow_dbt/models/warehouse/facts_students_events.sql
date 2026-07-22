with applications as (
    select
        event_id,
        student_id,
        event_timestamp,
        'application_submitted' as event_type,
        payload_program         as program_name,
        payload_school          as school_name,
        payload_degree_level    as degree_level,
        payload_funding_source  as funding_source,
        payload_term            as term
    from {{ source('staging', 'stg_application_submitted') }}
),

documents as (
    select
        event_id,
        student_id,
        event_timestamp,
        'document_submitted'    as event_type,
        null                    as program_name,
        null                    as school_name,
        null                    as degree_level,
        null                    as funding_source,
        null                    as term
    from {{ source('staging', 'stg_document_submitted') }}
),

visa as (
    select
        event_id,
        student_id,
        event_timestamp,
        'visa_status_change'    as event_type,
        null                    as program_name,
        null                    as school_name,
        null                    as degree_level,
        null                    as funding_source,
        null                    as term
    from {{ source('staging', 'stg_visa_status_change') }}
),

enrollment as (
    select
        event_id,
        student_id,
        event_timestamp,
        'enrollment_confirmed'  as event_type,
        payload_program         as program_name,
        null                    as school_name,
        null                    as degree_level,
        null                    as funding_source,
        payload_term            as term
    from {{ source('staging', 'stg_enrollment_confirmed') }}
),

registration as (
    select
        event_id,
        student_id,
        event_timestamp,
        'term_registration'     as event_type,
        null                    as program_name,
        null                    as school_name,
        null                    as degree_level,
        null                    as funding_source,
        payload_term            as term
    from {{ source('staging', 'stg_term_registration') }}
),

opt_cpt as (
    select
        event_id,
        student_id,
        event_timestamp,
        'opt_cpt_request'       as event_type,
        null                    as program_name,
        null                    as school_name,
        null                    as degree_level,
        null                    as funding_source,
        null                    as term
    from {{ source('staging', 'stg_opt_cpt_request') }}
),

status as (
    select
        event_id,
        student_id,
        event_timestamp,
        'status_change'         as event_type,
        null                    as program_name,
        null                    as school_name,
        null                    as degree_level,
        null                    as funding_source,
        null                    as term
    from {{ source('staging', 'stg_status_change') }}
),

graduation as (
    select
        event_id,
        student_id,
        event_timestamp,
        'graduation'            as event_type,
        payload_program         as program_name,
        null                    as school_name,
        payload_degree_level    as degree_level,
        null                    as funding_source,
        payload_term            as term
    from {{ source('staging', 'stg_graduation') }}
),

all_events as (
    select * from applications
    union all
    select * from documents
    union all
    select * from visa
    union all
    select * from enrollment
    union all
    select * from registration
    union all
    select * from opt_cpt
    union all
    select * from status
    union all
    select * from graduation
)

select
    e.event_id,
    e.student_id,
    md5(coalesce(e.program_name, '') || '|' || coalesce(e.school_name, '')) as program_id,
    to_char(date_trunc('day', e.event_timestamp), 'YYYYMMDD')               as time_id,
    e.event_type,
    e.event_timestamp,
    e.degree_level,
    e.funding_source,
    e.term
from all_events e
where e.event_id is not null