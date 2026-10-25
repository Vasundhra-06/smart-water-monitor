/*
  ================================================================================
  AUTO-PIN-DETECT LCD "HI HELLO" TEST SKETCH
  ================================================================================
  Tests all common ESP32 pins in real time every 2 seconds:
    - Pair 1: SDA=21, SCL=22
    - Pair 2: SDA=22, SCL=21 (Reversed)
    - Pair 3: SDA=19, SCL=23
    - Pair 4: SDA=23, SCL=19 (Reversed)
    - Pair 5: SDA=18, SCL=19
    - Pair 6: SDA=4,  SCL=5
    - Pair 7: SDA=16, SCL=17
  
  As soon as the right pins are found, it immediately clears the screen
  and displays "HI HEllo" on your LCD!
  ================================================================================
*/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>

const int pinPairs[][2] = {
  {21, 22}, // Default ESP32
  {22, 21}, // Swapped
  {19, 23}, // Common alternative
  {23, 19},
  {18, 19},
  {4, 5},
  {16, 17}
};

bool lcdFoundAndWorking = false;
int workingSDA = -1;
int workingSCL = -1;
byte workingAddr = 0;

void setup() {
  Serial.begin(115200);
  delay(1500);

  Serial.println("\n=============================================");
  Serial.println("  AUTO-HUNTING LCD TEST SKETCH (HI HEllo)   ");
  Serial.println("=============================================");
}

bool tryAddressOnPins(int sda, int scl, byte addr) {
  Wire.end();
  pinMode(sda, INPUT_PULLUP);
  pinMode(scl, INPUT_PULLUP);
  Wire.begin(sda, scl);
  Wire.setTimeOut(50);

  Wire.beginTransmission(addr);
  if (Wire.endTransmission() == 0) {
    // Found device! Try to initialize LCD
    LiquidCrystal_I2C testLcd(addr, 16, 2);
    testLcd.init();
    testLcd.backlight();
    testLcd.clear();
    testLcd.setCursor(0, 0);
    testLcd.print("       HI       ");
    testLcd.setCursor(0, 1);
    testLcd.print("     HEllo!     ");

    workingSDA = sda;
    workingSCL = scl;
    workingAddr = addr;
    lcdFoundAndWorking = true;

    Serial.println("\n***************************************************");
    Serial.print(">>> BINGO! LCD FOUND AT ADDRESS 0x");
    Serial.println(addr, HEX);
    Serial.print(">>> WORKING PINS: SDA = GPIO ");
    Serial.print(sda);
    Serial.print(" | SCL = GPIO ");
    Serial.println(scl);
    Serial.println(">>> 'HI HEllo' HAS BEEN SENT TO YOUR LCD SCREEN! <<<");
    Serial.println("***************************************************\n");
    return true;
  }
  return false;
}

void loop() {
  if (lcdFoundAndWorking) {
    // Keep LCD refreshed with HI HEllo
    LiquidCrystal_I2C lcd(workingAddr, 16, 2);
    lcd.setCursor(0, 0);
    lcd.print("       HI       ");
    lcd.setCursor(0, 1);
    lcd.print("     HEllo!     ");

    Serial.print("LCD Running Smoothly on SDA=");
    Serial.print(workingSDA);
    Serial.print(", SCL=");
    Serial.print(workingSCL);
    Serial.println(" | Screen: [HI HEllo]");
    delay(2000);
    return;
  }

  // Actively search all pin pairs
  Serial.println("Scanning pins for LCD connection...");

  for (int i = 0; i < 7; i++) {
    int sda = pinPairs[i][0];
    int scl = pinPairs[i][1];

    // Check common addresses 0x27 and 0x3F
    if (tryAddressOnPins(sda, scl, 0x27)) return;
    if (tryAddressOnPins(sda, scl, 0x3F)) return;

    // Check all other addresses
    for (byte addr = 1; addr < 127; addr++) {
      if (addr != 0x27 && addr != 0x3F) {
        if (tryAddressOnPins(sda, scl, addr)) return;
      }
    }
  }

  Serial.println("  --> No LCD response yet.");
  Serial.println("  --> Try wiggling your SDA/SCL wires or swapping them now...\n");

  delay(2000); // Check again every 2 seconds
}
