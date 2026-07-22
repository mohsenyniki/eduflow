with source as (
    select distinct
        student_id,
        payload_degree_level   as degree_level,
        payload_funding_source as funding_source
    from {{ source('staging', 'stg_application_submitted') }}
    where student_id is not null
)

select
    student_id,
    degree_level,
    funding_source
from source