#include <Arduino.h>
#include "ble_server.h"
#include "motor.h"

BLEManager ble;

void setup() {
  Serial.begin(115200);
  delay(1000);

  setupMotors();

  ble.begin();
}

void loop() {
  ble.loop();
}