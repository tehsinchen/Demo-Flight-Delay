import yaml
import json
import pytz
from datetime import datetime
from curl_cffi import requests
from db_config import FlightDatabase  # Import our new production DB config

class AirportSyncEngine:
    def __init__(self, config_path):
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = yaml.safe_load(f)
        
        self.db = FlightDatabase()
        self.session = requests.Session(impersonate="chrome120")
        self.log_file = 'airport_sync.json'

    def normalize_time(self, time_str):
        """Standardizes any time format to HHmm string."""
        if not time_str: return "0000"
        digits = ''.join(filter(str.isdigit, str(time_str)))
        return digits[:4].zfill(4)

    def calculate_delay(self, sched, act):
        """Signed delay calculation with 12-hour rollover check."""
        try:
            s_dt = datetime.strptime(sched, "%H%M")
            a_dt = datetime.strptime(act, "%H%M")
            diff = int((a_dt - s_dt).total_seconds() / 60)
            if diff < -720: diff += 1440
            elif diff > 720: diff -= 1440
            return diff
        except:
            return 0

    def process_airport(self, airport_cfg):
        """Fetches, parses, and saves a single airport."""
        # 1. Determine local date based on airport timezone
        tz = pytz.timezone(airport_cfg['timezone'])
        local_now = datetime.now(tz)
        local_date = local_now.strftime("%Y/%m/%d")

        # 2. Setup Payload
        payload = airport_cfg.get('payload', {})
        if isinstance(payload, dict) and payload.get("ODate") == "AUTO_TARGET":
            payload["ODate"] = local_date

        # 3. Fetch
        try:
            print(f"[*] Processing {airport_cfg['code']}...")
            if airport_cfg.get('payload_type') == 'json':
                resp = self.session.post(airport_cfg['url'], json=payload, headers=airport_cfg.get('headers'))
            else:
                resp = self.session.post(airport_cfg['url'], data=payload, headers=airport_cfg.get('headers'))
            
            raw_data = resp.json()
        except Exception as e:
            print(f"[!] Fetch failed for {airport_cfg['code']}: {e}")
            return

        # 4. Parse
        root = airport_cfg.get('json_root')
        items = raw_data.get(root) if root else raw_data
        if not isinstance(items, list): return

        m = airport_cfg['mapping']
        parsed_batch = []
        for i in items:
            s_hhmm = self.normalize_time(i.get(m['scheduled']))
            a_hhmm = self.normalize_time(i.get(m['actual']))
            
            parsed_batch.append({
                "date": local_date,
                "airport_code": airport_cfg['code'],
                "flight_no": i.get(m['flight_no']),
                "airline": i.get(m['airline']),
                "scheduled": s_hhmm,
                "actual": a_hhmm,
                "delay_min": self.calculate_delay(s_hhmm, a_hhmm)
            })

        # 5. Production Write: Save to DB immediately to keep memory clear
        self.db.ingest_airport_batch(parsed_batch)

        # 6. JSON Logging (Append Mode Simulation)
        # For production with hundreds of airports, we use a simple append to avoid re-reading the file
        # with open(self.log_file, 'a', encoding='utf-8') as f:
        #     for record in parsed_batch:
        #         f.write(json.dumps(record, ensure_ascii=False) + "\n")

    def run(self):
        # Clear/Initialize the JSON log file
        with open(self.log_file, 'w', encoding='utf-8') as f:
            pass 

        for airport in self.config['airports']:
            self.process_airport(airport)
        
        print("\n[✔] Daily Sync Complete.")

if __name__ == "__main__":
    engine = AirportSyncEngine('airports_config.yaml')
    engine.run()