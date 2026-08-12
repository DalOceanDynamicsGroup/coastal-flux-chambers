# -*- coding: utf-8 -*-
"""
MAX31865 Temperature Only Logger
"""

import os
import time
import csv
from datetime import datetime

# CircuitPython SPI libraries
import board
import busio
import digitalio
import adafruit_max31865

# -----------------------
# Configuration
# -----------------------
POLLING_RATE = 1.0
BASE_DIR = r"/home/dodg/Data/FluxChamber"

# MAX31865 Settings
RTD_NOMINAL = 1000.0      # Change to 1000.0 if using PT1000 probes
REF_RESISTANCE = 4300.0   # Change to 4300.0 if using PT1000 boards
RTD_WIRES = 3            # Change to 2 or 4 depending on your probe wires

# -----------------------
# File Setup
# -----------------------
os.makedirs(BASE_DIR, exist_ok=True)

LOGFILE = os.path.join(
    BASE_DIR,
    f"tempTest_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.csv"
)

# Initialize the file with headers
with open(LOGFILE, 'w', newline="", encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(["PREFIX", "TIMESTAMP", "ELAPSED_SEC", "TEMP_A", "TEMP_B"])

# -----------------------
# MAIN LOOP
# -----------------------
def main():
    print("Initializing MAX31865 boards on SPI0...")
    try:
        # Create shared SPI0 Bus (Pins: SCLK=GPIO11, MOSI=GPIO10, MISO=GPIO9)
        spi = busio.SPI(board.SCK, board.MOSI, board.MISO)

        # Set up separate Chip Select Pins (GPIO 25 and GPIO 7)
        cs_a = digitalio.DigitalInOut(board.D25)
        cs_b = digitalio.DigitalInOut(board.D7)

        # Create sensor objects
        sensor_a = adafruit_max31865.MAX31865(
            spi, cs_a, 
            rtd_nominal=RTD_NOMINAL, 
            ref_resistor=REF_RESISTANCE, 
            wires=RTD_WIRES
        )
        sensor_b = adafruit_max31865.MAX31865(
            spi, cs_b, 
            rtd_nominal=RTD_NOMINAL, 
            ref_resistor=REF_RESISTANCE, 
            wires=RTD_WIRES
        )
        print("Hardware ready!")
    except Exception as e:
        print("Fatal Error initializing hardware boards:", e)
        return

    start_time = time.time()

    print(f"\nLogging temperature data to: {LOGFILE}")
    print("Press Ctrl+C to stop logging.\n")

    # Open log file in append mode
    with open(LOGFILE, 'a', encoding='utf-8') as f:
        try:
            while True:
                loop_start = time.time()

                # Get timestamps
                now = datetime.now()
                ms = now.microsecond // 1000
                timestamp = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{ms:03d}"
                # elapsed = time.time() - start_time

                # Initialize readings to NaN in case a read fails
                temp_a = float('nan')
                temp_b = float('nan')

                # Read Board A (GPIO 8)
                try:
                    temp_a = sensor_a.temperature
                except Exception as e:
                    print("Error reading Sensor A (GPIO8):", e)

                # Read Board B (GPIO 7)
                try:
                    temp_b = sensor_b.temperature
                except Exception as e:
                    print("Error reading Sensor B (GPIO7):", e)

                # Format the text line matching your style preference
                therm_line = f"{temp_a:.2f},{temp_b:.2f}"

                # Print directly to your screen shell
                print(f"{timestamp} | THERM: {therm_line}")

                # Save directly to your data file
                f.write(f"THERM,{timestamp},{therm_line}\n")
                f.flush()

                # Maintain steady execution loop timing
                dt = time.time() - loop_start
                time.sleep(max(0, POLLING_RATE - dt))

        except KeyboardInterrupt:
            print("\nLogging stopped manually by user.")
        except Exception as e:
            print(f"\nAn unexpected loop error occurred: {e}")

if __name__ == "__main__":
    main()
