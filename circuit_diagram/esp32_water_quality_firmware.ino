/*
  ================================================================================
  SMART WATER QUALITY MONITORING SYSTEM - ESP32 FIRMWARE v6.0
  ================================================================================
  SYNCHRONIZED APP & LCD DISPLAY:
    - When the App updates Water Quality % and Safety Message,
      the LCD displays the EXACT SAME Percentage & Message simultaneously!
    
  Water Quality Safety Rules (Both App & LCD):
    - 70.0% to 100.0% -> "Safe to Drink"
    - 40.0% to  69.9% -> "Moderate Safe"
    - Below     40.0% -> "Unsafe to Drink!"

  Hardware Pin Connections:
    - DS18B20 Temp Sensor : GPIO 32 (with 4.7k pullup resistor between VCC & DATA)
    - Analog TDS Sensor   : GPIO 35 (ADC1_CH7)
    - Analog pH Sensor    : GPIO 34 (ADC1_CH6)
    - I2C LCD (16x2)      : SDA -> GPIO 21, SCL -> GPIO 22, VCC -> 5V (VIN), GND -> GND

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

// Initialize both 0x27 and 0x3F so the LCD works unconditionally
LiquidCrystal_I2C lcd27(0x27, 16, 2);
LiquidCrystal_I2C lcd3F(0x3F, 16, 2);

// ============================================================
// WI-FI CREDENTIALS
// ============================================================
const char* WIFI_SSID     = "Vasundhra";
const char* WIFI_PASSWORD = "vasundhra06";

// ============================================================
// THINGSPEAK CLOUD CONFIGURATION
// ============================================================
const char* TS_API_KEY = "2UC1FM91LL8THA43"; // Channel 3487158 Write Key
const char* TS_HOST    = "api.thingspeak.com";
const int   TS_PORT    = 80;

// ============================================================
// SENSOR PINS
// ============================================================
#define TEMP_PIN 32  // DS18B20 digital temperature probe
#define TDS_PIN  35  // Analog TDS meter output
#define PH_PIN   34  // Analog pH sensor output

// ============================================================
// TEMPERATURE SENSOR OBJECT
// ============================================================
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensor(&oneWire);
bool isTemperatureSensorValid = true;

// ============================================================
// pH CALIBRATION & FILTERING
// ============================================================
float PH_VOLTAGE_AT_PH7 = 2.50; // Reference voltage when probe is at pH 7.00
float PH_SLOPE          = 3.50; // pH units per Volt change (standard 3.50)
float smoothedPH        = 7.0;
bool  phInitialized     = false;

// ============================================================
// TIMING CONSTANTS (Synchronized 20-Second Refresh Cycle)
// ============================================================
const unsigned long UPDATE_INTERVAL = 20000; // 20 seconds between updates & uploads
unsigned long lastUpdateTime        = 0;
unsigned long lastLcdToggleTime     = 0;
int lcdDisplayMode                  = 0; // 0 = Purity % & Status, 1 = Sensor Readings

// Current synchronized values
float currentTds      = 0.0;
float currentPh       = 7.0;
float currentTemp     = 25.0;
float currentQuality  = 100.0;
String currentStatus  = "Starting...";

// ============================================================
// LCD INITIALIZATION (With I2C Pullups)
// ============================================================
void initLCD() {
  // Enable internal pullups on ESP32 I2C pins for stable communication
  pinMode(21, INPUT_PULLUP);
  pinMode(22, INPUT_PULLUP);
  Wire.begin(21, 22);
  Wire.setClock(100000); // Standard 100kHz I2C speed
  delay(100);

  // Initialize both common I2C addresses
  lcd27.init();
  lcd27.backlight();
  lcd27.clear();
  lcd27.setCursor(0, 0); lcd27.print("Smart Water Mon.");
  lcd27.setCursor(0, 1); lcd27.print("Starting...");

  lcd3F.init();
  lcd3F.backlight();
  lcd3F.clear();
  lcd3F.setCursor(0, 0); lcd3F.print("Smart Water Mon.");
  lcd3F.setCursor(0, 1); lcd3F.print("Starting...");

  Serial.println("LCD Initialized on GPIO 21 & 22 (Addresses 0x27 & 0x3F)");
}

// ============================================================
// SYNCHRONIZED LCD DISPLAY FUNCTION
// Displays Purity % & Safety Message (Exactly matching the App!)
// ============================================================
void syncDisplayOnLCD(float quality, String status, float tds, float ph, float temp, int mode) {
  if (mode == 0) {
    // ── PAGE 1: Water Quality Percentage + Safety Message (Matches App!) ──
    char line1[17];
    char line2[17];
    snprintf(line1, sizeof(line1), "Purity: %-5.1f%% ", quality);
    snprintf(line2, sizeof(line2), "%-16s", status.c_str());

    // Write to both addresses
    lcd27.setCursor(0, 0); lcd27.print(line1);
    lcd27.setCursor(0, 1); lcd27.print(line2);

    lcd3F.setCursor(0, 0); lcd3F.print(line1);
    lcd3F.setCursor(0, 1); lcd3F.print(line2);

    Serial.print("  [LCD SYNC] "); Serial.print(line1); Serial.print(" | "); Serial.println(line2);
  } else {
    // ── PAGE 2: Live Sensor Readings (TDS, pH, Temperature) ──
    char line1[17];
    char line2[17];
    snprintf(line1, sizeof(line1), "TDS:%-3d pH:%-4.1f ", (int)tds, ph);
    if (!isTemperatureSensorValid) {
      snprintf(line2, sizeof(line2), "Temp: NO SENSOR ");
    } else {
      snprintf(line2, sizeof(line2), "Temp: %-4.1f C   ", temp);
    }

    lcd27.setCursor(0, 0); lcd27.print(line1);
    lcd27.setCursor(0, 1); lcd27.print(line2);

    lcd3F.setCursor(0, 0); lcd3F.print(line1);
    lcd3F.setCursor(0, 1); lcd3F.print(line2);
  }
}

// ============================================================
// SENSOR READING FUNCTIONS (With Noise Rejection)
// ============================================================

// 1. Read Temperature from DS18B20 with fallback
float readTemperature() {
  tempSensor.requestTemperatures();
  float temp = tempSensor.getTempCByIndex(0);

  if (temp <= -55.0 || temp == 85.0 || temp > 100.0) {
    isTemperatureSensorValid = false;
    return 25.0; // Safe fallback
  }
  isTemperatureSensorValid = true;
  return temp;
}

// 2. Read TDS with 30-sample average & temperature compensation
float readTDS(float temp) {
  long sum = 0;
  for (int i = 0; i < 30; i++) {
    sum += analogRead(TDS_PIN);
    delay(2);
  }
  float avgADC = (float)sum / 30.0;
  float voltage = (avgADC / 4095.0) * 3.3;

  float coeff = isTemperatureSensorValid ? (1.0 + 0.02 * (temp - 25.0)) : 1.0;
  float compVoltage = voltage / coeff;

  float tds = (133.42 * compVoltage * compVoltage * compVoltage
              - 255.86 * compVoltage * compVoltage
              + 857.39 * compVoltage) * 0.5;

  return max(tds, 0.0f);
}

// 3. Read pH with 40-sample median filter + EMA smoothing
float readPH() {
  const int SAMPLES = 40;
  int rawReadings[SAMPLES];

  for (int i = 0; i < SAMPLES; i++) {
    rawReadings[i] = analogRead(PH_PIN);
    delay(4);
  }

  // Bubble sort samples ascending
  for (int i = 0; i < SAMPLES - 1; i++) {
    for (int j = i + 1; j < SAMPLES; j++) {
      if (rawReadings[i] > rawReadings[j]) {
        int temp = rawReadings[i];
        rawReadings[i] = rawReadings[j];
        rawReadings[j] = temp;
      }
    }
  }

  // Discard 10 lowest and 10 highest outlier spikes (Trimmed Mean)
  long sum = 0;
  for (int i = 10; i < 30; i++) {
    sum += rawReadings[i];
  }
  float avgADC = (float)sum / 20.0;
  float voltage = (avgADC / 4095.0) * 3.3;

  // Calculate pH from calibration curve
  float rawPH = 7.0 + ((PH_VOLTAGE_AT_PH7 - voltage) * PH_SLOPE);
  rawPH = constrain(rawPH, 0.0, 14.0);

  // EMA smoothing: 75% previous + 25% new
  if (!phInitialized) {
    smoothedPH = rawPH;
    phInitialized = true;
  } else {
    smoothedPH = (smoothedPH * 0.75) + (rawPH * 0.25);
  }

  return constrain(smoothedPH, 0.0, 14.0);
}

// ============================================================
// WATER QUALITY SCORING (0.0% to 100.0%)
// ============================================================

float scorePH(float ph) {
  if (ph >= 6.5 && ph <= 8.5) return 100.0;
  float diff = (ph < 6.5) ? (6.5 - ph) : (ph - 8.5);
  return constrain(100.0 - (diff * 25.0), 0.0, 100.0);
}

float scoreTDS(float tds) {
  if (tds <= 300.0) return 100.0;
  if (tds <= 500.0) return 100.0 - ((tds - 300.0) / 200.0 * 25.0);
  if (tds <= 1000.0) return 75.0 - ((tds - 500.0) / 500.0 * 45.0);
  if (tds <= 2000.0) return 30.0 - ((tds - 1000.0) / 1000.0 * 30.0);
  return 0.0;
}

float scoreTemperature(float temp) {
  if (temp >= 20.0 && temp <= 30.0) return 100.0;
  float diff = (temp < 20.0) ? (20.0 - temp) : (temp - 30.0);
  return constrain(100.0 - (diff * 5.0), 0.0, 100.0);
}

// Weighted percentage: TDS 45%, pH 40%, Temp 15%
float calculateQuality(float tds, float ph, float temp) {
  float tdsS  = scoreTDS(tds);
  float phS   = scorePH(ph);
  float tempS = scoreTemperature(temp);
  float total = (tdsS * 0.45) + (phS * 0.40) + (tempS * 0.15);
  return constrain(total, 0.0, 100.0);
}

// ============================================================
// WATER QUALITY SAFETY MESSAGE (Identical to Web App Logic!)
// ============================================================
String getSafetyStatus(float quality) {
  if (!isTemperatureSensorValid) {
    return "Check Temp Probe";
  }
  // 70.0% to 100.0% -> Safe to Drink
  if (quality >= 70.0) {
    return "Safe to Drink";
  }
  // 40.0% to 69.9% -> Moderate Safe
  else if (quality >= 40.0) {
    return "Moderate Safe";
  }
  // Below 40.0% -> Unsafe to Drink!
  else {
    return "Unsafe to Drink!";
  }
}

// ============================================================
// WI-FI AUTO-RECONNECT
// ============================================================
void checkWiFiConnection() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.println("WiFi reconnecting...");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 8000) {
    delay(400);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Reconnected! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi Reconnect failed.");
  }
}

// ============================================================
// THINGSPEAK UPLOAD (Updates the Web App)
// ============================================================
void uploadToThingSpeak(float tds, float ph, float temp, float quality) {
  checkWiFiConnection();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Skip ThingSpeak: No WiFi connection.");
    return;
  }

  float safeTemp = isTemperatureSensorValid ? temp : 25.0;

  String params = "api_key=" + String(TS_API_KEY)
    + "&field1=" + String(tds, 2)
    + "&field2=" + String(ph, 2)
    + "&field3=" + String(safeTemp, 2)
    + "&field4=" + String(quality, 2);

  String request = "GET /update?" + params + " HTTP/1.1\r\nHost: "
    + String(TS_HOST) + "\r\nConnection: close\r\n\r\n";

  Serial.println("\n>>> [CLOUD SYNC] Uploading to ThingSpeak & App...");
  Serial.println("    " + params);

  WiFiClient client;
  client.setTimeout(6); // 6-second timeout (never hangs)
  if (!client.connect(TS_HOST, TS_PORT)) {
    Serial.println("ERROR: Could not connect to ThingSpeak server.");
    return;
  }

  client.print(request);

  unsigned long timeout = millis() + 4000;
  String responseLine = "";
  while (client.connected() && millis() < timeout) {
    if (client.available()) {
      responseLine = client.readStringUntil('\n');
      break;
    }
    delay(10);
  }
  client.stop();

  if (responseLine.indexOf("200") >= 0) {
    Serial.println(">>> SUCCESS: App and LCD are now synchronized with new data!");
  } else {
    Serial.println("ThingSpeak Response: " + responseLine);
  }
}

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1500);

  Serial.println("\n=============================================");
  Serial.println("  SMART WATER QUALITY MONITORING SYSTEM v6.0");
  Serial.println("  SYNCHRONIZED APP & LCD DISPLAY");
  Serial.println("=============================================");

  // Initialize LCD
  initLCD();

  // Initialize Temperature Probe
  tempSensor.begin();
  int tempCount = tempSensor.getDeviceCount();
  Serial.print("DS18B20 sensors detected: ");
  Serial.println(tempCount);

  // Connect to Wi-Fi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    delay(400);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    String ip = WiFi.localIP().toString();
    Serial.println("\nWiFi Connected! IP: " + ip);
  } else {
    Serial.println("\nWiFi Failed! Check credentials.");
  }

  delay(1500);

  // Initial measurement and immediate synchronization
  currentTemp    = readTemperature();
  currentTds     = readTDS(currentTemp);
  currentPh      = readPH();
  currentQuality = calculateQuality(currentTds, currentPh, currentTemp);
  currentStatus  = getSafetyStatus(currentQuality);

  // Synchronize LCD and App immediately at startup
  syncDisplayOnLCD(currentQuality, currentStatus, currentTds, currentPh, currentTemp, 0);
  uploadToThingSpeak(currentTds, currentPh, currentTemp, currentQuality);

  lastUpdateTime    = millis();
  lastLcdToggleTime = millis();
}

// ============================================================
// MAIN LOOP — Updates Both LCD & App Synchronously
// ============================================================
void loop() {
  unsigned long now = millis();

  // 1. Alternate LCD between Page 1 (Purity % + Status) and Page 2 (Values) every 5 seconds
  if (now - lastLcdToggleTime >= 5000) {
    lastLcdToggleTime = now;
    lcdDisplayMode = 1 - lcdDisplayMode; // Toggles between Page 0 and Page 1
    syncDisplayOnLCD(currentQuality, currentStatus, currentTds, currentPh, currentTemp, lcdDisplayMode);
  }

  // 2. Perform Full Measurement, Synchronize LCD & Upload to App Every 20 Seconds
  if (now - lastUpdateTime >= UPDATE_INTERVAL) {
    lastUpdateTime = now;

    // Read fresh sensor data
    currentTemp    = readTemperature();
    currentTds     = readTDS(currentTemp);
    currentPh      = readPH();
    currentQuality = calculateQuality(currentTds, currentPh, currentTemp);
    currentStatus  = getSafetyStatus(currentQuality);

    // Immediately snap LCD back to Page 0 (Purity % & Safety Status matching App!)
    lcdDisplayMode = 0;
    lastLcdToggleTime = now;
    syncDisplayOnLCD(currentQuality, currentStatus, currentTds, currentPh, currentTemp, 0);

    // Print to Serial Monitor
    Serial.println("\n=============================================");
    Serial.println("  [SYNCHRONIZED UPDATE - APP & LCD]");
    Serial.print("  Purity / Quality Score : "); Serial.print(currentQuality, 1); Serial.println(" %");
    Serial.print("  Safety Status Message  : "); Serial.println(currentStatus);
    Serial.print("  TDS Level              : "); Serial.print(currentTds, 1);    Serial.println(" ppm");
    Serial.print("  pH Level               : "); Serial.println(currentPh, 2);
    Serial.print("  Temperature            : "); Serial.print(currentTemp, 1);   Serial.println(" C");
    Serial.print("  WiFi Status            : ");
    Serial.println(WiFi.status() == WL_CONNECTED
      ? "Connected (" + WiFi.localIP().toString() + ")"
      : "DISCONNECTED!");
    Serial.println("=============================================");

    // Send to ThingSpeak so the Web App updates at the exact same moment
    uploadToThingSpeak(currentTds, currentPh, currentTemp, currentQuality);
  }

  delay(50); // Lightweight 50ms loop delay
}
