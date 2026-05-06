#include "ble_server.h"
#include <Arduino.h>
#include "motor.h"

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
// 🔥 PARSE PACKET
// =====================
int speed = 0;
int steer = 0;

void parsePacket(uint8_t *data, int len) {
    if (len < 4) return;
    if (data[0] != 0xA5) return;

    int v = data[1] - 100;
    int s = data[2] - 100;
    int checksum = data[3];

    if (((v ^ s) & 0xFF) != checksum) {
        Serial.println("❌ BAD CHECKSUM");
        return;
    }

    speed = v;
    steer = s;

    Serial.print("V=");
    Serial.println(speed);

    Serial.print("S=");
    Serial.println(steer);

    setSpeed(speed, steer);
}

// =====================
// 🔥 CHARACTERISTIC CALLBACKS
// =====================
class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *characteristic) override {

        std::string value = characteristic->getValue();
        if (value.empty()) return;

        uint8_t *data = (uint8_t*)value.data();
        int len = value.length();

        // ================= HEARTBEAT =================
        if (len == 1 && data[0] == 0x01) {
            lastHeartbeat = millis();
            Serial.println("💓 HEARTBEAT");
            return;
        }

        // ================= DEBUG =================
        Serial.println("---------------- RAW PACKET ----------------");

        for (int i = 0; i < len; i++) {
            Serial.print(data[i]);
            Serial.print(" ");
        }
        Serial.println();

        // ================= COMMAND =================
        parsePacket(data, len);
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

    Serial.println("=== NEW FW BUILD ===");
    Serial.println(CHARACTERISTIC_UUID);
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

    // 🔥 grace period
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