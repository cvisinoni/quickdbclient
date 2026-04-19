def nvl(value, *defaults):
    if value is not None:
        return value
    for default in defaults:
        if default is not None:
            return default
    return None


def upper(value):
    if isinstance(value, str):
        return value.upper()
    return value


def lower(value):
    if isinstance(value, str):
        return value.lower()
    return value
