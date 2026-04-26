#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

#define SERVICE_UUID        "12345678-1234-1234-1234-1234abcd5678"
#define CHARACTERISTIC_UUID "abcd1234-5678-1234-5678-abcdef123456"

BLECharacteristic *pCharacteristic;

bool deviceConnected = false;

unsigned long lastHeartbeat = 0;
unsigned long connectTime = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    connectTime = millis();
    lastHeartbeat = millis();

    Serial.println("🔵 CONNECTED");
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;

    Serial.println("🔴 DISCONNECTED");

    BLEDevice::startAdvertising();
    Serial.println("♻️ ADVERTISING RESTARTED");
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    std::string value = pCharacteristic->getValue();

    if (value.length() == 0) return;

    String cmd = String(value.c_str());

    // 🔥 HEARTBEAT
    if (cmd == "H") {
      lastHeartbeat = millis();
      Serial.println("💓 HEARTBEAT");
      return;
    }

    Serial.print("CMD: ");
    Serial.println(cmd);

    if (cmd == "F") Serial.println("FORWARD");
    else if (cmd == "B") Serial.println("BACK");
    else if (cmd == "L") Serial.println("LEFT");
    else if (cmd == "R") Serial.println("RIGHT");
    else if (cmd == "S") Serial.println("STOP");
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);

  BLEDevice::init("RC_CAR");

  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  pCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );

  pCharacteristic->setCallbacks(new MyCallbacks());

  service->start();

  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);

  BLEAdvertisementData data;
  data.setName("RC_CAR");
  adv->setScanResponseData(data);

  BLEDevice::startAdvertising();

  Serial.println("BLE READY");
}

void loop() {

  // 🔥 heartbeat działa zawsze gdy jesteśmy po connect (przed disconnect event)
  if (deviceConnected) {

    // GRACE PERIOD
    if (millis() - connectTime < 5000) {
      delay(200);
      return;
    }

    if (millis() - lastHeartbeat > 3000) {
      Serial.println("💀 HEARTBEAT LOST → FORCE DISCONNECT");

      deviceConnected = false;

      BLEDevice::startAdvertising();
      Serial.println("♻️ ADVERTISING RESTARTED");
    }
  }

  delay(200);
}