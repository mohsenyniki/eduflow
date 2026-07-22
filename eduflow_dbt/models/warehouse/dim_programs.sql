with source as (
    select distinct
        payload_program  as program_name,
        payload_school   as school_name
    from {{ source('staging', 'stg_application_submitted') }}
    where payload_program is not null
)

select
    md5(program_name || '|' || school_name) as program_id,
    program_name,
    school_name
from source