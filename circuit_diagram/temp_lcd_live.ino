/*
  ========================================================================
  LIVE WATER TEMPERATURE SENSOR + 16x2 I2C LCD DISPLAY
  ========================================================================
  Hardware Pins:
    - Temperature Sensor Yellow Wire ➔ ESP32 GPIO 32 (D32)
    - LCD SDA                        ➔ ESP32 GPIO 21 (D21)
    - LCD SCL                        ➔ ESP32 GPIO 22 (D22)
    - LCD VCC                        ➔ ESP32 VIN (5V)
    - LCD GND                        ➔ ESP32 GND
  ========================================================================
*/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <OneWire.h>
#include <DallasTemperature.h>

#define TEMP_PIN 32

OneWire oneWire(TEMP_PIN);
DallasTemperature sensors(&oneWire);

// Default to 0x27, auto-detects 0x3F in setup()
LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n==========================================");
  Serial.println("  WATER TEMPERATURE + LCD DISPLAY         ");
  Serial.println("==========================================");

  // 1. Start Temperature Sensor on D32
  sensors.begin();
  Serial.println("Temp sensor initialized on D32.");

  // 2. Start I2C bus on D21 & D22
  Wire.begin(21, 22);
  delay(100);

  // 3. Detect LCD Address (0x27 or 0x3F)
  byte addr = 0x27;
  Wire.beginTransmission(0x27);
  if (Wire.endTransmission() != 0) {
    Wire.beginTransmission(0x3F);
    if (Wire.endTransmission() == 0) {
      addr = 0x3F;
      Serial.println("LCD found at address 0x3F");
    } else {
      Serial.println("Notice: If screen is blank, verify D21(SDA) and D22(SCL)");
    }
  } else {
    Serial.println("LCD found at address 0x27");
  }

  // 4. Initialize LCD
  lcd = LiquidCrystal_I2C(addr, 16, 2);
  lcd.init();
  lcd.backlight();
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print("  SMART WATER   ");
  lcd.setCursor(0, 1);
  lcd.print(" MONITOR SYSTEM ");
  delay(2000);
  lcd.clear();
}

void loop() {
  // Read live temperature from probe on D32
  sensors.requestTemperatures();
  float temp = sensors.getTempCByIndex(0);

  // Print to Serial Monitor
  Serial.print("Live Water Temp: ");
  Serial.print(temp, 1);
  Serial.println(" °C");

  // Display on LCD
  lcd.setCursor(0, 0);
  lcd.print("WATER TEMP:     ");

  lcd.setCursor(0, 1);
  if (temp <= -50.0 || temp >= 85.0) {
    lcd.print("CHECK PROBE...  ");
  } else {
    // Condition label based on temperature
    String condition = "NORMAL";
    if (temp < 20.0) condition = "COLD  ";
    if (temp > 35.0) condition = "WARM  ";

    char line2[17];
    // \xDF is the degree symbol (°) on 1602 LCDs
    snprintf(line2, sizeof(line2), " %.1f\xDFC  [%s]", temp, condition.c_str());
    lcd.print(line2);
  }

  delay(1000); // Live updates every 1 second
}
