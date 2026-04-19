-- Get information of an object.
-- Arguments:
--     1) p_object_type
--     2) p_object_name
--     3) p_owner
--     4) p_status
--     5) p_date_from
--     6) p_date_to
WITH all_objects_v AS (
    SELECT
        owner || '.' || replace(object_type, ' ', '_') || '.' || object_name       key,
        owner                                                                      owner,
        object_name                                                                object_name,
        replace(object_type, ' ', '_')                                             object_type,
        CASE WHEN object_type = 'JOB' THEN created ELSE last_ddl_time END          last_update_date,
        status                                                                     status
    FROM
        all_objects obj
    WHERE
        upper(object_type) IN (
            'FUNCTION', 'INDEX', 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'SEQUENCE',
            'SYNONYM', 'TABLE', 'VIEW', 'TRIGGER', 'MATERIALIZED VIEW',
            'JOB', 'SCHEDULE', 'PROGRAM'
        )
        AND object_name not like '%$%'
        AND not exists (
            SELECT 1
            FROM all_constraints cons
            WHERE cons.index_owner = obj.owner AND cons.index_name = obj.object_name AND obj.object_type = 'INDEX'
        )
        AND not exists (
            SELECT 1
            FROM all_objects mv
            WHERE
                mv.object_type = 'MATERIALIZED VIEW'
                AND mv.object_name = obj.object_name
                AND mv.owner = obj.owner
                AND mv.object_id != obj.object_id
        )
)
SELECT
    key,
    owner,
    object_name,
    object_type,
    last_update_date,
    status
FROM
    all_objects_v
WHERE
    upper(object_type) LIKE upper(nvl(:p_object_type, '%'))
    AND upper(owner) LIKE upper(nvl(:p_owner, '%'))
    AND upper(object_name) LIKE upper(nvl(:p_object_name, '%'))
    AND upper(status) LIKE upper(nvl(:p_status, '%'))
    AND trunc(last_update_date) > trunc(:p_date_from)
    AND trunc(last_update_date) <= trunc(:p_date_to)
ORDER BY
    owner, object_type, object_name
