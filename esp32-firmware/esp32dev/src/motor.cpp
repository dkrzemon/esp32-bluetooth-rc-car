#include <Arduino.h>
#include "motor.h"

// ===== PINY TB6612FNG =====
// left wheel
#define AIN1 17
#define AIN2 16
#define PWMA 33

// right wheel
#define BIN1 26 //reverse
#define BIN2 25
#define PWMB 27

#define PWM_CHANNEL_A 0
#define PWM_CHANNEL_B 0
#define PWM_FREQ 20000 // frequency for PWM, you can adjust this value based on your needs
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

void setSpeed(int percent) {
    if (!motorInitDone) return;

    // ograniczenie
    percent = constrain(percent, 0, 100);

    // mapowanie na PWM (0–1023)
    int pwm = map(percent, 0, 100, 250, 1023); // 250 minimum for correct motor start, adjust if needed

    // kierunek przód
    digitalWrite(AIN1, LOW);
    digitalWrite(AIN2, HIGH);

    digitalWrite(BIN1, LOW);
    digitalWrite(BIN2, HIGH);

    ledcWrite(PWM_CHANNEL_A, pwm);
    ledcWrite(PWM_CHANNEL_B, pwm);
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

    //soft start
    for (int speed = 300; speed <= 1000; speed += 100) {

        ledcWrite(PWM_CHANNEL_A, speed);
        ledcWrite(PWM_CHANNEL_B, speed);

        delay(20); // im większe → bardziej miękkie hamowanie
    }

    ledcWrite(PWM_CHANNEL_A, 1023); //1023 max
    ledcWrite(PWM_CHANNEL_B, 1023);
}

void stopMotors() {
    if (!motorInitDone) return;

    Serial.println("CMD RECEIVED - STOP");

    /*
    // HAND BRAKE MODE (ACTIVE STOP)
    digitalWrite(AIN1, HIGH);
    digitalWrite(AIN2, HIGH);

    digitalWrite(BIN1, HIGH);
    digitalWrite(BIN2, HIGH);

    ledcWrite(PWM_CHANNEL_A, 0);
    ledcWrite(PWM_CHANNEL_B, 0);
    */

    // 🔥 aktualna prędkość (załóżmy max 1023) SMOOTH BRAKE
    for (int speed = 500; speed >= 0; speed -= 50) {

        ledcWrite(PWM_CHANNEL_A, speed);
        ledcWrite(PWM_CHANNEL_B, speed);

        delay(20); // im większe → bardziej miękkie hamowanie
    }

    // 🔴 na końcu aktywne hamowanie (żeby nie toczył się dalej)
    digitalWrite(AIN1, HIGH);
    digitalWrite(AIN2, HIGH);

    digitalWrite(BIN1, HIGH);
    digitalWrite(BIN2, HIGH);

    ledcWrite(PWM_CHANNEL_A, 0);
    ledcWrite(PWM_CHANNEL_B, 0);
}