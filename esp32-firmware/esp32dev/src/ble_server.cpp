#include "ble_server.h"
#include <Arduino.h>

#define SERVICE_UUID        "12345678-1234-1234-1234-1234abcd5678"
#define CHARACTERISTIC_UUID "abcd1234-5678-1234-5678-abcdef123456"

BLECharacteristic *pCharacteristic;
BLEServer *pServer;

bool deviceConnected = false;

unsigned long lastHeartbeat = 0;
unsigned long connectTime = 0;

// =====================
// 🔥 SERVER CALLBACKS
// =====================
class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* server) override {
        deviceConnected = true;
        connectTime = millis();
        lastHeartbeat = millis();

        Serial.println("🔵 CONNECTED");
    }

    void onDisconnect(BLEServer* server) override {
        deviceConnected = false;

        Serial.println("🔴 DISCONNECTED");

        BLEDevice::startAdvertising();
        Serial.println("♻️ ADVERTISING RESTARTED");
    }
};

// =====================
// 🔥 CHARACTERISTIC CALLBACKS (FIXED)
// =====================
class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *characteristic) override {

        std::string value = characteristic->getValue();
        if (value.length() == 0) return;

        // 🔥 SAFE PARSING (NO GARBAGE / NO CRASH / NO "����T")
        String cmd = "";
        for (int i = 0; i < value.length(); i++) {
            cmd += value[i];
        }

        cmd.trim();

        // =====================
        // 🔥 HEARTBEAT
        // =====================
        if (cmd == "H") {
            lastHeartbeat = millis();
            Serial.println("💓 HEARTBEAT");
            return;
        }

        // =====================
        // 🔥 DEBUG COMMAND
        // =====================
        Serial.print("CMD: ");
        Serial.println(cmd);

        if (cmd == "F") Serial.println("FORWARD");
        else if (cmd == "B") Serial.println("BACK");
        else if (cmd == "L") Serial.println("LEFT");
        else if (cmd == "R") Serial.println("RIGHT");
        else if (cmd == "S") Serial.println("STOP");
    }
};

// =====================
// 🔥 INIT
// =====================
void BLEManager::begin() {
    BLEDevice::init("RC_CAR");

    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService *service = pServer->createService(SERVICE_UUID);

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

// =====================
// 🔥 LOOP
// =====================
void BLEManager::loop() {

    if (!deviceConnected) {
        delay(200);
        return;
    }

    // 🔥 grace period (po connect)
    if (millis() - connectTime < 5000) {
        return;
    }

    // 🔥 HEARTBEAT TIMEOUT
    if (millis() - lastHeartbeat > 3000) {
        Serial.println("💀 HEARTBEAT LOST → FORCE DISCONNECT");

        pServer->disconnect(pServer->getConnId());
    }

    delay(200);
}