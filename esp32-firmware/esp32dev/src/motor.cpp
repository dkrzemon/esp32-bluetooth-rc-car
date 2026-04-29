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
#define PWM_CHANNEL_B 1
#define PWM_FREQ 15000 // frequency for PWM, you can adjust this value based on your needs
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

    stopMotors(0);

    Serial.println("MOTORS INIT OK");
}

void setSpeed(int percent) {
    if (!motorInitDone) return;

    if(percent > 0){
        // kierunek przód
        digitalWrite(AIN1, LOW);
        digitalWrite(AIN2, HIGH);

        digitalWrite(BIN1, LOW);
        digitalWrite(BIN2, HIGH);
    } 
    else if (percent < 0) {
        // kierunek tył
        digitalWrite(AIN1, HIGH);
        digitalWrite(AIN2, LOW);

        digitalWrite(BIN1, HIGH);
        digitalWrite(BIN2, LOW);
    }
     else {
        // STOP
        stopMotors(0);
        return;
    }

    // 🔥 PRĘDKOŚĆ (BEZ ZNAKU)
    int velocity = abs(percent);
    velocity = constrain(velocity, 0, 100);
    Serial.println("CONSTRAINED VELOCITY: " + String(velocity));

    // 🔥 DEADZONE
    if (velocity <= 5) {
        stopMotors(0);
        return;
    }

    int pwm = map(velocity, 0, 100, 250, 1023); // 250 minimum for correct motor start, adjust if needed
    Serial.println("PWM: " + String(pwm));

    ledcWrite(PWM_CHANNEL_A, pwm);
    ledcWrite(PWM_CHANNEL_B, pwm);

    return;
}

void stopMotors(int pwm) {
    if (!motorInitDone) return;

    Serial.println("CMD RECEIVED - STOP");

    // 🔴 na końcu aktywne hamowanie (żeby nie toczył się dalej)
    digitalWrite(AIN1, HIGH);
    digitalWrite(AIN2, HIGH);

    digitalWrite(BIN1, HIGH);
    digitalWrite(BIN2, HIGH);

    ledcWrite(PWM_CHANNEL_A, 0);
    ledcWrite(PWM_CHANNEL_B, 0);
}