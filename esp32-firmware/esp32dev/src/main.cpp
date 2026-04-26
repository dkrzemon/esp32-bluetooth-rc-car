#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "abcd1234-5678-1234-5678-abcdef123456"

BLECharacteristic *pCharacteristic;

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    std::string value = pCharacteristic->getValue();

    Serial.println("=== WRITE ===");

    if (value.length() > 0) {
      Serial.print("Odebrano: ");
      Serial.println(value.c_str());
    }
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("START BLE");

  BLEDevice::init("RC_CAR");

  BLEServer *server = BLEDevice::createServer();

  BLEService *service = server->createService(SERVICE_UUID);

  pCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ
  );

  pCharacteristic->setCallbacks(new MyCallbacks());

  service->start();

  // 🔥 KLUCZOWE: poprawne advertising
  BLEAdvertising *advertising = BLEDevice::getAdvertising();

  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);

  BLEAdvertisementData scanResponse;
  scanResponse.setName("RC_CAR");

  advertising->setScanResponseData(scanResponse);

  BLEDevice::startAdvertising();

  Serial.println("BLE READY");
}

void loop() {
  delay(1000);
}