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
// 🔥 CHARACTERISTIC CALLBACKS (FIXED)
// =====================
class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *characteristic) override {
        
        std::string raw = characteristic->getValue();
        if (raw.empty()) return;
        
        // 🔥 bezpieczne kopiowanie
        String cmd = String(raw.data(), raw.length());
        cmd.trim();
        
        // 🔥 ignoruj śmieci (np. dziwne znaki)
        if (cmd.length() == 0 || cmd.length() > 10) return;
        
        // =====================
        // 💓 HEARTBEAT
        // =====================
        if (cmd == "H") {
            lastHeartbeat = millis();
            Serial.println("💓 HEARTBEAT");
            return;
        }

        // =====================
        // 🚗 SPEED (V0–V100)
        // =====================
        if (cmd.startsWith("V")) {
        
            // 🔥 sprawdź czy reszta to liczba
            String numStr = cmd.substring(1);
        
            for (int i = 0; i < numStr.length(); i++) {
                if (!isDigit(numStr[i])) {
                    Serial.println("❌ INVALID SPEED DATA");
                    return;
                }
            }
        
            int value = numStr.toInt();
        
            // 🔥 zakres bezpieczeństwa
            if (value < 0 || value > 100) {
                Serial.println("❌ SPEED OUT OF RANGE");
                return;
            }
        
            Serial.print("SPEED: ");
            Serial.println(value);
        
            setSpeed(value);
            return;
        }

        // =====================
        // 🛑 STOP
        // =====================
        if (cmd == "S") {
            stopMotors();
            Serial.println("STOP");
            return;
        }

        // =====================
        // ❌ NIEZNANA KOMENDA
        // =====================
        Serial.print("❌ UNKNOWN CMD: ");
        Serial.println(cmd);
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