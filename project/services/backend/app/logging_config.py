import logging
import json
from logging.config import dictConfig
from .config import settings

class EndpointLogFilter(logging.Filter):
    """Filters out specific endpoints from the access logs."""
    def __init__(self, excluded_endpoints: list[str] = None):
        super().__init__()
        self.excluded_endpoints = excluded_endpoints or []

    def filter(self, record: logging.LogRecord) -> bool:
        # uvicorn.access logs store the path in the first argument of the message args
        if record.args and len(record.args) >= 3:
            path = record.args[2]
            return not any(path.startswith(e) for e in self.excluded_endpoints)
        return True

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging."""
    def format(self, record: logging.LogRecord) -> str:
        log_record = {
            "level": record.levelname,
            "timestamp": self.formatTime(record, self.datefmt),
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            log_record["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_record)

def setup_logging():
    logging_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "json": {
                "()": JSONFormatter,
            },
            "standard": {
                "format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
            },
        },
        "filters": {
            "health_filter": {
                "()": EndpointLogFilter,
                "excluded_endpoints": ["/healthz", "/metrics"],
            }
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": "json" if settings.ENV == "prod" else "standard",
            },
            "access_handler": {
                "class": "logging.StreamHandler",
                "formatter": "json" if settings.ENV == "prod" else "standard",
                "filters": ["health_filter"],
            },
        },
        "loggers": {
            "": {"handlers": ["console"], "level": settings.LOG_LEVEL},
            "uvicorn.error": {"level": "INFO"},
            "uvicorn.access": {
                "handlers": ["access_handler"],
                "level": "INFO",
                "propagate": False,
            },
            "sqlalchemy.engine": {
                "level": "WARNING" if not settings.ECHO_SQL else "INFO",
            },
        },
    }
    dictConfig(logging_config)
