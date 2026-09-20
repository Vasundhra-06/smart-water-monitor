# REST API Specification — Smart Water Monitor

## 1. Hardware Ingestion Endpoint (ESP32)

```http
POST /api/v1/devices/readings
Content-Type: application/json

{
  "device_id": "TANK_001",
  "api_key": "DEVICE_API_KEY_SECURE_987",
  "ph": 7.2,
  "tds": 235.0,
  "turbidity": 1.2,
  "temperature": 26.4,
  "water_level": 78.0,
  "timestamp": "2026-08-16T10:30:00Z"
}
```

### Response (201 Created)
```json
{
  "status": "success",
  "device_id": "TANK_001",
  "received_at": "2026-08-16T10:30:00Z",
  "calculated_water_score": 85,
  "message": "Sensor reading validated and logged successfully."
}
```

---

## 2. AI Analysis Contract Endpoint

```http
POST /api/v1/ai/analyze
Content-Type: application/json
```

### Output JSON Contract
```json
{
  "tank_id": "tank-main",
  "status": "ATTENTION",
  "score": 61,
  "trend": "DETERIORATING",
  "anomalies": [
    {
      "parameter": "turbidity",
      "severity": "HIGH",
      "reason": "Rapid spike from historical baseline of 1.1 NTU"
    }
  ],
  "cleaning_recommended": true,
  "confidence": 0.92,
  "summary": "Water quality in tank is deteriorating based on recent turbidity trends.",
  "generated_at": "2026-08-16T10:30:00Z"
}
```
