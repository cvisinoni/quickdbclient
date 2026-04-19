DECLARE
BEGIN
    :x_result := dbms_metadata.get_ddl(:p_object_type, :p_object_name, :p_owner);
END;