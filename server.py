import http.server
import json
import os
import time
import urllib.request
import urllib.parse
from datetime import datetime

PORT = int(os.environ.get("PORT", 8080))
DIRECTORY = os.path.join(os.path.dirname(__file__), "build", "web")

THINGSPEAK_CHANNEL_ID = os.environ.get("THINGSPEAK_CHANNEL_ID", "3487158")
THINGSPEAK_READ_API_KEY = os.environ.get("THINGSPEAK_READ_API_KEY", "")

# In-memory cache for /latest to avoid exceeding ThingSpeak rate limits
latest_cache = {
    "timestamp": 0,
    "data": None
}
CACHE_TTL_SECONDS = 5

def calculate_quality_status(score):
    if score >= 90:
        return "Excellent"
    elif score >= 75:
        return "Good"
    elif score >= 50:
        return "Moderate"
    elif score >= 25:
        return "Poor"
    else:
        return "Very Poor"

def calculate_quality_score(ph, tds, temp):
    # pH Score
    ph_score = 100.0
    if ph < 6.5:
        ph_score = max(0.0, 100.0 - (6.5 - ph) * 20.0)
    elif ph > 8.5:
        ph_score = max(0.0, 100.0 - (ph - 8.5) * 20.0)
    
    # TDS Score
    tds_score = 100.0
    if tds <= 300.0:
        tds_score = 100.0
    elif tds <= 500.0:
        tds_score = max(0.0, 100.0 - (tds - 300.0) * (20.0 / 200.0))
    elif tds <= 1000.0:
        tds_score = max(0.0, 80.0 - (tds - 500.0) * (40.0 / 500.0))
    elif tds <= 1500.0:
        tds_score = max(0.0, 40.0 - (tds - 1000.0) * (40.0 / 500.0))
    else:
        tds_score = 0.0

    # Temperature Score
    temp_score = 100.0
    if temp < 20.0:
        temp_score = max(0.0, 100.0 - (20.0 - temp) * 5.0)
    elif temp > 30.0:
        temp_score = max(0.0, 100.0 - (temp - 30.0) * 5.0)

    final_score = (ph_score * 0.40) + (tds_score * 0.40) + (temp_score * 0.20)
    return round(max(0.0, min(100.0, final_score)), 1)

def parse_feed_item(item):
    try:
        tds = float(item.get("field1") or 235.0)
    except (ValueError, TypeError):
        tds = 235.0

    try:
        ph = float(item.get("field2") or 7.2)
    except (ValueError, TypeError):
        ph = 7.2

    try:
        temp = float(item.get("field3") or 26.5)
    except (ValueError, TypeError):
        temp = 26.5

    try:
        score_val = item.get("field4")
        score = float(score_val) if score_val is not None and score_val != "" else calculate_quality_score(ph, tds, temp)
    except (ValueError, TypeError):
        score = calculate_quality_score(ph, tds, temp)

    entry_id = item.get("entry_id", 1)
    timestamp = item.get("created_at") or datetime.utcnow().isoformat() + "Z"
    status = calculate_quality_status(score)

    return {
        "tds": round(tds, 1),
        "ph": round(ph, 2),
        "temperature": round(temp, 1),
        "quality_score": round(score, 1),
        "quality_status": status,
        "timestamp": timestamp,
        "entry_id": entry_id
    }

def fetch_latest_from_thingspeak():
    global latest_cache
    now = time.time()
    if latest_cache["data"] and (now - latest_cache["timestamp"] < CACHE_TTL_SECONDS):
        return latest_cache["data"], 200

    url = f"https://api.thingspeak.com/channels/{THINGSPEAK_CHANNEL_ID}/feeds/last.json"
    if THINGSPEAK_READ_API_KEY:
        url += f"?api_key={THINGSPEAK_READ_API_KEY}"

    req = urllib.request.Request(url, headers={"User-Agent": "SmartWaterMonitorBackend/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                raw_body = response.read().decode("utf-8")
                feed_data = json.loads(raw_body)
                if feed_data and isinstance(feed_data, dict) and "entry_id" in feed_data:
                    parsed = parse_feed_item(feed_data)
                    latest_cache["timestamp"] = now
                    latest_cache["data"] = parsed
                    return parsed, 200
    except Exception as e:
        print(f"[ThingSpeak API Error] /latest fetch failed: {e}")

    # Fallback simulation object if ThingSpeak empty / key missing / offline
    fallback_reading = {
        "tds": 235.0,
        "ph": 7.2,
        "temperature": 26.5,
        "quality_score": 95.0,
        "quality_status": "Excellent",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "entry_id": 1,
        "is_fallback": True
    }
    return fallback_reading, 200

def fetch_history_from_thingspeak(results=50):
    url = f"https://api.thingspeak.com/channels/{THINGSPEAK_CHANNEL_ID}/feeds.json?results={results}"
    if THINGSPEAK_READ_API_KEY:
        url += f"&api_key={THINGSPEAK_READ_API_KEY}"

    req = urllib.request.Request(url, headers={"User-Agent": "SmartWaterMonitorBackend/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=6) as response:
            if response.status == 200:
                raw_body = response.read().decode("utf-8")
                body_json = json.loads(raw_body)
                feeds = body_json.get("feeds", [])
                parsed_list = [parse_feed_item(item) for item in feeds]
                return {"data": parsed_list}, 200
    except Exception as e:
        print(f"[ThingSpeak API Error] /history fetch failed: {e}")

    # Fallback simulated dataset if ThingSpeak unreachable
    fallback_list = []
    base_time = time.time()
    for i in range(results, 0, -1):
        ts = datetime.utcfromtimestamp(base_time - (i * 300)).isoformat() + "Z"
        tds = 230.0 + (i % 5) * 5
        ph = 7.2 + ((i % 3) - 1) * 0.1
        temp = 26.0 + (i % 2) * 0.5
        score = calculate_quality_score(ph, tds, temp)
        fallback_list.append({
            "tds": tds,
            "ph": ph,
            "temperature": temp,
            "quality_score": score,
            "quality_status": calculate_quality_status(score),
            "timestamp": ts,
            "entry_id": i
        })
    return {"data": fallback_list, "is_fallback": True}, 200


class SmartWaterRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        if path == "/api/v1/water-quality/latest":
            print(f"[{datetime.utcnow().isoformat()}] Received GET /api/v1/water-quality/latest")
            data, code = fetch_latest_from_thingspeak()
            self.send_json_response({"success": True, "data": data}, code)
            return

        if path == "/api/v1/water-quality/history":
            query_params = urllib.parse.parse_qs(parsed_url.query)
            results = 50
            if "results" in query_params:
                try:
                    # Validate requested result count (range 1 to 100)
                    results = max(1, min(100, int(query_params["results"][0])))
                except ValueError:
                    results = 50
            print(f"[{datetime.utcnow().isoformat()}] Received GET /api/v1/water-quality/history?results={results}")
            data_dict, code = fetch_history_from_thingspeak(results=results)
            history_data = data_dict.get("data", []) if isinstance(data_dict, dict) else []
            self.send_json_response({"success": True, "data": history_data}, code)
            return

        if path == "/api/v1/water-quality/status":
            status_data = {
                "status": "online",
                "thingspeak_channel_id": THINGSPEAK_CHANNEL_ID,
                "read_key_configured": bool(THINGSPEAK_READ_API_KEY),
                "cache_age_seconds": round(time.time() - latest_cache["timestamp"], 1) if latest_cache["timestamp"] else None,
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
            self.send_json_response(status_data, 200)
            return

        # Default static file handler for Flutter Web
        super().do_GET()

    def send_json_response(self, data, status_code=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("bypass-tunnel-reminder", "true")
        try:
            super().end_headers()
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError):
            pass

    def log_message(self, format, *args):
        # Quiet logger
        pass

if __name__ == "__main__":
    server_address = ("", PORT)
    httpd = http.server.ThreadingHTTPServer(server_address, SmartWaterRequestHandler)
    print(f"=======================================================")
    print(f" Smart Water Quality Backend Server running on port {PORT}")
    print(f" ThingSpeak Channel: {THINGSPEAK_CHANNEL_ID}")
    print(f" Endpoints:")
    print(f"   GET http://localhost:{PORT}/api/v1/water-quality/latest")
    print(f"   GET http://localhost:{PORT}/api/v1/water-quality/history?results=50")
    print(f"   GET http://localhost:{PORT}/api/v1/water-quality/status")
    print(f"=======================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        httpd.server_close()
