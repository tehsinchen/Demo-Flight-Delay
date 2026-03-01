-- Create database
CREATE DATABASE IF NOT EXISTS flight_ops CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE flight_ops;

-- Reference data: Airlines (surrogate key)
CREATE TABLE IF NOT EXISTS dim_airline (
  airline_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  airline_name   VARCHAR(128) NOT NULL,
  airline_code   VARCHAR(8) NULL,                       -- optional (IATA/ICAO)
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (airline_id),
  UNIQUE KEY uq_airline_name (airline_name)
) ENGINE=InnoDB;

-- (Optional) Airports dimension – here we keep just code, but a dimension helps metadata
CREATE TABLE IF NOT EXISTS dim_airport (
  airport_code   CHAR(3) NOT NULL,                      -- e.g., TSA
  airport_name   VARCHAR(128) NULL,
  timezone       VARCHAR(64) NULL,                      -- e.g., Asia/Taipei
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (airport_code)
) ENGINE=InnoDB;

-- Fact: only insert when actual_time or delay_min changes (snapshots of changes)
CREATE TABLE IF NOT EXISTS fact_flight_snapshot (
  snapshot_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  service_date   DATE NOT NULL,                         -- from "date" e.g., 2026-01-15
  airport_code   CHAR(3) NOT NULL,
  airline_id     BIGINT UNSIGNED NOT NULL,
  flight_no      VARCHAR(10) NOT NULL,                  -- e.g., NH854, FM3002
  scheduled_time TIME NOT NULL,                         -- from "1630" -> 16:30:00
  actual_time    TIME NOT NULL,                         -- from "1628" -> 16:28:00
  delay_min      SMALLINT NOT NULL,                     -- can be negative for early
  changed_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- snapshot timestamp
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (snapshot_id),
  KEY idx_airport_date (airport_code, service_date),
  KEY idx_flight_identity (service_date, airport_code, airline_id, flight_no, scheduled_time, changed_at),
  CONSTRAINT fk_snapshot_airline FOREIGN KEY (airline_id) REFERENCES dim_airline(airline_id),
  CONSTRAINT fk_snapshot_airport FOREIGN KEY (airport_code) REFERENCES dim_airport(airport_code),
  CONSTRAINT chk_delay_min CHECK (delay_min BETWEEN -1440 AND 1440)
);

-- Daily rollup: one row per date/flight identity with the latest known state for that day
CREATE TABLE IF NOT EXISTS fact_flight_day (
  service_date   DATE NOT NULL,
  airport_code   CHAR(3) NOT NULL,
  airline_id     BIGINT UNSIGNED NOT NULL,
  flight_no      VARCHAR(10) NOT NULL,
  scheduled_time TIME NOT NULL,

  -- "Latest" known values for that date
  actual_time    TIME NOT NULL,
  delay_min      SMALLINT NOT NULL,

  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (service_date, airport_code, airline_id, flight_no, scheduled_time),
  KEY idx_airport_airline_fno (airport_code, airline_id, flight_no),
  CONSTRAINT fk_fday_airline FOREIGN KEY (airline_id) REFERENCES dim_airline(airline_id),
  CONSTRAINT fk_fday_airport FOREIGN KEY (airport_code) REFERENCES dim_airport(airport_code),
  CONSTRAINT chk_fday_delay CHECK (delay_min BETWEEN -1440 AND 1440)
);

-- Handy view for frequent Query #4 (airlines & flight_nos for an airport)
CREATE OR REPLACE VIEW vw_airport_airlines_flights AS
SELECT
  f.airport_code,
  a.airline_name,
  f.flight_no
FROM fact_flight_day f
JOIN dim_airline a ON a.airline_id = f.airline_id
GROUP BY f.airport_code, a.airline_name, f.flight_no;  -- deduplicate logical set

-- Create the stored procedure
USE flight_ops;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ingest_flight_reading $$

CREATE PROCEDURE sp_ingest_flight_reading (
    IN p_date_str      VARCHAR(10),   -- 'YYYY/MM/DD' e.g. '2026/01/15'
    IN p_airport_code  CHAR(3),       -- 'TSA'
    IN p_flight_no     VARCHAR(10),   -- 'FM3002'
    IN p_airline_name  VARCHAR(128),  -- 'Shanghai Airlines'
    IN p_scheduled_str VARCHAR(4),    -- 'HHmm' e.g. '1715'
    IN p_actual_str    VARCHAR(4),    -- 'HHmm' e.g. '1720'
    IN p_delay_min     INT            -- e.g. 5
)
BEGIN
    DECLARE v_service_date DATE;
    DECLARE v_scheduled TIME;
    DECLARE v_actual TIME;
    DECLARE v_airline_id BIGINT UNSIGNED;

    DECLARE v_prev_actual TIME;
    DECLARE v_prev_delay  INT;
    DECLARE v_found INT DEFAULT 1;

    -- Handle empty result from SELECT ... INTO
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0;

    -- Normalize strings to proper types
    SET v_service_date = STR_TO_DATE(p_date_str, '%Y/%m/%d');
    SET v_scheduled    = STR_TO_DATE(p_scheduled_str, '%H%i');
    SET v_actual       = STR_TO_DATE(p_actual_str,    '%H%i');

    -- Ensure airport exists (minimal seed)
    INSERT IGNORE INTO dim_airport (airport_code) VALUES (p_airport_code);

    -- Upsert airline and get id
    INSERT INTO dim_airline (airline_name) VALUES (p_airline_name)
    ON DUPLICATE KEY UPDATE airline_id = LAST_INSERT_ID(airline_id);
    SET v_airline_id = LAST_INSERT_ID();

    START TRANSACTION;

    -- Read last snapshot for this flight identity
    SET v_found = 1;
    SELECT actual_time, delay_min
      INTO v_prev_actual, v_prev_delay
      FROM fact_flight_snapshot
     WHERE service_date   = v_service_date
       AND airport_code   = p_airport_code
       AND airline_id     = v_airline_id
       AND flight_no      = p_flight_no
       AND scheduled_time = v_scheduled
     ORDER BY changed_at DESC
     LIMIT 1
     FOR UPDATE;

    -- Insert a snapshot only when changed (or first time)
    IF v_found = 0 OR v_prev_actual <> v_actual OR v_prev_delay <> p_delay_min THEN
        INSERT INTO fact_flight_snapshot (
            service_date, airport_code, airline_id, flight_no, scheduled_time,
            actual_time, delay_min, changed_at
        ) VALUES (
            v_service_date, p_airport_code, v_airline_id, p_flight_no, v_scheduled,
            v_actual, p_delay_min, NOW()
        );
    END IF;

    -- Upsert the day's latest state
    INSERT INTO fact_flight_day (
        service_date, airport_code, airline_id, flight_no, scheduled_time,
        actual_time, delay_min, updated_at
    ) VALUES (
        v_service_date, p_airport_code, v_airline_id, p_flight_no, v_scheduled,
        v_actual, p_delay_min, NOW()
    )
    ON DUPLICATE KEY UPDATE
        actual_time = VALUES(actual_time),
        delay_min   = VALUES(delay_min),
        updated_at  = NOW();

    COMMIT;
END $$

DELIMITER ;

-- User
CREATE USER IF NOT EXISTS 'backend_ro'@'%' IDENTIFIED BY 'backend_ro_pw';
CREATE USER IF NOT EXISTS 'crawler_rw'@'%' IDENTIFIED BY 'crawler_rw_pw';

-- Backend: read-only
GRANT SELECT ON flight_ops.* TO 'backend_ro'@'%';
GRANT EXECUTE ON flight_ops.* TO 'backend_ro'@'%';

-- Crawler: read/write (tune as needed)
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP
  ON flight_ops.* TO 'crawler_rw'@'%';
GRANT EXECUTE ON flight_ops.* TO 'crawler_rw'@'%';

FLUSH PRIVILEGES;
