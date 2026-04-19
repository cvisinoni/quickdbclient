DECLARE
    v_ddl                  CLOB;
    v_max_length           NUMBER;
    v_columns_count        NUMBER;
    v_index                NUMBER;
    v_column_name          VARCHAR2(256);
BEGIN
    if :p_object_type != 'TABLE' then
        raise_application_error(-20000, 'Object type is not TABLE');
    end if;

    dbms_lob.createtemporary(v_ddl, true);

    -- Max length
    SELECT greatest(max(length(column_name)) + 6, 56), count(1)
    INTO v_max_length, v_columns_count
    FROM all_tab_columns
    WHERE owner = UPPER(:p_owner)
          AND table_name = UPPER(:p_object_name);

    -- Check table exists
    if v_columns_count = 0 then
        raise_application_error(-20000, 'Table ' || :p_owner || '.' || :p_object_name || ' does not exist');
    end if;

    -- Create
    dbms_lob.append(v_ddl, 'CREATE TABLE ' || :p_object_name || ' (');
    v_index := 0;

    for rec in (
        SELECT
            column_name,
            data_type,
            data_length,
            data_precision,
            data_scale,
            nullable,
            data_default
        FROM
            all_tab_columns
        WHERE
            owner = UPPER(:p_owner)
            AND table_name = UPPER(:p_object_name)
        ORDER BY column_id
    ) loop
        -- Counter
        v_index := v_index + 1;

        -- Name
        v_column_name := '"' || rec.column_name || '"';
        dbms_lob.append(v_ddl, CHR(10) || '    ' || rpad(v_column_name, v_max_length) || rec.data_type);

        -- Datatype
        if rec.data_type IN ('VARCHAR2', 'CHAR') then
            dbms_lob.append(v_ddl, '(' || rec.data_length || ')');
        elsif rec.data_type IN ('NUMBER') then
            if rec.data_precision is not null then
                dbms_lob.append(v_ddl, '(' || rec.data_precision);
                if rec.data_scale is not null then
                    dbms_lob.append(v_ddl, ',' || rec.data_scale);
                end if;
                dbms_lob.append(v_ddl, ')');
            end if;
        end if;

        -- Default
        if rec.data_default is not null then
            dbms_lob.append(v_ddl, ' DEFAULT ' || trim(rec.data_default));
        end if;

        -- Nullable
        if rec.nullable = 'N' then
            dbms_lob.append(v_ddl, ' NOT NULL ENABLE');
        end if;

        -- Comma
        if v_index < v_columns_count then
            dbms_lob.append(v_ddl, ',');
        end if;

    end loop;

    -- Constraints
    for rec in (
        WITH base AS (
            SELECT
                c.owner,
                c.table_name,
                c.constraint_name,
                c.constraint_type,
                c.status,
                c.deferrable,
                c.deferred,
                c.delete_rule,
                c.r_owner,
                c.r_constraint_name
            FROM
                all_constraints c
            WHERE
                c.status = 'ENABLED'
                AND c.owner = UPPER(:p_owner)
                AND c.table_name = UPPER(:p_object_name)
                AND c.constraint_type IN ('P', 'U', 'R')
        ),
        local_cols AS (
            SELECT
                owner,
                constraint_name,
                LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_name) AS column_list
            FROM
                all_cons_columns
            WHERE
                (owner, constraint_name) IN (SELECT owner, constraint_name FROM base)
            GROUP BY owner, constraint_name
        ),
        ref_info AS (
            -- Referenced constraint info (for FK): referenced table
            SELECT
                rc.owner AS ref_owner,
                rc.table_name AS ref_table,
                rc.constraint_name AS ref_constraint_name
            FROM
                all_constraints rc
            WHERE
                (rc.owner, rc.constraint_name) IN (SELECT b.r_owner, b.r_constraint_name FROM base b WHERE b.constraint_type = 'R')
        ),
        ref_cols AS (
            -- Referenced columns (ordered by referenced constraint position)
            SELECT
              rcc.owner, rcc.constraint_name,
              LISTAGG(rcc.column_name, ', ') WITHIN GROUP (ORDER BY rcc.column_name) AS ref_column_list
            FROM
                all_cons_columns rcc
            WHERE (rcc.owner, rcc.constraint_name) IN (SELECT r_owner, r_constraint_name FROM base WHERE constraint_type = 'R')
            GROUP BY rcc.owner, rcc.constraint_name
        ),
        ddl AS (
            SELECT
                b.constraint_name,
                b.constraint_type,
                CASE b.constraint_type
                    WHEN 'P' THEN 'CONSTRAINT ' || b.constraint_name || ' PRIMARY KEY (' || lc.column_list || ')'
                    WHEN 'U' THEN 'CONSTRAINT ' || b.constraint_name || ' UNIQUE (' || lc.column_list || ')'
                    WHEN 'R' THEN 'CONSTRAINT ' || b.constraint_name || ' FOREIGN KEY (' || lc.column_list || ') REFERENCES ' ||
                        CASE WHEN b.r_owner IS NOT NULL AND b.r_owner <> b.owner THEN b.r_owner || '.' ELSE '' END || ri.ref_table || ' (' || rf.ref_column_list || ')' ||
                        CASE WHEN b.delete_rule = 'CASCADE' THEN ' ON DELETE CASCADE'
                             WHEN b.delete_rule = 'SET NULL' THEN ' ON DELETE SET NULL'
                             ELSE '' END ||
                        CASE WHEN b.status = 'ENABLED' THEN ' ENABLE' ELSE ' DISABLE' END
                    END AS constraint_ddl
            FROM
                base b
                JOIN local_cols lc ON lc.owner = b.owner AND lc.constraint_name = b.constraint_name
                LEFT JOIN ref_info ri ON b.constraint_type = 'R' AND ri.ref_owner = b.r_owner AND ri.ref_constraint_name = b.r_constraint_name
                LEFT JOIN ref_cols rf ON b.constraint_type = 'R' AND rf.owner = b.r_owner AND rf.constraint_name = b.r_constraint_name
        )
        SELECT
          constraint_ddl,
          ROW_NUMBER() OVER (ORDER BY CASE constraint_type WHEN 'P' THEN 1 WHEN 'U' THEN 2 WHEN 'R' THEN 3 END, constraint_name) AS rnum,
          COUNT(*) OVER () AS tot
        FROM
          ddl
        ORDER BY
          rnum
    ) loop
        -- Sep line
        if rec.rnum = 1 then
            dbms_lob.append(v_ddl, ',' || CHR(10) || '    --');
        end if;

        -- constraint_ddl
        dbms_lob.append(v_ddl, CHR(10) || '    ' || rec.constraint_ddl);

        -- Comma
        if rec.rnum < rec.tot then
            dbms_lob.append(v_ddl, ',');
        end if;
    end loop;

    -- Close
    dbms_lob.append(v_ddl, CHR(10) || ');');

    :x_result := v_ddl;
END;