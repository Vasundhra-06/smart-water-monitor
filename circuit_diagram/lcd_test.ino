#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// Supports both standard I2C addresses (0x27 and 0x3F) automatically
LiquidCrystal_I2C lcd27(0x27, 16, 2);
LiquidCrystal_I2C lcd3F(0x3F, 16, 2);

void setup() {
  Serial.begin(115200);
  
  // ESP32 standard I2C pins: SDA = GPIO 21, SCL = GPIO 22
  Wire.begin(21, 22);

  // Initialize address 0x27
  lcd27.init();
  lcd27.backlight();
  lcd27.clear();
  lcd27.setCursor(0, 0);
  lcd27.print("VASU");
  lcd27.setCursor(0, 1);
  lcd27.print("LCD WORKING!");

  // Initialize address 0x3F (in case your LCD uses 0x3F)
  lcd3F.init();
  lcd3F.backlight();
  lcd3F.clear();
  lcd3F.setCursor(0, 0);
  lcd3F.print("VASU");
  lcd3F.setCursor(0, 1);
  lcd3F.print("LCD WORKING!");

  Serial.println("LCD Test complete - check your display!");
}

void loop() {
}
