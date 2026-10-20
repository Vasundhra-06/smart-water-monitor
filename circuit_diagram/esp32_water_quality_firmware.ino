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
// LCD CONFIGURATION (I2C)
// Default ESP32 I2C pins: SDA = 21, SCL = 22
// Address is commonly 0x27 or 0x3F
// ============================================================
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ============================================================
// WI-FI CREDENTIALS
// ============================================================
const char* WIFI_SSID     = "Mickymouse";
const char* WIFI_PASSWORD = "priyanka.m";

// ============================================================
// THINGSPEAK CLOUD CONFIGURATION
// ============================================================
const char* THINGSPEAK_WRITE_API_KEY = "7W0H8Z3RN171CGD8";
const char* THINGSPEAK_URL           = "https://api.thingspeak.com/update";

// Optional local backend URL (set to "" or keep with low timeout)
const char* WEB_API_URL = ""; 

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

// Timing variables (Upload every 20 seconds)
unsigned long lastUploadTime = 0;
const unsigned long uploadInterval = 20000; // 20,000 ms = 20 seconds

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

// BIS IS 10500 assessment string for LCD Line 2
// Scientific disclaimer: probes monitor physicochemical indicators; microbial testing required.
String getWaterQualityStatus(float tds, float ph, bool tempValid) {
  if (!tempValid) {
    return "Prov: Temp Err";
  }
  if (ph < 6.5 || ph > 8.5) {
    return "pH Out of Range";
  }
  if (tds > 2000.0) {
    return "TDS > 2000 Perm";
  }
  if (tds > 500.0) {
    return "TDS > 500 Accept";
  }
  if (tds > 300.0) {
    return "TDS > 300 Target";
  }
  return "Limits Normal";
}

// ============================================================
// LCD DISPLAY FUNCTION (16x2 Display with Alternating Page View)
// ============================================================
int lcdDisplayCycle = 0;

void updateLCD(float quality, String status, float tds, float ph, float temp) {
  lcd.clear();
  lcdDisplayCycle = (lcdDisplayCycle + 1) % 4;

  if (lcdDisplayCycle < 2) {
    // Page 1: Telemetry readings
    // Line 1: TDS and pH
    lcd.setCursor(0, 0);
    lcd.print("TDS:");
    lcd.print((int)tds);
    lcd.print(" pH:");
    lcd.print(ph, 1);

    // Line 2: Temperature & Quality Score
    lcd.setCursor(0, 1);
    if (!isTemperatureSensorValid) {
      lcd.print("T:ERR  Q:");
    } else {
      lcd.print("T:");
      lcd.print(temp, 1);
      lcd.print("C Q:");
    }
    lcd.print((int)quality);
    lcd.print("%");
  } else {
    // Page 2: BIS IS 10500 Status & Laboratory Verification Notice
    // Line 1: Status Classification
    lcd.setCursor(0, 0);
    lcd.print(status.substring(0, 16));

    // Line 2: Mandatory scientific verification reminder
    lcd.setCursor(0, 1);
    lcd.print("Lab Verif Req.");
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
// SEND TELEMETRY TO THINGSPEAK (Every 20 Seconds)
// ============================================================
void sendToThingSpeak(float tds, float ph, float temperature, float quality) {
  ensureWiFiConnected();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("ThingSpeak: Skipped (No WiFi)");
    return;
  }

  HTTPClient http;
  String url = String(THINGSPEAK_URL) +
               "?api_key=" + THINGSPEAK_WRITE_API_KEY +
               "&field1=" + String(tds, 2) +
               "&field2=" + String(ph, 2) +
               "&field3=" + String(temperature, 2) +
               "&field4=" + String(quality, 2);

  Serial.println("\n>>> Uploading to ThingSpeak Channel 3487158...");
  Serial.println(url);

  http.begin(url);
  http.setTimeout(7000); // 7s timeout to prevent blocking
  int httpCode = http.GET();
  Serial.print("ThingSpeak HTTP Code: ");
  Serial.println(httpCode);

  if (httpCode == 200) {
    String response = http.getString();
    Serial.print("Entry ID Created: ");
    Serial.println(response);
  } else {
    Serial.print("Upload failed with error code: ");
    Serial.println(httpCode);
  }
  http.end();
}

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  // Initialize I2C Bus & LCD
  Wire.begin(21, 22); // Explicit SDA=21, SCL=22
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Smart Water Mon.");
  lcd.setCursor(0, 1);
  lcd.print("Connecting WiFi");

  // Initialize DS18B20 OneWire Sensor
  temperatureSensor.begin();

  // Connect to WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);

  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 20) {
    delay(500);
    Serial.print(".");
    tries++;
  }

  lcd.clear();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected! IP: " + WiFi.localIP().toString());
    lcd.setCursor(0, 0);
    lcd.print("WiFi Connected!");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP());
  } else {
    Serial.println("\nWiFi Timeout, continuing in offline buffer mode...");
    lcd.setCursor(0, 0);
    lcd.print("WiFi Offline");
    lcd.setCursor(0, 1);
    lcd.print("Local Monitoring");
  }
  delay(2000);
}

// ============================================================
// MAIN LOOP
// ============================================================
void loop() {
  // 1. Read real sensor values from water
  float temperature = readTemperature();
  float tds         = readTDS(temperature);
  float ph          = readPH();

  // 2. Calculate Purity Score & Category
  float quality     = calculateWaterQuality(tds, ph, temperature);
  String status     = getWaterQualityStatus(tds, ph, isTemperatureSensorValid);

  // 3. Update LCD Screen in Real-Time
  updateLCD(quality, status, tds, ph, temperature);

  // 4. Print telemetry to Serial Monitor
  Serial.println("\n========================================");
  Serial.print("TDS (ppm)      : "); Serial.println(tds, 1);
  Serial.print("pH Level       : "); Serial.println(ph, 2);
  Serial.print("Temperature    : "); Serial.print(temperature, 1); Serial.println(" C");
  Serial.print("Purity Quality : "); Serial.print(quality, 1); Serial.println(" %");
  Serial.print("Status         : "); Serial.println(status);
  Serial.println("========================================");

  // 5. Send to ThingSpeak every 20 seconds (non-blocking)
  unsigned long currentMillis = millis();
  if (currentMillis - lastUploadTime >= uploadInterval || lastUploadTime == 0) {
    lastUploadTime = currentMillis;
    sendToThingSpeak(tds, ph, temperature, quality);
  }

  // 2-second sampling interval for responsive LCD display
  delay(2000);
}
