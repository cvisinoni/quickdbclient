from ..database import Database
from ..utils import upper, nvl
from ..logger import log
from .ddl import database_object_classes, DatabaseObject
from oracledb import Connection
from datetime import datetime
import oracledb


# https://python-oracledb.readthedocs.io/en/latest/user_guide/lob_data.html#fetching-lobs-as-strings-and-bytes
oracledb.defaults.fetch_lobs = False


class OracleDatabase(Database):

    def __init__(self, properties):
        super().__init__(properties)
        self._wallet_location = self._properties.get('wallet_location')
        self._wallet_password = self._properties.get('wallet_password')
        self._config_dir = self._properties.get('config_dir')
        self._dsn = self._properties.get('dsn')
        self._host = self._properties.get('host')
        self._port = self._properties.get('port')
        self._service_name = self._properties.get('service_name')
        self._user = self._properties.get('user')
        self._password = self._properties.get('password')
        self._instantclient = self._properties.get('instantclient')
        self._connection: Connection | None = None

    def connect(self):
        if self._wallet_location is not None:
            self._connection = oracledb.connect(
                wallet_location=self._wallet_location,
                wallet_password=self._wallet_password,
                config_dir=self._config_dir,
                dsn=self._dsn,
                user=self._user,
                password=self._password
            )
        else:
            if self._instantclient:
                oracledb.init_oracle_client(lib_dir=self._instantclient)
            self._connection = oracledb.connect(
                host=self._host,
                port=self._port,
                service_name=self._service_name,
                user=self._user,
                password=self._password
            )
        log.info(f'connection established to {self._dsn} as {self._user}. ' +
                 f'Database version: {self._connection.version}')

    def is_healthy(self):
        if self._connection is not None:
            return self._connection.is_healthy()
        return False

    @property
    def connection(self) -> Connection:
        return super().connection

    @property
    def version(self):
        return self.connection.version

    def execute(self, sql: str, parameters: dict):
        self.debug_query(sql, parameters)
        cursor = self.connection.cursor()
        return cursor.execute(sql, parameters=parameters)

    def select(self, sql: str, parameters: dict = None):
        cursor = self.execute(sql, parameters)
        names = [d[0].lower() for d in cursor.description]
        for row in cursor:
            result = dict(zip(names, row))
            yield result

    def select_sysdate(self):
        return self.select_one_value("SELECT sysdate FROM dual")

    def select_all_objects(
            self,
            object_type: str = None,
            object_name: str = None,
            owner: str = None,
            status: str = None,
            date_from: datetime = datetime(year=1955, month=11, day=5),
            date_to: datetime = datetime.now()
    ):
        owner = nvl(owner, self._user)
        sql = self.get_sql_from_file('ddl/all_objects.sql')
        parameters = dict(
            p_object_type=upper(object_type),
            p_object_name=upper(object_name),
            p_owner=upper(owner),
            p_status=upper(status),
            p_date_from=date_from,
            p_date_to=date_to
        )
        return self.select(sql, parameters)

    def select_object_ddl(self, owner, object_type, object_name):
        cls = database_object_classes.get(object_type, DatabaseObject)
        instance = cls(owner, object_type, object_name)
        cur = self.connection.cursor()
        var = cur.var(oracledb.DB_TYPE_CLOB)
        sql = self.get_sql_from_file(instance.resource)
        parameters = dict(
            p_owner=owner,
            p_object_type=instance.object_type_parameter,
            p_object_name=object_name,
            x_result=var
        )
        cur.execute(sql, **parameters)
        instance.content = var.getvalue().read()
        instance.fix_content()
        return instance.content
