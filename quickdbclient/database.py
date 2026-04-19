from .logger import log
from importlib import resources


class Database:

    def __init__(self, properties: dict):
        self._properties = properties
        self._connection = None

    def connect(self):
        raise NotImplementedError("connect method must be implemented by subclass")

    def is_healthy(self):
        return self._connection is not None

    @property
    def connection(self):
        if not self.is_healthy():
            self.connect()
        return self._connection

    @property
    def version(self):
        raise NotImplementedError("version property must be implemented by subclass")

    def get_sql_from_file(self, resource: str, encoding='utf-8'):
        package = f"{self.__class__.__module__.rsplit('.', 1)[0]}.sql"
        if resources.is_resource(package, resource):
            return resources.read_text(package, resource, encoding=encoding)
        parent_package = f"{self.__class__.__module__.rsplit('.', 1)[0]}.sql"
        if resources.is_resource(parent_package, resource):
            return resources.read_text(parent_package, resource, encoding=encoding)
        raise FileNotFoundError(f"Resource '{resource}' not found in package '{package}'")

    def debug_query(self, sql: str, parameters: dict):
        if self._properties.get('debugsql', True):
            log.debug('')
            log.debug(f'call query: {sql}')
            if parameters is not None:
                for key, value in parameters.items():
                    log.debug(f'    {key}: {value}')

    def execute(self, sql: str, parameters: dict):
        raise NotImplementedError("execute method must be implemented by subclass")

    def select(self, sql: str, parameters: dict = None):
        raise NotImplementedError("select method must be implemented by subclass")

    def select_one_row(self, sql: str, parameters: dict = None):
        for row in self.select(sql, parameters):
            return row
        return None

    def select_one_value(self, sql: str, parameters: dict = None):
        for value in self.select_one_row(sql, parameters).values():
            return value
        return None
