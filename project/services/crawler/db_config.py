import os
import pymysql
from dotenv import load_dotenv
from pymysql import err

# Load environment variables from .env
load_dotenv()

class FlightDatabase:
    def __init__(self):
        self.db_config = {
            "host": os.getenv("DB_HOST", "127.0.0.1"),
            "port": int(os.getenv("DB_PORT", 3306)),
            "user": os.getenv("DB_USER"),
            "password": os.getenv("DB_PASSWORD"),
            "database": os.getenv("DB_NAME"),
            "charset": "utf8mb4",
            "cursorclass": pymysql.cursors.DictCursor,
            "autocommit": False
        }

    def get_connection(self):
        return pymysql.connect(**self.db_config)

    def ingest_airport_batch(self, records):
        """Writes a single airport's batch to the database immediately."""
        if not records:
            return
        
        sql = "CALL sp_ingest_flight_reading(%s,%s,%s,%s,%s,%s,%s)"
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # Optimized isolation level for batch writes
                cur.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED")
                
                # Execute in one transaction per airport
                for r in records:
                    cur.execute(sql, (
                        r["date"],
                        r["airport_code"],
                        r["flight_no"],
                        r["airline"],
                        r["scheduled"], 
                        r["actual"],    
                        r.get("delay_min", 0)
                    ))
                conn.commit()
                print(f"[DB Success] Ingested {len(records)} flights for {records[0]['airport_code']}")
        except Exception as e:
            conn.rollback()
            print(f"[DB Error] Batch failed: {e}")
        finally:
            conn.close()