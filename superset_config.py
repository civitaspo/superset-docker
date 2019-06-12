import os


def envvar(var_name, default=None):
    try:
        return os.environ[var_name]
    except KeyError:
        if default:
            return default
        raise EnvironmentError(f'The environment variable {var_name} is missing.')


POSTGRES_USER = envvar('POSTGRES_USER')
POSTGRES_PASSWORD = envvar('POSTGRES_PASSWORD')
POSTGRES_HOST = envvar('POSTGRES_HOST')
POSTGRES_PORT = envvar('POSTGRES_PORT')
POSTGRES_DB = envvar('POSTGRES_DB')

# The SQLAlchemy connection string.
SQLALCHEMY_DATABASE_URI = f'postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}'

REDIS_HOST = envvar('REDIS_HOST')
REDIS_PORT = envvar('REDIS_PORT')

CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 60 * 60 * 24, # 1 day default (in secs)
    'CACHE_KEY_PREFIX': 'superset_results',
    'CACHE_REDIS_URL': f'redis://{REDIS_HOST}:{REDIS_PORT}/0',
}


class CeleryConfig(object):
    BROKER_URL = f'redis://{REDIS_HOST}:{REDIS_PORT}/0'
    CELERY_IMPORTS = ('superset.sql_lab', )
    CELERY_RESULT_BACKEND = f'redis://{REDIS_HOST}:{REDIS_PORT}/1'
    CELERY_ANNOTATIONS = {'tasks.add': {'rate_limit': '10/s'}}
    CELERY_TASK_PROTOCOL = 1


CELERY_CONFIG = CeleryConfig

