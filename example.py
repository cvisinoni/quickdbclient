from quickdbclient.oracle import OracleDatabase
import logging


logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')


if __name__ == '__main__':
    db = OracleDatabase(dict(
        debugsql=True
    ))
    logging.debug(db.version)
