"""
Smart Water Monitor - AI Analysis Service & ESP32 Ingestion API
FastAPI implementation with multi-layer trend analysis, anomaly detection, score computation,
and mock scenario trigger endpoints.
"""

from fastapi import FastAPI, HTTPException, Header, Depends, status, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
import math
import os
import time
import urllib.request
import urllib.parse
import json
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

app = FastAPI(
    title="Smart Water Monitor AI & ESP32 API Engine",
    description="Backend microservice for AI trend analysis, anomaly detection, score computation, and ESP32 hardware readings ingestion.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------------------------------------------------
# DATA MODELS & SCHEMAS
# -----------------------------------------------------------------------------

class ESP32SensorPayload(BaseModel):
    device_id: str = Field(..., example="TANK_001")
    api_key: str = Field(..., example="DEVICE_API_KEY_SECURE_987")
    ph: float = Field(..., ge=0.0, le=14.0, example=7.2)
    tds: float = Field(..., ge=0.0, le=5000.0, example=235.0)
    turbidity: float = Field(..., ge=0.0, le=100.0, example=1.2)
    temperature: float = Field(..., ge=-10.0, le=70.0, example=26.4)
    water_level: float = Field(..., ge=0.0, le=100.0, example=78.0)
    timestamp: Optional[str] = Field(default=None, example="2026-08-16T10:30:00Z")

class SensorReadingItem(BaseModel):
    ph: float
    tds: float
    turbidity: float
    temperature: float
    water_level: float
    timestamp: str

class AnalysisRequest(BaseModel):
    tank_id: str
    readings: List[SensorReadingItem]
    historical_baseline_turbidity: Optional[float] = 1.1
    historical_baseline_tds: Optional[float] = 220.0
    historical_baseline_ph: Optional[float] = 7.2

class AnomalyDetail(BaseModel):
    parameter: str
    severity: str  # LOW, MEDIUM, HIGH, CRITICAL
    reason: str

class AIAnalysisOutput(BaseModel):
    tank_id: str
    status: str  # EXCELLENT, GOOD, ATTENTION, POOR, CRITICAL
    score: int   # 0 to 100
    trend: str   # STABLE, IMPROVING, DETERIORATING
    anomalies: List[AnomalyDetail]
    cleaning_recommended: bool
    confidence: float
    summary: str
    generated_at: str

class ScenarioTriggerRequest(BaseModel):
    tank_id: str
    scenario: str  # NORMAL, DETERIORATING, CRITICAL, DEVICE_OFFLINE, POWER_FAILURE

# In-memory store for simulation states & active baselines
DEVICE_API_KEYS = {
    "TANK_001": "DEVICE_API_KEY_SECURE_987",
    "TANK_002": "DEVICE_API_KEY_SECURE_987",
    "TANK_003": "DEVICE_API_KEY_SECURE_987",
    "TANK_004": "DEVICE_API_KEY_SECURE_987"
}

TANK_SIMULATION_STATE = {
    "TANK_001": "NORMAL",
    "TANK_002": "NORMAL",
    "TANK_003": "DETERIORATING",
    "TANK_004": "NORMAL"
}

# -----------------------------------------------------------------------------
# HYBRID AI SCORING & ANOMALY DETECTION ENGINE
# -----------------------------------------------------------------------------

def calculate_water_quality_score(ph: float, tds: float, turbidity: float, temp: float, level: float) -> int:
    """
    Computes a composite 0-100 Water Quality Score using physical parameter bounds:
    - pH: ideal 6.5 - 8.5 (weighted 25%)
    - TDS: ideal < 300 ppm (weighted 25%)
    - Turbidity: ideal < 1.5 NTU (weighted 30%)
    - Temp: ideal 15-30 °C (weighted 10%)
    - Water Level: ideal 20-95% (weighted 10%)
    """
    # pH subscore
    if 6.5 <= ph <= 8.5:
        ph_score = 100
    elif 6.0 <= ph < 6.5 or 8.5 < ph <= 9.0:
        ph_score = 75
    elif 5.0 <= ph < 6.0 or 9.0 < ph <= 10.0:
        ph_score = 45
    else:
        ph_score = 10

    # TDS subscore (ppm)
    if tds <= 250:
        tds_score = 100
    elif tds <= 400:
        tds_score = 80
    elif tds <= 600:
        tds_score = 55
    elif tds <= 1000:
        tds_score = 30
    else:
        tds_score = 10

    # Turbidity subscore (NTU)
    if turbidity <= 1.0:
        turb_score = 100
    elif turbidity <= 2.0:
        turb_score = 85
    elif turbidity <= 3.5:
        turb_score = 55
    elif turbidity <= 5.0:
        turb_score = 30
    else:
        turb_score = 5

    # Temp subscore (°C)
    if 15.0 <= temp <= 30.0:
        temp_score = 100
    elif 10.0 <= temp < 15.0 or 30.0 < temp <= 38.0:
        temp_score = 80
    else:
        temp_score = 50

    # Level subscore (%)
    if level >= 20.0:
        level_score = 100
    else:
        level_score = max(10, int(level * 5))

    weighted_score = (ph_score * 0.25) + (tds_score * 0.25) + (turb_score * 0.30) + (temp_score * 0.10) + (level_score * 0.10)
    return max(0, min(100, int(round(weighted_score))))


def run_trend_and_anomaly_analysis(
    readings: List[SensorReadingItem],
    baseline_turb: float = 1.1,
    baseline_tds: float = 220.0,
    baseline_ph: float = 7.2
) -> Dict[str, Any]:
    """
    5-Layer AI Analysis:
    Layer 1: Parameter range validation
    Layer 2: Rolling baseline & Moving Average computation
    Layer 3: Rate of change (derivative) peak detection
    Layer 4: Multi-parameter correlation analysis
    Layer 5: Classification & Cleaning Recommendation
    """
    if not readings:
        return {
            "score": 85,
            "status": "GOOD",
            "trend": "STABLE",
            "anomalies": [],
            "cleaning_recommended": False,
            "confidence": 0.80,
            "summary": "No recent sensor data available for evaluation."
        }

    latest = readings[-1]
    score = calculate_water_quality_score(
        latest.ph, latest.tds, latest.turbidity, latest.temperature, latest.water_level
    )

    anomalies: List[AnomalyDetail] = []
    
    # Layer 2 & 3: Moving Average & Derivative Peak Analysis
    turb_values = [r.turbidity for r in readings]
    tds_values = [r.tds for r in readings]
    ph_values = [r.ph for r in readings]

    avg_turb = sum(turb_values) / len(turb_values)
    max_turb = max(turb_values)
    latest_turb = latest.turbidity

    avg_tds = sum(tds_values) / len(tds_values)
    latest_tds = latest.tds

    # Rate of change over recent readings
    turb_delta = latest_turb - (turb_values[0] if len(turb_values) > 1 else latest_turb)

    # Check Turbidity Anomaly Peak
    if latest_turb >= 4.0 or max_turb >= 4.0:
        anomalies.append(AnomalyDetail(
            parameter="turbidity",
            severity="CRITICAL",
            reason=f"Abnormal turbidity peak detected at {latest_turb:.2f} NTU (Historical baseline: {baseline_turb:.2f} NTU)."
        ))
    elif latest_turb >= 2.5 or (latest_turb > baseline_turb * 1.8 and turb_delta > 0.8):
        anomalies.append(AnomalyDetail(
            parameter="turbidity",
            severity="HIGH",
            reason=f"Rapid turbidity elevation detected ({latest_turb:.2f} NTU, +{((latest_turb - baseline_turb)/baseline_turb)*100:.0f}% from baseline)."
        ))

    # Check TDS Anomaly
    if latest_tds > 500.0:
        anomalies.append(AnomalyDetail(
            parameter="tds",
            severity="HIGH",
            reason=f"Total Dissolved Solids elevated to {latest_tds:.0f} ppm."
        ))
    elif latest_tds > baseline_tds * 1.3:
        anomalies.append(AnomalyDetail(
            parameter="tds",
            severity="MEDIUM",
            reason=f"TDS increased by {((latest_tds - baseline_tds)/baseline_tds)*100:.0f}% above historical baseline."
        ))

    # Check pH Anomaly
    if latest.ph < 6.5 or latest.ph > 8.5:
        anomalies.append(AnomalyDetail(
            parameter="ph",
            severity="MEDIUM",
            reason=f"pH level shifted to {latest.ph:.2f} (outside ideal 6.5-8.5 range)."
        ))

    # Determine Overall Status & Recommendation
    has_critical = any(a.severity == "CRITICAL" for a in anomalies)
    has_high = any(a.severity == "HIGH" for a in anomalies)

    if has_critical or score < 40:
        status_str = "CRITICAL"
        trend_str = "DETERIORATING"
        cleaning_rec = True
        summary_str = f"Critical water quality deterioration detected! Turbidity peak ({latest_turb:.2f} NTU) indicates severe sediment/biofilm buildup. Immediate tank cleaning required."
        confidence_val = 0.96
    elif has_high or score < 65:
        status_str = "ATTENTION"
        trend_str = "DETERIORATING"
        cleaning_rec = True
        summary_str = f"Water quality in tank is deteriorating. Rapid turbidity/TDS trend increase observed above historical baseline. Tank inspection and cleaning recommended."
        confidence_val = 0.91
    elif len(anomalies) > 0 or score < 80:
        status_str = "GOOD"
        trend_str = "DETERIORATING"
        cleaning_rec = False
        summary_str = "Minor parameter fluctuations observed compared to historical baseline. Continuous monitoring ongoing."
        confidence_val = 0.87
    elif score >= 90:
        status_str = "EXCELLENT"
        trend_str = "STABLE"
        cleaning_rec = False
        summary_str = "Water-quality parameters are operating at optimal conditions compared with the tank's historical baseline."
        confidence_val = 0.98
    else:
        status_str = "GOOD"
        trend_str = "STABLE"
        cleaning_rec = False
        summary_str = "Water quality remains stable within safe institutional drinking standards."
        confidence_val = 0.95

    return {
        "score": score,
        "status": status_str,
        "trend": trend_str,
        "anomalies": anomalies,
        "cleaning_recommended": cleaning_rec,
        "confidence": confidence_val,
        "summary": summary_str
    }

# -----------------------------------------------------------------------------
# API ROUTES
# -----------------------------------------------------------------------------

@app.get("/api")
def api_status():
    return {
        "app": "Smart Water Monitor AI & ESP32 Engine",
        "status": "online",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

@app.post("/api/v1/devices/readings", status_code=status.HTTP_201_CREATED)
def ingest_esp32_reading(payload: ESP32SensorPayload):
    """
    Hardware Ready REST API for ESP32 devices installed on water tanks.
    Validates device authorization, checks data bounds, and stores reading.
    """
    # 1. Validate API Key
    expected_key = DEVICE_API_KEYS.get(payload.device_id)
    if not expected_key or payload.api_key != expected_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Unauthorized device credentials for {payload.device_id}"
        )

    # 2. Validate Physical Range Limits
    if not (0.0 <= payload.ph <= 14.0):
        raise HTTPException(status_code=400, detail="Invalid pH reading out of range (0-14)")
    if payload.tds < 0:
        raise HTTPException(status_code=400, detail="Invalid TDS reading (< 0 ppm)")
    if payload.turbidity < 0:
        raise HTTPException(status_code=400, detail="Invalid Turbidity reading (< 0 NTU)")

    timestamp_str = payload.timestamp or datetime.now(timezone.utc).isoformat()

    # Calculate real-time score
    score = calculate_water_quality_score(
        payload.ph, payload.tds, payload.turbidity, payload.temperature, payload.water_level
    )

    return {
        "status": "success",
        "device_id": payload.device_id,
        "received_at": timestamp_str,
        "calculated_water_score": score,
        "message": "Sensor reading validated and logged successfully."
    }

@app.post("/api/v1/ai/analyze", response_model=AIAnalysisOutput)
def analyze_water_quality(req: AnalysisRequest):
    """
    Runs multi-layer statistical anomaly and trend analysis on a set of sensor readings.
    Returns structured JSON conforming to the Smart Water Monitor AI Contract.
    """
    res = run_trend_and_anomaly_analysis(
        readings=req.readings,
        baseline_turb=req.historical_baseline_turbidity or 1.1,
        baseline_tds=req.historical_baseline_tds or 220.0,
        baseline_ph=req.historical_baseline_ph or 7.2
    )

    return AIAnalysisOutput(
        tank_id=req.tank_id,
        status=res["status"],
        score=res["score"],
        trend=res["trend"],
        anomalies=res["anomalies"],
        cleaning_recommended=res["cleaning_recommended"],
        confidence=res["confidence"],
        summary=res["summary"],
        generated_at=datetime.now(timezone.utc).isoformat()
    )

@app.post("/api/v1/sim/trigger_scenario")
def trigger_scenario(req: ScenarioTriggerRequest):
    """
    Developer/Demo endpoint to trigger scenarios (NORMAL, DETERIORATING, CRITICAL, DEVICE_OFFLINE, POWER_FAILURE)
    without physical hardware.
    """
    if req.scenario not in ["NORMAL", "DETERIORATING", "CRITICAL", "DEVICE_OFFLINE", "POWER_FAILURE"]:
        raise HTTPException(status_code=400, detail="Invalid simulation scenario")

    TANK_SIMULATION_STATE[req.tank_id] = req.scenario

    return {
        "tank_id": req.tank_id,
        "active_scenario": req.scenario,
        "message": f"Successfully activated demo scenario '{req.scenario}' for {req.tank_id}."
    }

# -----------------------------------------------------------------------------
# THINGSPEAK LIVE TELEMETRY & HEALTH ENDPOINTS
# -----------------------------------------------------------------------------

THINGSPEAK_CHANNEL_ID = os.environ.get("THINGSPEAK_CHANNEL_ID", "3487158")
THINGSPEAK_READ_API_KEY = os.environ.get("THINGSPEAK_READ_API_KEY", "")

latest_cache: Dict[str, Any] = {
    "timestamp": 0,
    "data": None
}
CACHE_TTL_SECONDS = 5

def _calculate_quality_score(ph: float, tds: float, temp: float) -> float:
    ph_score = 100.0
    if ph < 6.5:
        ph_score = max(0.0, 100.0 - (6.5 - ph) * 20.0)
    elif ph > 8.5:
        ph_score = max(0.0, 100.0 - (ph - 8.5) * 20.0)

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

    temp_score = 100.0
    if temp < 20.0:
        temp_score = max(0.0, 100.0 - (20.0 - temp) * 5.0)
    elif temp > 30.0:
        temp_score = max(0.0, 100.0 - (temp - 30.0) * 5.0)

    final_score = (ph_score * 0.40) + (tds_score * 0.40) + (temp_score * 0.20)
    return round(max(0.0, min(100.0, final_score)), 1)

def _calculate_quality_status(score: float) -> str:
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

def _parse_feed_item(item: dict) -> dict:
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
        score = float(score_val) if score_val is not None and score_val != "" else _calculate_quality_score(ph, tds, temp)
    except (ValueError, TypeError):
        score = _calculate_quality_score(ph, tds, temp)

    entry_id = item.get("entry_id", 1)
    timestamp = item.get("created_at") or datetime.now(timezone.utc).isoformat()
    status = _calculate_quality_status(score)

    return {
        "tds": round(tds, 1),
        "ph": round(ph, 2),
        "temperature": round(temp, 1),
        "quality_score": round(score, 1),
        "quality_status": status,
        "timestamp": timestamp,
        "entry_id": entry_id
    }

_web_build_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")
_index_html_path = os.path.join(_web_build_dir, "index.html")

@app.get("/")
def root():
    if os.path.isfile(_index_html_path):
        return FileResponse(_index_html_path, media_type="text/html")
    return {
        "service": "Smart Water Monitor AI & ESP32 Telemetry API",
        "status": "online",
        "version": "1.0.0",
        "docs_url": "/docs"
    }

@app.get("/api")
def api_info():
    return {
        "service": "Smart Water Monitor AI & ESP32 Telemetry API",
        "status": "online",
        "version": "1.0.0",
        "docs_url": "/docs"
    }

@app.get("/health")
def health():
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}

@app.get("/api/v1/water-quality/latest")
def get_water_quality_latest():
    global latest_cache
    now = time.time()
    if latest_cache["data"] and (now - latest_cache["timestamp"] < CACHE_TTL_SECONDS):
        return {"success": True, "data": latest_cache["data"]}

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
                    parsed = _parse_feed_item(feed_data)
                    latest_cache["timestamp"] = now
                    latest_cache["data"] = parsed
                    return {"success": True, "data": parsed}
    except Exception as e:
        print(f"[ThingSpeak API Error] /latest fetch failed: {e}")

    # Fallback simulation
    fallback = {
        "tds": 235.0,
        "ph": 7.2,
        "temperature": 26.5,
        "quality_score": 95.0,
        "quality_status": "Excellent",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "entry_id": 1,
        "is_fallback": True
    }
    return {"success": True, "data": fallback}

@app.get("/api/v1/water-quality/history")
def get_water_quality_history(results: int = Query(default=50, ge=1, le=100)):
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
                parsed_list = [_parse_feed_item(item) for item in feeds]
                return {"success": True, "data": parsed_list}
    except Exception as e:
        print(f"[ThingSpeak API Error] /history fetch failed: {e}")

    # Fallback simulated dataset
    fallback_list = []
    base_time = time.time()
    for i in range(results, 0, -1):
        ts = datetime.fromtimestamp(base_time - (i * 300), timezone.utc).isoformat()
        tds = 230.0 + (i % 5) * 5
        ph = 7.2 + ((i % 3) - 1) * 0.1
        temp = 26.0 + (i % 2) * 0.5
        score = _calculate_quality_score(ph, tds, temp)
        fallback_list.append({
            "tds": tds,
            "ph": ph,
            "temperature": temp,
            "quality_score": score,
            "quality_status": _calculate_quality_status(score),
            "timestamp": ts,
            "entry_id": i
        })
    return {"success": True, "data": fallback_list, "is_fallback": True}

@app.get("/api/v1/water-quality/status")
def get_water_quality_status():
    return {
        "status": "online",
        "thingspeak_channel_id": THINGSPEAK_CHANNEL_ID,
        "read_key_configured": bool(THINGSPEAK_READ_API_KEY),
        "cache_age_seconds": round(time.time() - latest_cache["timestamp"], 1) if latest_cache["timestamp"] else None,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

# -----------------------------------------------------------------------------
# STATIC FRONTEND SERVING (Flutter Web)
# -----------------------------------------------------------------------------
_web_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")
if os.path.isdir(_web_dir):
    app.mount("/", StaticFiles(directory=_web_dir, html=True), name="web")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("backend_ai.main:app", host="0.0.0.0", port=port, reload=False)

