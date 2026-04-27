#include <Arduino.h>
#include "motor.h"

// ===== PINY TB6612FNG =====
// left wheel
#define AIN1 17
#define AIN2 16
#define PWMA 33

// right wheel
#define BIN1 3
#define BIN2 1
#define PWMB 27

#define PWM_CHANNEL_A 0
#define PWM_CHANNEL_B 0
#define PWM_FREQ 5000 // frequency for PWM, you can adjust this value based on your needs
#define PWM_RES 10 // 10-bit resolution: duty cycle can be from 0 to 1023

static bool motorInitDone = false;

void setupMotors() {
    pinMode(AIN1, OUTPUT);
    pinMode(AIN2, OUTPUT);
    
    ledcSetup(PWM_CHANNEL_A, PWM_FREQ, PWM_RES);
    ledcAttachPin(PWMA, PWM_CHANNEL_A);

    pinMode(BIN1, OUTPUT);
    pinMode(BIN2, OUTPUT);
    ledcSetup(PWM_CHANNEL_B, PWM_FREQ, PWM_RES);
    ledcAttachPin(PWMB, PWM_CHANNEL_B);

    motorInitDone = true;

    stopMotors();

    Serial.println("MOTORS INIT OK");
}

void forward() {
    if (!motorInitDone) {
        Serial.println("❌ MOTOR NOT INIT YET");
        return;
    }

    Serial.println("CMD RECEIVED - FORWARD");
    
    digitalWrite(AIN1, LOW);
    digitalWrite(AIN2, HIGH);

    digitalWrite(BIN1, LOW);
    digitalWrite(BIN2, HIGH);

    ledcWrite(PWM_CHANNEL_A, 500); //1023 max
    ledcWrite(PWM_CHANNEL_B, 500);
}

void stopMotors() {
    if (!motorInitDone) return;

    Serial.println("CMD RECEIVED - STOP");

    digitalWrite(AIN1, LOW);
    digitalWrite(AIN2, LOW);

    digitalWrite(BIN1, LOW);
    digitalWrite(BIN2, LOW);

    ledcWrite(PWM_CHANNEL_A, 0);
    ledcWrite(PWM_CHANNEL_B, 0);
}