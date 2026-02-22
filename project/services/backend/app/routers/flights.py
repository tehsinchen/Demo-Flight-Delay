import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.engine import Connection
import pandas as pd
from ..db import conn_dependency
from ..utils.data_processing import delay_histogram, flight_data

router = APIRouter(prefix="/api", tags=["flights"])
logger = logging.getLogger(__name__)

@router.get("/flights/{airport_code}")
def get_flights(airport_code: str, conn: Connection = Depends(conn_dependency)):
    logger.info(f"Fetching flights for airport: {airport_code}")
    query = """
        SELECT airline_name, flight_no
        FROM vw_airport_airlines_flights
        WHERE airport_code = :code
        ORDER BY airline_name, flight_no
    """
    result = conn.execute(text(query), {"code": airport_code})
    return flight_data(result)

@router.get("/histogram/{airport_code}/{airline_name}/{flight_no}")
def get_delay_histogram(
    airport_code: str,
    airline_name: str,
    flight_no: str,
    conn: Connection = Depends(conn_dependency),
):
    logger.info("Building delay histogram",
                extra={"airport_code": airport_code, "airline_name": airline_name, "flight_no": flight_no})
    query = """
        SELECT fd.delay_min
        FROM fact_flight_day fd
        JOIN dim_airline a ON a.airline_id = fd.airline_id
        WHERE fd.airport_code = :airport
          AND a.airline_name = :airline
          AND fd.flight_no = :flight
    """
    df = pd.read_sql(
        text(query),
        conn,
        params={"airport": airport_code, "airline": airline_name, "flight": flight_no},
    )
    logger.debug("Delay rows loaded", extra={"rows": int(df.shape[0])})
    return delay_histogram(df, column="delay_min")
