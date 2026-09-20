/*
  ================================================================================
  SMART WATER QUALITY MONITORING SYSTEM - ESP32 FIRMWARE
  ================================================================================
  Architecture Flow:
    ESP32 Sensors -> Calculate Score -> Upload to ThingSpeak -> Python Backend -> Flutter
  
  Field Mapping (ThingSpeak Channel 3487158):
    field1 = TDS (ppm)
    field2 = pH
    field3 = Temperature (°C)
    field4 = Water Quality Score (%)
  ================================================================================
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <LiquidCrystal.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// --- CONFIGURATION ---
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* THINGSPEAK_WRITE_API_KEY = "YOUR_THINGSPEAK_WRITE_API_KEY";
const char* THINGSPEAK_URL = "http://api.thingspeak.com/update";

// --- PIN ASSIGNMENTS ---
#define TEMP_PIN       4   // DS18B20 OneWire Temp Sensor
#define PH_PIN         32  // pH Sensor Analog Output (ADC1_CH4)
#define TDS_PIN        34  // TDS Meter Analog Output (ADC1_CH6)
#define TURBIDITY_PIN  35  // Turbidity Sensor Analog Output (ADC1_CH7)

// LCD Pins: RS=19, E=23, D4=18, D5=17, D6=16, D7=15
LiquidCrystal lcd(19, 23, 18, 17, 16, 15);

// OneWire Temperature Setup
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensor(&oneWire);

// Timing variables
unsigned long lastUploadTime = 0;
const unsigned long uploadInterval = 20000; // Upload to ThingSpeak every 20s

// -------------------------------------------------------------------
// WATER QUALITY SCORE CALCULATION (SECTION 5 SPECIFICATION)
// -------------------------------------------------------------------
float calculateWaterQualityScore(float ph, float tds, float temp) {
  // 1. pH Score calculation
  float phScore = 100.0;
  if (ph < 6.5) {
    phScore = 100.0 - (6.5 - ph) * 20.0;
  } else if (ph > 8.5) {
    phScore = 100.0 - (ph - 8.5) * 20.0;
  }
  if (phScore < 0.0) phScore = 0.0;

  // 2. TDS Score calculation
  float tdsScore = 100.0;
  if (tds <= 300.0) {
    tdsScore = 100.0;
  } else if (tds <= 500.0) {
    tdsScore = 100.0 - (tds - 300.0) * (20.0 / 200.0); // 100 -> 80
  } else if (tds <= 1000.0) {
    tdsScore = 80.0 - (tds - 500.0) * (40.0 / 500.0);   // 80 -> 40
  } else if (tds <= 1500.0) {
    tdsScore = 40.0 - (tds - 1000.0) * (40.0 / 500.0);  // 40 -> 0
  } else {
    tdsScore = 0.0;
  }
  if (tdsScore < 0.0) tdsScore = 0.0;

  // 3. Temperature Score calculation
  float tempScore = 100.0;
  if (temp < 20.0) {
    tempScore = 100.0 - (20.0 - temp) * 5.0;
  } else if (temp > 30.0) {
    tempScore = 100.0 - (temp - 30.0) * 5.0;
  }
  if (tempScore < 0.0) tempScore = 0.0;

  // 4. Combined weighted score
  float finalScore = (phScore * 0.40) + (tdsScore * 0.40) + (tempScore * 0.20);
  if (finalScore < 0.0) finalScore = 0.0;
  if (finalScore > 100.0) finalScore = 100.0;

  return finalScore;
}

void connectToWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[Wi-Fi] Connected! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n[Wi-Fi] Connection Failed. Operating offline.");
  }
}

void uploadToThingSpeak(float tds, float ph, float temp, float score) {
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
    if (WiFi.status() != WL_CONNECTED) return;
  }

  HTTPClient http;
  http.setTimeout(5000); // 5 second timeout to prevent ESP32 freeze
  String postData = "api_key=" + String(THINGSPEAK_WRITE_API_KEY) +
                    "&field1=" + String(tds, 1) +
                    "&field2=" + String(ph, 2) +
                    "&field3=" + String(temp, 1) +
                    "&field4=" + String(score, 1);

  http.begin(THINGSPEAK_URL);
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  int httpCode = http.POST(postData);
  if (httpCode > 0) {
    String response = http.getString();
    Serial.println("[ThingSpeak] Upload Success. Entry ID: " + response);
  } else {
    Serial.printf("[ThingSpeak] Upload Failed: %s (Error code %d)\n", http.errorToString(httpCode).c_str(), httpCode);
  }
  http.end();
}

void setup() {
  Serial.begin(115200);

  // Initialize LCD Screen (16 Columns, 2 Rows)
  lcd.begin(16, 2);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("SMART WATER SYS");
  lcd.setCursor(0, 1);
  lcd.print("INITIALIZING...");
  delay(2000);

  // Initialize Temperature Probe
  tempSensor.begin();

  // Configure Analog Pins
  pinMode(PH_PIN, INPUT);
  pinMode(TDS_PIN, INPUT);
  pinMode(TURBIDITY_PIN, INPUT);

  // Initial Wi-Fi connection attempt
  connectToWiFi();

  Serial.println("\n=======================================================");
  Serial.println("   SMART WATER QUALITY MONITORING SYSTEM READY         ");
  Serial.println("=======================================================");
}

void loop() {
  // 1. READ TEMPERATURE (DS18B20)
  tempSensor.requestTemperatures();
  float tempC = tempSensor.getTempCByIndex(0);
  if (tempC < -50 || tempC > 100) {
    tempC = 25.0; // Default fallback temperature if probe disconnected
  }

  // 2. READ pH LEVEL (GPIO 32)
  int rawPH = analogRead(PH_PIN);
  float voltagePH = (rawPH / 4095.0) * 3.3;
  float phValue = 3.5 * voltagePH + 0.5;
  if (phValue < 0.0) phValue = 0.0;
  if (phValue > 14.0) phValue = 14.0;

  // 3. READ TDS VALUE (GPIO 34)
  int rawTDS = analogRead(TDS_PIN);
  float voltageTDS = (rawTDS / 4095.0) * 3.3;
  float tdsValue = (133.42 * voltageTDS * voltageTDS * voltageTDS 
                   - 255.86 * voltageTDS * voltageTDS 
                   + 857.39 * voltageTDS) * 0.5;
  if (tdsValue < 0.0) tdsValue = 0.0;

  // 4. READ TURBIDITY VALUE (GPIO 35)
  int rawTurb = analogRead(TURBIDITY_PIN);
  float voltageTurb = (rawTurb / 4095.0) * 3.3;
  float ntuValue = 0.0;
  if (voltageTurb < 2.5) {
    ntuValue = 3000.0;
  } else {
    ntuValue = -1120.4 * (voltageTurb * voltageTurb) + 5742.3 * voltageTurb - 4353.8;
  }
  if (ntuValue < 0.0) ntuValue = 0.0;

  // 5. CALCULATE WATER QUALITY SCORE
  float qualityScore = calculateWaterQualityScore(phValue, tdsValue, tempC);

  // 6. UPDATE LOCAL LCD SCREEN
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Temp: ");
  lcd.print(tempC, 1);
  lcd.print("C pH:");
  lcd.print(phValue, 1);

  lcd.setCursor(0, 1);
  lcd.print("TDS:");
  lcd.print((int)tdsValue);
  lcd.print(" Q:");
  lcd.print((int)qualityScore);
  lcd.print("%");

  // 7. OUTPUT SERIAL LOG
  Serial.println("-------------------------------------------------------");
  Serial.print("🌡️ Temp : "); Serial.print(tempC, 1); Serial.println(" °C");
  Serial.print("🧪 pH    : "); Serial.print(phValue, 2); Serial.println();
  Serial.print("🧂 TDS   : "); Serial.print(tdsValue, 1); Serial.println(" PPM");
  Serial.print("🌊 Turb  : "); Serial.print(ntuValue, 1); Serial.println(" NTU");
  Serial.print("⭐ Score : "); Serial.print(qualityScore, 1); Serial.println(" %");
  Serial.println("-------------------------------------------------------");

  // 8. UPLOAD TO THINGSPEAK (Controlled Interval)
  if (millis() - lastUploadTime >= uploadInterval) {
    uploadToThingSpeak(tdsValue, phValue, tempC, qualityScore);
    lastUploadTime = millis();
  }

  delay(3000);
}
