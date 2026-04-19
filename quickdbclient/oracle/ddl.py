from ..logger import log
import re


class DatabaseObject:

    def __init__(self, owner, object_type, object_name):
        self.owner = owner
        self.object_type = object_type
        self.object_name = object_name
        self.content = ''

    @property
    def object_type_parameter(self):
        return self.object_type

    @property
    def resource(self):
        return 'ddl/object.sql'

    def fix_content(self):
        self.content = self.content.strip()


class Table(DatabaseObject):

    @property
    def resource(self):
        return 'ddl/table.sql'


class View(DatabaseObject):

    def fix_content(self):
        super().fix_content()
        self.content = re.sub(fr'(CREATE [\S ]+ VIEW "{self.owner}"."{self.object_name}") .+( AS *\r?\n)',
                              r'\1\2', self.content)
        self.content = re.sub(r'(\r?\n {2}SELECT)', r'\n    SELECT', self.content)


class Package(DatabaseObject):

    @property
    def object_type_parameter(self):
        return 'PACKAGE_SPEC'


class PackageBody(DatabaseObject):

    pass


class Function(DatabaseObject):

    pass


class Procobj(DatabaseObject):

    @property
    def object_type_parameter(self):
        return 'PROCOBJ'

    def fix_content(self):
        super().fix_content()
        self.content = re.sub(r'dbms_scheduler\.enable.+;', r'', self.content)


class Trigger(DatabaseObject):

    def fix_content(self):
        super().fix_content()
        self.content = re.sub(r'ALTER TRIGGER.+$', r'', self.content)


class Sequence(DatabaseObject):

    def fix_content(self):
        super().fix_content()
        m = re.match(r'.+MINVALUE (\d+)', self.content)
        if m:
            self.content = re.sub(r'START WITH \d+', f'START WITH {m.group(1)}', self.content)


class Index(DatabaseObject):

    def fix_content(self):
        super().fix_content()
        m = re.match(r'(CREATE .*INDEX [\s\S]*)PCTFREE', self.content)
        if m:
            self.content = m.group(1).strip() + ';'
        else:
            log.warning(f'index {self.object_name}: unknown format')


database_object_classes = {
    'TABLE': Table,
    'VIEW': View,
    'PACKAGE': Package,
    'PACKAGE_BODY': PackageBody,
    'FUNCTION': Function,
    'TRIGGER': Trigger,
    'SEQUENCE': Sequence,
    'INDEX': Index,
    'JOB': Procobj,
    'PROGRAM': Procobj,
    'SCHEDULE': Procobj,
}
