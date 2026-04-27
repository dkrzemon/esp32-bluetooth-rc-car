#include <Arduino.h>
#include "ble_server.h"

BLEManager ble;

void setup() {
  Serial.begin(115200);
  delay(1000);

  ble.begin();
}

void loop() {
  ble.loop();
}