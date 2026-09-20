# Hardware Integration Guide (ESP32) — Smart Water Monitor

## 🔌 ESP32 Circuitry & Pin Mapping

| Sensor | ESP32 Pin | Interface Type | Standard Range |
|---|---|---|---|
| Analog pH Sensor | GPIO 34 (ADC1_CH6) | Analog Voltage (0-3.3V) | 0.0 - 14.0 |
| Analog TDS Sensor | GPIO 35 (ADC1_CH7) | Analog Voltage | 0 - 1000 ppm |
| Turbidity Sensor | GPIO 32 (ADC1_CH4) | Analog Voltage | 0.0 - 10.0 NTU |
| DS18B20 Temp Probe | GPIO 4 | 1-Wire Digital | -10 to 85 °C |
| Ultrasonic Level | GPIO 18 (Trig), GPIO 19 (Echo) | Digital Pulse | 0 - 100% |

## 📡 ESP32 C++ Code Snippet (HTTP POST)

```cpp
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* serverUrl = "http://YOUR_SERVER_IP:8000/api/v1/devices/readings";

void sendSensorData(float ph, float tds, float turb, float temp, float level) {
  if(WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<200> doc;
    doc["device_id"] = "TANK_001";
    doc["api_key"] = "DEVICE_API_KEY_SECURE_987";
    doc["ph"] = ph;
    doc["tds"] = tds;
    doc["turbidity"] = turb;
    doc["temperature"] = temp;
    doc["water_level"] = level;

    String jsonString;
    serializeJson(doc, jsonString);

    int httpResponseCode = http.POST(jsonString);
    http.end();
  }
}
```
