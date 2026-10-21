/*
  ================================================================================
  SMART WATER QUALITY MONITORING SYSTEM - ESP32 FIRMWARE
  ================================================================================
  Hardware Connections:
    - DS18B20 Temp Sensor : GPIO 32 (with 4.7k pullup resistor between VCC & DATA)
    - Analog TDS Sensor    : GPIO 35 (ADC1_CH7)
    - Analog pH Sensor     : GPIO 34 (ADC1_CH6)
    - I2C LCD (16x2)       : SDA -> GPIO 21, SCL -> GPIO 22, VCC -> 5V (VIN), GND -> GND

  ThingSpeak Channel 3487158:
    - field1 : TDS (ppm)
    - field2 : pH Level
    - field3 : Temperature (°C)
    - field4 : Purity / Quality Percentage (%)

  Web Application URL:
    - https://smart-water-monitor-self.vercel.app
  ================================================================================
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ============================================================
// LCD CONFIGURATION (I2C) — auto-detected by I2C scanner
// Default ESP32 I2C pins: SDA = 21, SCL = 22
// Address is commonly 0x27 or 0x3F
// ============================================================
bool lcdFound = false;
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ============================================================
// WI-FI CREDENTIALS
// ============================================================
const char* WIFI_SSID     = "Vasundhra";
const char* WIFI_PASSWORD = "vasundhra06";

// ============================================================
// THINGSPEAK CLOUD CONFIGURATION — raw TCP (most reliable)
// ============================================================
const char* THINGSPEAK_API_KEY = "R6K2CMSRK6FRBB2A";
const char* THINGSPEAK_HOST    = "api.thingspeak.com";
const int   THINGSPEAK_PORT    = 80;

// ============================================================
// SENSOR PINS
// ============================================================
#define TEMP_PIN 32  // DS18B20 digital temperature probe
#define TDS_PIN  35  // Analog TDS meter output
#define PH_PIN   34  // Analog pH sensor output

// ============================================================
// TEMPERATURE SENSOR
// ============================================================
OneWire oneWire(TEMP_PIN);
DallasTemperature temperatureSensor(&oneWire);

// ============================================================
// I2C SCANNER — finds LCD address automatically at startup
// ============================================================
void scanAndInitLCD() {
  Serial.println("\n--- I2C Scanner ---");
  int found = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print("I2C device at 0x");
      if (addr < 16) Serial.print("0");
      Serial.println(addr, HEX);
      found++;
      if (addr == 0x27 || addr == 0x3F || addr == 0x20 || addr == 0x38) {
        lcd = LiquidCrystal_I2C(addr, 16, 2);
        lcd.init();
        lcd.backlight();
        lcdFound = true;
        Serial.print("  >> LCD initialized at 0x");
        Serial.println(addr, HEX);
      }
    }
  }
  if (found == 0) {
    Serial.println("ERROR: No I2C devices! Check SDA=GPIO21, SCL=GPIO22, VCC=5V.");
  }
  Serial.println("--- Scan Done ---\n");
}

// Timing variables (Upload every 20 seconds)
unsigned long lastUploadTime = 0;
const unsigned long uploadInterval = 20000;

// ============================================================
// SENSOR READING & SMOOTHING (Noise Filtering)
// ============================================================

// Track temperature sensor operational status
bool isTemperatureSensorValid = true;

// Read Temperature with DS18B20 error fallback
float readTemperature() {
  temperatureSensor.requestTemperatures();
  float temp = temperatureSensor.getTempCByIndex(0);

  // DS18B20 returns -127.00 when wire is disconnected or 85.00 on power-on error
  if (temp == -127.00 || temp == 85.00 || temp < 0.0 || temp > 75.0) {
    Serial.println("Warning: DS18B20 read error! Using provisional 25.0C baseline.");
    isTemperatureSensorValid = false;
    return 25.0; 
  }
  isTemperatureSensorValid = true;
  return temp;
}

// Read TDS with multi-sample averaging & temperature compensation
// Normalized to 25°C: EC25 = ECT / [1 + alpha * (T - 25)]
float readTDS(float currentTemp) {
  long sum = 0;
  for (int i = 0; i < 20; i++) {
    sum += analogRead(TDS_PIN);
    delay(2);
  }
  float rawADC = sum / 20.0;
  float voltage = (rawADC / 4095.0) * 3.3;

  // Temperature compensation coefficient (standard alpha = 0.02 / °C normalized to 25°C)
  // Invalid temperature data triggers provisional flag rather than silent assumption
  float compensationCoefficient = 1.0;
  if (isTemperatureSensorValid) {
    compensationCoefficient = 1.0 + 0.02 * (currentTemp - 25.0);
  }
  float compensationVoltage = voltage / compensationCoefficient;

  // Standard Gravity TDS polynomial curve:
  float tds = (133.42 * compensationVoltage * compensationVoltage * compensationVoltage 
              - 255.86 * compensationVoltage * compensationVoltage 
              + 857.39 * compensationVoltage) * 0.5;

  if (tds < 0.0) tds = 0.0;
  return tds;
}

// Read pH with multi-sample averaging & calibration curve
float readPH() {
  long sum = 0;
  for (int i = 0; i < 20; i++) {
    sum += analogRead(PH_PIN);
    delay(2);
  }
  float rawADC = sum / 20.0;
  float voltage = (rawADC / 4095.0) * 3.3;

  // pH probe slope (pH 7.0 calibration at standard 2.5V reference)
  float ph = 7.0 + ((2.50 - voltage) * 3.50);
  return constrain(ph, 0.0, 14.0);
}

// ============================================================
// WATER QUALITY SCORING (0.0 to 100.0%)
// ============================================================

float calculatePHScore(float ph) {
  if (ph >= 6.5 && ph <= 8.5) return 100.0;
  float diff = (ph < 6.5) ? (6.5 - ph) : (ph - 8.5);
  float score = 100.0 - (diff * 25.0);
  return constrain(score, 0.0, 100.0);
}

float calculateTDSScore(float tds) {
  if (tds <= 300.0) return 100.0;
  if (tds <= 500.0) return 100.0 - ((tds - 300.0) / 200.0 * 25.0);
  if (tds <= 1000.0) return 75.0 - ((tds - 500.0) / 500.0 * 45.0);
  if (tds <= 2000.0) return 30.0 - ((tds - 1000.0) / 1000.0 * 30.0);
  return 0.0;
}

float calculateTemperatureScore(float temperature) {
  if (temperature >= 20.0 && temperature <= 30.0) return 100.0;
  float diff = (temperature < 20.0) ? (20.0 - temperature) : (temperature - 30.0);
  float score = 100.0 - (diff * 5.0);
  return constrain(score, 0.0, 100.0);
}

// Weighted percentage: TDS 45%, pH 40%, Temperature 15%
float calculateWaterQuality(float tds, float ph, float temperature) {
  float tdsScore         = calculateTDSScore(tds);
  float phScore          = calculatePHScore(ph);
  float temperatureScore = calculateTemperatureScore(temperature);

  float finalScore = (tdsScore * 0.45) + (phScore * 0.40) + (temperatureScore * 0.15);
  return constrain(finalScore, 0.0, 100.0);
}

// ============================================================
// WATER QUALITY SAFETY MESSAGE
// Rules:
//   70 - 100% → Safe to Drink
//   40 -  69% → Moderate Safe
//   Below  40% → Unsafe to Drink!
// ============================================================
String getWaterQualitySafetyMessage(float quality, float tds, float ph, bool tempValid) {
  if (!tempValid) {
    // Temperature sensor disconnected
    return "Check Temp Probe";
  }

  // SAFE RANGE: 70% to 100%
  if (quality >= 70.0) {
    return "Safe to Drink";
  }
  // MODERATE RANGE: 40% to 69%
  else if (quality >= 40.0) {
    return "Moderate Safe";
  }
  // UNSAFE: below 40%
  else {
    return "Unsafe to Drink!";
  }
}

// ============================================================
// LCD DISPLAY FUNCTION
// PAGE 1 (shown 3 sec): Purity % + Safety Message
// PAGE 2 (shown 3 sec): TDS, pH, Temperature values
// ============================================================
int lcdDisplayCycle = 0;

void updateLCD(float quality, String safetyMessage, float tds, float ph, float temp) {
  lcd.clear();
  lcdDisplayCycle = (lcdDisplayCycle + 1) % 4;

  if (lcdDisplayCycle < 2) {
    // ── PAGE 1: Purity percentage + Safety message ──
    // Line 1: e.g.  "Purity: 93.7%  "
    lcd.setCursor(0, 0);
    lcd.print("Purity:");
    lcd.print(quality, 1);
    lcd.print("%");

    // Line 2: Safe to Drink / Moderate Safe / Unsafe to Drink!
    lcd.setCursor(0, 1);
    lcd.print(safetyMessage);

  } else {
    // ── PAGE 2: Live sensor readings ──
    // Line 1: e.g.  "TDS:412 pH:8.3"
    lcd.setCursor(0, 0);
    lcd.print("TDS:");
    lcd.print((int)tds);
    lcd.print(" pH:");
    lcd.print(ph, 1);

    // Line 2: e.g.  "Temp: 27.0 C" or "Temp: NO SENSOR"
    lcd.setCursor(0, 1);
    if (!isTemperatureSensorValid) {
      lcd.print("Temp: NO SENSOR");
    } else {
      lcd.print("Temp:");
      lcd.print(temp, 1);
      lcd.print(" C");
    }
  }
}

// ============================================================
// WI-FI CONNECTION & AUTO-RECONNECT
// ============================================================
void ensureWiFiConnected() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.println("WiFi reconnecting...");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 8000) {
    delay(300);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi Connection failed. Will retry next cycle.");
  }
}

// ============================================================
// SEND TO THINGSPEAK — HTTPClient (primary method)
// ============================================================
void sendToThingSpeak(float tds, float ph, float temperature, float quality) {
  ensureWiFiConnected();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("SKIP ThingSpeak: No WiFi.");
    return;
  }

  // Always send 25.0 if DS18B20 is disconnected (not -127)
  float safeTemp = isTemperatureSensorValid ? temperature : 25.0;

  String url = "http://api.thingspeak.com/update"
    "?api_key=" + String(THINGSPEAK_API_KEY) +
    "&field1=" + String(tds, 2) +
    "&field2=" + String(ph, 2) +
    "&field3=" + String(safeTemp, 2) +
    "&field4=" + String(quality, 2);

  Serial.println("\n>>> ThingSpeak Upload...");
  Serial.println("URL: " + url);
  Serial.print("RSSI: "); Serial.print(WiFi.RSSI()); Serial.println(" dBm");

  WiFiClient client;
  HTTPClient http;
  http.begin(client, url);
  http.setTimeout(15000);
  http.addHeader("Connection", "close");

  int code = http.GET();
  String body = http.getString();
  http.end();

  Serial.print("HTTP Code: "); Serial.println(code);
  Serial.print("Response : "); Serial.println(body);

  if (code == 200 && body.toInt() > 0) {
    Serial.println("SUCCESS! Entry ID: " + body + " created on ThingSpeak.");
  } else if (code == 200 && body == "0") {
    Serial.println("RATE LIMIT: ThingSpeak needs 15s between uploads. Wait.");
  } else if (code < 0) {
    Serial.println("CONNECTION ERROR " + String(code) + ": Check WiFi/router.");
    Serial.println("Trying raw TCP fallback...");
    // Fallback: raw TCP
    WiFiClient rawClient;
    rawClient.setTimeout(10);
    if (rawClient.connect("api.thingspeak.com", 80)) {
      rawClient.print("GET /update?api_key=" + String(THINGSPEAK_API_KEY)
        + "&field1=" + String(tds,2)
        + "&field2=" + String(ph,2)
        + "&field3=" + String(safeTemp,2)
        + "&field4=" + String(quality,2)
        + " HTTP/1.1\r\nHost: api.thingspeak.com\r\nConnection: close\r\n\r\n");
      delay(2000);
      String resp = rawClient.readString();
      rawClient.stop();
      Serial.println("Raw TCP response: " + resp.substring(0, 60));
    } else {
      Serial.println("Raw TCP also failed. Port 80 may be blocked.");
    }
  } else {
    Serial.println("UNEXPECTED code " + String(code) + ". Check API key.");
  }
}

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1500);
  Serial.println("\n================================");
  Serial.println("Smart Water Monitor v3.0");
  Serial.println("================================");

  // I2C + LCD init with auto-scan
  Wire.begin(21, 22);
  delay(200);
  scanAndInitLCD(); // Auto-finds 0x27 or 0x3F

  if (lcdFound) {
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Smart Water Mon.");
    lcd.setCursor(0, 1); lcd.print("Starting...");
  }

  // DS18B20 init
  temperatureSensor.begin();
  int sensorCount = temperatureSensor.getDeviceCount();
  Serial.print("DS18B20 sensors found: ");
  Serial.println(sensorCount);
  if (sensorCount == 0) {
    Serial.println("  >> No DS18B20 found! Check GPIO32 wiring + 4.7k resistor.");
  }

  // Wi-Fi connection
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi SSID: ");
  Serial.println(WIFI_SSID);

  if (lcdFound) {
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("WiFi Connecting");
    lcd.setCursor(0, 1); lcd.print(WIFI_SSID);
  }

  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 30) {
    delay(500);
    Serial.print(".");
    tries++;
  }

  if (lcdFound) lcd.clear();

  if (WiFi.status() == WL_CONNECTED) {
    String ip = WiFi.localIP().toString();
    Serial.println("\nWiFi Connected! IP: " + ip);
    Serial.print("RSSI: "); Serial.print(WiFi.RSSI()); Serial.println(" dBm");
    if (lcdFound) {
      lcd.setCursor(0, 0); lcd.print("WiFi OK!");
      lcd.setCursor(0, 1); lcd.print(ip);
    }
  } else {
    Serial.println("\nWiFi FAILED! SSID=" + String(WIFI_SSID));
    if (lcdFound) {
      lcd.setCursor(0, 0); lcd.print("WiFi FAILED!");
      lcd.setCursor(0, 1); lcd.print("Check password");
    }
  }
  delay(2500);
}

// ============================================================
// MAIN LOOP
// ============================================================
void loop() {
  float temperature = readTemperature();
  float tds         = readTDS(temperature);
  float ph          = readPH();
  float quality     = calculateWaterQuality(tds, ph, temperature);
  String safetyStatus = getWaterQualitySafetyMessage(quality, tds, ph, isTemperatureSensorValid);

  // Update LCD
  updateLCD(quality, safetyStatus, tds, ph, temperature);

  // Serial Monitor output
  Serial.println("\n========================================");
  Serial.print("TDS (ppm)    : "); Serial.println(tds, 1);
  Serial.print("pH Level     : "); Serial.println(ph, 2);
  Serial.print("Temperature  : "); Serial.print(temperature, 1); Serial.println(" C");
  Serial.print("Purity       : "); Serial.print(quality, 1); Serial.println(" %");
  Serial.print("Status       : "); Serial.println(safetyStatus);
  Serial.print("WiFi         : ");
  Serial.println(WiFi.status() == WL_CONNECTED
    ? "Connected (" + WiFi.localIP().toString() + ")"
    : "DISCONNECTED - check password!");
  Serial.println("========================================");

  // Upload to ThingSpeak every 20 seconds
  unsigned long now = millis();
  if (now - lastUploadTime >= uploadInterval || lastUploadTime == 0) {
    lastUploadTime = now;
    sendToThingSpeak(tds, ph, temperature, quality);
  }

  delay(2000);
}
