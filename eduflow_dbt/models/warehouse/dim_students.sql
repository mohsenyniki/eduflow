with source as (
    select distinct
        student_id,
        payload_full_name           as full_name,
        payload_date_of_birth       as date_of_birth,
        payload_gender              as gender,
        payload_country_of_origin   as country_of_origin,
        payload_degree_level        as degree_level,
        payload_funding_source      as funding_source,
        payload_visa_type           as visa_type,
        payload_program             as program,
        payload_school              as school
    from {{ source('staging', 'stg_application_submitted') }}
    where student_id is not null
)

select
    student_id,
    full_name,
    date_of_birth,
    gender,
    country_of_origin,
    degree_level,
    funding_source,
    visa_type,
    program,
    school
from source