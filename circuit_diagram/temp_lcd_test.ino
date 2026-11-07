#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// Try GPIO 4 or GPIO 32 for temperature probe
#define TEMP_PIN 4 

OneWire oneWire(TEMP_PIN);
DallasTemperature sensors(&oneWire);

// We will create the LCD object dynamically AFTER detecting the address
LiquidCrystal_I2C* lcd = nullptr;
byte lcdAddress = 0;

void setup() {
  Serial.begin(115200);
  delay(1500);

  Serial.println("\n==========================================");
  Serial.println("  ESP32 LCD + TEMPERATURE TEST            ");
  Serial.println("==========================================");

  // 1. Initialize I2C Pins (SDA=21, SCL=22)
  Wire.begin(21, 22);
  Wire.setTimeOut(50);
  delay(100);

  // 2. Scan for LCD Address (0x27 or 0x3F)
  Serial.print("Checking LCD address... ");
  Wire.beginTransmission(0x27);
  if (Wire.endTransmission() == 0) {
    lcdAddress = 0x27;
    Serial.println("Found LCD at 0x27!");
  } else {
    Wire.beginTransmission(0x3F);
    if (Wire.endTransmission() == 0) {
      lcdAddress = 0x3F;
      Serial.println("Found LCD at 0x3F!");
    } else {
      Serial.println("FAILED! No LCD found on D21/D22.");
      Serial.println("Please check: VCC->VIN(5V), GND->GND, SDA->D21, SCL->D22.");
    }
  }

  // 3. Initialize LCD if found
  if (lcdAddress != 0) {
    lcd = new LiquidCrystal_I2C(lcdAddress, 16, 2);
    lcd->init();
    lcd->backlight();
    lcd->clear();
    lcd->setCursor(0, 0);
    lcd->print("TEMP MONITOR");
    lcd->setCursor(0, 1);
    lcd->print("STARTING...");
    Serial.println("LCD Initialized and Backlight ON!");
  }

  // 4. Initialize Temperature Sensor (with internal pullup)
  pinMode(TEMP_PIN, INPUT_PULLUP);
  sensors.begin();
  int count = sensors.getDeviceCount();
  Serial.print("Temperature sensors found on GPIO ");
  Serial.print(TEMP_PIN);
  Serial.print(": ");
  Serial.println(count);

  delay(2000);
  if (lcd != nullptr) lcd->clear();
}

void loop() {
  // Read temperature
  sensors.requestTemperatures();
  float temp = sensors.getTempCByIndex(0);

  Serial.print("Live Temp: ");
  Serial.print(temp, 1);
  Serial.println(" C");

  if (lcd != nullptr) {
    if (temp <= -50.0 || temp >= 85.0 || temp == DEVICE_DISCONNECTED_C) {
      lcd->setCursor(0, 0);
      lcd->print("TEMP: SENSOR ERR");
      lcd->setCursor(0, 1);
      lcd->print("CHECK PROBE WIRE");
    } else {
      lcd->setCursor(0, 0);
      lcd->print("WATER TEMP:     ");
      
      char line2[17];
      snprintf(line2, sizeof(line2), "   %.1f %cC       ", temp, 223); // 223 is ° symbol
      lcd->setCursor(0, 1);
      lcd->print(line2);
    }
  }

  delay(1000);
}
