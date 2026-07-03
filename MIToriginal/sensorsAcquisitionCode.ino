/* =============================================
  Project Title: Dual MAX31865 PT1000 Temperature Monitor with and ADS1115 ADC for analog devices and a SEN0546
  Description   : Interfaces two MAX31865 PT1000 sensors and an ADS1115 ADC with an ESP32-WROOM-DA
                  to measure and display temperature and humidity readings and analog inputs.
                  Includes fault detection and handling for each sensor.
  Author        : Souha Elmousadik (souhaelm@mit.edu)
  Date Created  : January 25, 2025
  Version       : 1.3
  Hardware      : 
                  - ESP32-WROOM-DA
                  - 2 x MAX31865 PT1000 RTD-to-Digital Converter Modules
                  - 2 x PT1000 RTD Sensors
                  - 1 x ADS1115 ADC Module
                  - SEN0546 Humidity/Temperature Sensor
                  - Additional Analog Sensors ....
  Libraries     : 
                  - Adafruit MAX31865
                  - Adafruit ADS1X15
                  - SPI (Built-in)
                  - Wire (Built-in)
  License       : MIT License
  ============================================= */


#include <Wire.h> 
#include <SPI.h>  
#include <Adafruit_MAX31865.h>
#include <Adafruit_ADS1X15.h>

// ==============================
// Hardware Configuration
// ==============================
#define RREF_PT1000     4300.0 // The value of the Rref resistor. Use 430.0 for PT100 and 4300.0 for PT1000
#define RNOMINAL_PT1000 1000.0 // The 'nominal' 0-degrees-C resistance of the sensor. Use 100.0 for PT100, 1000.0 for PT1000
#define SENSOR_WIRES    MAX31865_3WIRE  // Change to MAX31865_2WIRE if using a 2-wire sensor

// Define Chip Select (CS) pins for both MAX31865 modules
#define MAX31865_CS1    32  // CS pin for Sensor 1
#define MAX31865_CS2    33  // CS pin for Sensor 2

// I2C Configuration for ADS1115
#define ADS1115_ADDRESS   0x48 // Default I2C address (0x48 if ADDR is connected to GND)
#define ADS_SDA_PIN       21   // Default SDA pin on ESP32
#define ADS_SCL_PIN       22   // Default SCL pin on ESP32

// Create MAX31865 sensor instances
Adafruit_MAX31865 thermo_1 = Adafruit_MAX31865(MAX31865_CS1, &SPI); // Use software SPI: CS, DI, DO, CLK
Adafruit_MAX31865 thermo_2 = Adafruit_MAX31865(MAX31865_CS2, &SPI); // Use software SPI: CS, DI, DO, CLK

// Create ADS1115 ADC instance
Adafruit_ADS1115 ads; // Use default I2C address
#define RESISTANCE 221.0 // The value of the current resistor

// Create humidity sensor instance
#define SEN0546_ADDRESS 0x40

String cmd;

// ==============================
// Setup
// ==============================
void setup() {
  Serial.begin(115200);
  Serial.println("Dual MAX31865 PT1000 Temperature Monitor with ADS1115 ADC!");

  // --- Initialize MAX31865 Sensors ---
  initializeSensor(thermo_1, MAX31865_CS1);
  initializeSensor(thermo_2, MAX31865_CS2);

  // --- Initialize ADS1115 ---
  initADS1115(ADS_SDA_PIN, ADS_SCL_PIN);

  // --- Initialize SEN0546 ---
  initSEN0546(ADS_SDA_PIN, ADS_SCL_PIN);
  Serial.println("---------------------------------------------");
}

// ==============================
// Loop
// ==============================
void loop() {
  // Check if there's an incoming command from Python
  if (Serial.available()) {
    cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd == "READ") {
      // Read temperature from Sensor 1 and Sensor 2
      float temp_1 = readTemperature(thermo_1, RREF_PT1000, RNOMINAL_PT1000, MAX31865_CS1);
      float temp_2 = readTemperature(thermo_2, RREF_PT1000, RNOMINAL_PT1000, MAX31865_CS2);

      // Read volages from the ADC 
      float voltage_1 = readADS1115Channel(0);
      float amps_1 = voltage_1*1000.000/RESISTANCE; 
      float voltage_2 = readADS1115Channel(1);

      // Read temperature and humidity from SEN0546
      float temp_3, humidity;
      if (!readSEN0546(temp_3, humidity)) {
        Serial.println("Error reading SEN0546 data.");
        return;
      }
      
      Serial.print(temp_1,3);
      Serial.print(",");
      Serial.print(temp_2,3);
      Serial.print(",");
      Serial.print(humidity,3);
      Serial.print(",");
      Serial.print(amps_1,3);
      Serial.print(",");
      Serial.println(voltage_2,3);
    }
  }

}


// ==============================
// Function Definitions
// ==============================

/**
 * @brief Initializes a MAX31865 sensor with the specified wire configuration.
 * 
 * @param thermo Reference to the MAX31865 sensor instance.
 * @param csPin The Chip Select (CS) pin number for the sensor.
 */
void initializeSensor(Adafruit_MAX31865 &thermo, uint8_t csPin) {
  // Begin communication with the sensor
  bool initialized = thermo.begin(SENSOR_WIRES);
  
  if (!initialized) {
    Serial.print("Error: MAX31865 initialization failed for sensor at CS pin ");
    Serial.println(csPin);
    while (1); // Halt execution
  }
  
  // Optionally set the number of wires explicitly (redundant if already set in begin)
  thermo.setWires(SENSOR_WIRES);
  
  Serial.print("MAX31865 sensor initialized at CS pin ");
  Serial.println(csPin);
}

// ===========================================================================
/**
 * @brief Checks for faults in the MAX31865 sensor and handles them accordingly.
 * 
 * @param thermo Reference to the MAX31865 sensor instance.
 * @param csPin The Chip Select (CS) pin number for the sensor.
 */
void checkAndHandleFaults(Adafruit_MAX31865 &thermo, uint8_t csPin) {
  uint8_t fault = thermo.readFault();
  
  if (fault) {
    Serial.print("Fault detected in sensor at CS pin ");
    Serial.print(csPin);
    Serial.print(": 0x");
    Serial.println(fault, HEX);
    
    // Decode and display each fault
    if (fault & MAX31865_FAULT_HIGHTHRESH) {
      Serial.println(" - RTD High Threshold");
    }
    if (fault & MAX31865_FAULT_LOWTHRESH) {
      Serial.println(" - RTD Low Threshold");
    }
    if (fault & MAX31865_FAULT_REFINLOW) {
      Serial.println(" - REFIN- > 0.85 x REF");
    }
    if (fault & MAX31865_FAULT_REFINHIGH) {
      Serial.println(" - REFIN- < 0.85 x REF - FORCE- open");
    }
    if (fault & MAX31865_FAULT_RTDINLOW) {
      Serial.println(" - RTDIN- < 0.85 x RTD - FORCE- open");
    }
    if (fault & MAX31865_FAULT_OVUV) {
      Serial.println(" - Under/Over Voltage");
    }
    
    // Clear the faults to allow normal operation
    thermo.clearFault();
    Serial.println(" - Faults cleared.");
  }
}

// ===========================================================================
/**
 * @brief Reads the temperature from a MAX31865 sensor.
 * 
 * @param thermo Reference to the MAX31865 sensor instance.
 * @param RREF The reference resistor value in Ohms.
 * @param RNOMINAL The nominal resistance at 0°C for the PT1000 sensor.
 * @param csPin The Chip Select (CS) pin number for the sensor.
 * @return float The measured temperature in Celsius.
 */
float readTemperature(Adafruit_MAX31865 &thermo, const float RREF, const float RNOMINAL, uint8_t csPin) {
  // Read RTD value
  uint16_t rtd = thermo.readRTD();
  
  // Read and handle faults
  checkAndHandleFaults(thermo, csPin);
  
  // Calculate temperature
  float temperature = thermo.temperature(RNOMINAL, RREF);
  
  // Validate temperature reading
  if (isnan(temperature)) {
    Serial.print("Warning: Temperature reading from sensor at CS pin ");
    Serial.print(csPin);
    Serial.println(" failed.");
    return 0.0;
  }
  
  return temperature;
}


// ===========================================================================
/**
 * @brief Initializes the ADS1115 ADC via I2C.
 *
 * @param sdaPin The SDA pin number on the ESP32.
 * @param sclPin The SCL pin number on the ESP32.
 */
void initADS1115(uint8_t sdaPin, uint8_t sclPin) {
  Wire.begin(sdaPin, sclPin);  // Initialize I2C
  if (!ads.begin(ADS1115_ADDRESS)) {
    Serial.println("Failed to initialize ADS1115 ADC.");
    while (1); // Halt execution if ADS1115 fails to initialize
  }
  Serial.println("ADS1115 ADC initialized successfully.");
}

// ===========================================================================
/**
 * @brief Reads a single-ended channel from the ADS1115 and returns its voltage.
 * 
 * @param channel The channel number (0 to 3).
 * @return float The voltage reading of the specified channel.
 */
float readADS1115Channel(uint8_t channel) {
  // Read the raw ADC value
  int16_t adcValue = ads.readADC_SingleEnded(channel);
  float voltage = ads.computeVolts(adcValue)*1.000;

  return voltage;
}

// ===========================================================================
/**
 * @brief Initializes the ADS1115 ADC via I2C.
 *
 * @param sdaPin The SDA pin number on the ESP32.
 * @param sclPin The SCL pin number on the ESP32.
 */
void initSEN0546(uint8_t sdaPin, uint8_t sclPin) {
  Wire.begin(sdaPin, sclPin);  // Initialize I2C
  Wire.beginTransmission(SEN0546_ADDRESS);
  if (Wire.endTransmission() != 0) {
    Serial.println("Failed to initialize SEN0546.");
    while (1); // Halt execution if SEN0546 fails to initialize
  }
  Serial.println("SEN0546 initialized successfully.");
}

// ===========================================================================
/**
 * @brief Reads data from a specified register of the SEN0546 sensor.
 *
 * @param reg The register address to read from.
 * @param[out] buffer The buffer to store the data.
 * @param size The number of bytes to read.
 * @return The number of bytes read successfully, or 0 if an error occurred.
 */
uint8_t readSEN0546Reg(uint8_t reg, uint8_t *buffer, size_t size) {
  Wire.beginTransmission(SEN0546_ADDRESS);
  Wire.write(reg);
  if (Wire.endTransmission() != 0) {
    return 0;
  }
  delay(20);
  Wire.requestFrom(SEN0546_ADDRESS, (uint8_t)size);
  for (size_t i = 0; i < size && Wire.available(); i++) {
    buffer[i] = Wire.read();
  }
  return size;
}

// ===========================================================================
/**
 * @brief Reads temperature and humidity data from the SEN0546 sensor.
 *
 * @param[out] temperature The temperature value in Celsius.
 * @param[out] humidity The relative humidity value in percentage.
 * @return true if the data is read successfully, false otherwise.
 */
bool readSEN0546(float &temperature, float &humidity) {
  uint8_t buffer[4] = {0};
  if (readSEN0546Reg(0x00, buffer, 4) != 4) {
    return false;
  }
  uint16_t tempRaw = (buffer[0] << 8) | buffer[1];
  uint16_t humRaw = (buffer[2] << 8) | buffer[3];
  temperature = ((float)tempRaw * 165.0 / 65535.0) - 40.0;
  humidity = ((float)humRaw * 100.0 / 65535.0);
  return true;
}

