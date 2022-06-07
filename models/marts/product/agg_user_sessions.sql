
{% set event_types = dbt_utils.get_column_values(ref('stg_heroku_postgres_events_events'),'event_type') %}
WITH fct_events AS (
    SELECT * 
    FROM {{ ref('fct_events') }}
    ),


int_session_events_users AS (
    SELECT * 
    FROM {{ ref('int_session_events_users') }}
    ),
    

dim_users AS (
    SELECT * 
    FROM {{ ref('dim_users') }}
    ),


int_session_events_agg AS (
    SELECT 
        session_id,
        user_id,
        count(product_id) as number_products,
        min(created_at_utc) as first_event_time_utc,
        max (created_at_utc) as last_event_time_utc,
        {%- for event_type in event_types %}
        sum({{event_type}}) as {{event_type}}_amount
        {%- if not loop.last %},{% endif -%}
        {% endfor %}
    FROM int_session_events_users

    {{ dbt_utils.group_by(2) }}
    ),


fct_user_sessions AS (
    SELECT
        i.session_id
        ,i.user_id
        ,u.first_name
        ,u.email
        ,number_products
        {%- for event_type in event_types %}
        {{event_type}}_amount
        {%- if not loop.last %},{% endif -%}
        {% endfor %}
        ,i.first_event_time_utc
        ,i.last_event_time_utc
        ,DATEDIFF(MINUTE, cast(i.first_event_time_utc as timestamp), cast(i.last_event_time_utc as timestamp)) AS session_length_minutes

    FROM int_session_events_agg I
    LEFT JOIN dim_users U ON i.user_id = u.user_id
    )

SELECT * FROM fct_user_sessions