import logging
from fastapi import FastAPI, Depends, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from .config import settings
from .routers import flights
from .db import conn_dependency
from .logging_config import setup_logging

# Initialize Logging
setup_logging()
logger = logging.getLogger(__name__)

def create_app() -> FastAPI:
    app = FastAPI(title="Flight Operations API", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ALLOW_ORIGINS,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.error(f"Unhandled error on {request.url.path}: {str(exc)}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"message": "An internal server error occurred."},
        )

    @app.get("/healthz")
    def health(conn = Depends(conn_dependency)):
        conn.execute(text("SELECT 1"))
        return {"status": "ok"}

    app.include_router(flights.router)
    return app

app = create_app()


if __name__ == "__main__":
    import uvicorn
    # Log level is passed here to ensure Uvicorn internal logs respect settings
    uvicorn.run(
        "app.main:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True,
        log_config=None # We use our own config
    )
