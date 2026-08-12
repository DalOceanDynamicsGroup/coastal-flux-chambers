# -*- coding: utf-8 -*-
"""
Created on Thu Jan 30 12:31:11 2025

@author: souhaelmousadik
 """
import os
import serial
import time
import csv
import re
import numpy as np
from datetime import datetime
from pymodbus.client import ModbusSerialClient as ModbusClient
import struct

# -----------------------
# User configuration
# -----------------------
POLLING_RATE = 1.0 # seconds
BASE_DIR = r"C:\Users\endla\Desktop\Flux Chamber Project\Data" # specify path to the data folder


# -----------------------
# Reference Node Configuration
# -----------------------
REF_ADDRESS  = 3
REF_PORT     = 'COM7'  # or e.g., 'COM4' on Windows
REF_BAUDRATE = 19200
REF_PARITY   = 'N'
REF_STOPBITS = 2
REF_BYTESIZE = 8
REF_TIMEOUT  = 1

# -----------------------
# Sample Node Configuration
# -----------------------
NOD_ADDRESS  = 4
NOD_PORT     = 'COM6'  # or e.g., 'COM5' on Windows
NOD_BAUDRATE = 19200
NOD_PARITY   = 'N'
NOD_STOPBITS = 2
NOD_BYTESIZE = 8
NOD_TIMEOUT  = 1

# -----------------------
# Sample ESP32 Configuration
# -----------------------
SERIAL_PORT = 'COM5'  # Change to your port, e.g. 'COM3', '/dev/ttyUSB0', etc.
BAUD_RATE = 115200                      # Must match your ESP32's Serial.begin() baud rate


# -----------------------
# Ceate the data file
# -----------------------
os.makedirs(BASE_DIR, exist_ok=True)
HEADER = ["TIME", "RUNTIME", "pCO2", "pCO2 VOLTAGE", "pH", "pH CURRENT", "TEMP 1", "TEMP 2", "HUMIDITY", "REF pCO2", "REF TEMP", "SAMPLE pCO2", "SAMPLE TEMP", "CALCULATED FLUX"]
UNITS = [["YYYY-MM-DD hh:mm:ss:fff", "seconds", "ppm", "V", " ", "mA", "C", "C", "%", "ppm", "C", "ppm", "C", "umol/m2/s"]]

LOGFILE = os.path.join(
    BASE_DIR,
    f"fluxChamber_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.csv"
)

# Write the header and units rows once at the start
with open(LOGFILE, mode='w', newline="") as file:
    writer = csv.writer(file)
    writer.writerow(HEADER)
    writer.writerows(UNITS)


def extract_calibration(calibration_file):
    sensor_data = np.empty((4, 3), dtype=object)

    # Read the contents of the calibration file
    with open(calibration_file, "r") as file:
        text = file.read()

    # Define regex patterns for extracting the sensor information
    sensor_pattern = r"(.*?)\s*calibration date: (\d{4}-\d{2}-\d{2})\s*Slope:\s*([-+]?\d*\.\d+|\d+),\s*Intercept:\s*([-+]?\d*\.\d+|\d+)"

    # Find all matches
    matches = re.findall(sensor_pattern, text)

    print("============ Calibration data ===============")
    # Process and print extracted information and assign values to the matrix
    for idx, match in enumerate(matches):
        print("------")
        sensor_name, calibration_date, slope, intercept = match
        print(f"Sensor: {sensor_name}")
        print(f"Calibration Date: {calibration_date}")
        print(f"Slope: {slope}")
        print(f"Intercept: {intercept}")

        sensor_name, calibration_date, slope, intercept = match
        sensor_data[idx, 0] = sensor_name.split()[0]  # "pH", "pCO2", "reference" or "sample"
        sensor_data[idx, 1] = float(slope)  # Slope
        sensor_data[idx, 2] = float(intercept)  # Intercept
    print("============================================")
    return sensor_data

def poll_sensor(client, slave_address):
    """
    Reads 8 holding registers (0–7) from 'slave_address' on the given 'client',
    decodes the first 4 registers as two 32-bit floats, and prints the results.

    Adjust this function's logic/decoding to match each sensor’s register map.
    """
    response = client.read_holding_registers(0, count=8, slave=slave_address)

    if response.isError():
        # If there's a Modbus error/timeout, print it
        print(f"Modbus Error on address {slave_address}:", response)
        return

    registers = response.registers

    byte_order_flag = '>'
    raw_pCO2 = (registers[1]<<16) | registers[0] # combine registers into a single 32-bit value
    raw_temp = (registers[3]<<16) | registers[4] # combine registers into a single 32-bit value

    pCO2_value = struct.unpack(f'{byte_order_flag}f',raw_pCO2.to_bytes(4, byteorder='big'))[0]
    temp_value = struct.unpack(f'{byte_order_flag}f',raw_temp.to_bytes(4, byteorder='big'))[0]
    return pCO2_value, temp_value

def is_float(value):
    """Check if a string can be converted to a float."""
    try:
        float(value)
        return True
    except ValueError:
        return False


def main():
    try:
        # ------------------------------------
        # extract calibration data stored in the calibration file
        # ------------------------------------
        CALIBRATION_FILE = r"C:\Users\endla\OneDrive - Massachusetts Institute of Technology\Desktop\Flux Chamber Project\Scripts\data_acquisition\data_acquisition\calibration_data.txt"

        calibration_data = extract_calibration(CALIBRATION_FILE)

        pH_slope = calibration_data[0,1] # pH units / mA
        pH_intercept = calibration_data[0,2] # pH units

        pCO2_slope = calibration_data[1,1] # ppm/V
        pCO2_intercept = calibration_data[1,2] # ppm

        NFD_G_CST = calibration_data[2,1] # umol/m2/s/ppm
        NFD_REF_OFFSET = calibration_data[2,2] # ppm
        NFD_NOD_OFFSET = calibration_data[3,2] # ppm

        # ------------------------------------
        # Open the ESP32 serial port
        # ------------------------------------
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        time.sleep(5)
        print(f"Connected to {SERIAL_PORT} at {BAUD_RATE} baud.")
        ser.flushOutput()
        ser.flushInput()
        for i in range(17):
            line = ser.readline().decode('utf-8', errors='replace')
            print("RAW:", repr(line))
            if i>12 : print(line.strip())
            i += 1
        print("============================================")
        print("Initializing connection to the eosFD nodes:")
        # ------------------------------------
        # Create Modbus Client 1 for Reference
        # -------------------------------------
        client1 = ModbusClient(
            # method='rtu', method parameter used in older versions
            port=REF_PORT,
            baudrate=REF_BAUDRATE,
            parity=REF_PARITY,
            stopbits=REF_STOPBITS,
            bytesize=REF_BYTESIZE,
            timeout=REF_TIMEOUT
        )
        if not client1.connect():
            print(f"Unable to open {REF_PORT}")
        else:
            print(f"Connected to {REF_PORT} (Address = {REF_ADDRESS})")

        # ------------------------------------
        # Create Modbus Client 2 for Node
        # ------------------------------------

        client2 = ModbusClient(
            # method='rtu',
            port=NOD_PORT,
            baudrate=NOD_BAUDRATE,
            parity=NOD_PARITY,
            stopbits=NOD_STOPBITS,
            bytesize=NOD_BYTESIZE,
            timeout=NOD_TIMEOUT
        )
        if not client2.connect():
            print(f"Unable to open {NOD_PORT}")
        else:
            print(f"Connected to {NOD_PORT} (Address = {NOD_ADDRESS})")

        # delay to allow sensor boot time
        time.sleep(5)

        # Record the start time of the experiment
        start_time = time.time()  # in seconds since the epoch

        # Open the file in append mode
        with open(LOGFILE, 'a') as f:
            print("================================")
            print(f"Logging data to {LOGFILE}. Press Ctrl+C to stop.")

            while True:
                # Wait before the next polling cycle
                time.sleep(POLLING_RATE)

                # Get data acquisition timestamp
                now = datetime.now()
                ms = now.microsecond // 1000 # Truncate microseconds to milliseconds
                timestamp = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{ms:03d}" # Build the string "YYYY-MM-DD HH:MM:SS" + ".fff"

                # Calculate the elapsed time since the experiment started
                elapsed_time = time.time() - start_time

                # Read a line from the serial port
                ser.write(b"READ\n")
                line = ser.readline().decode('utf-8', errors='replace')

                # Poll reference and sample nodes
                ref_pCO2_value, ref_temp_value = poll_sensor(client1, REF_ADDRESS)
                nod_pCO2_value, nod_temp_value = poll_sensor(client2, NOD_ADDRESS)

                calculated_flux = NFD_G_CST*((nod_pCO2_value+NFD_NOD_OFFSET)-(ref_pCO2_value+NFD_REF_OFFSET))

                if line:
                    parts = line.strip().split(',')

                    if all(is_float(value) for value in parts):
                        if len(parts) < 5:
                            # Not enough data in line, skip or handle error
                            continue

                        # Convert each field to a float as needed
                        temp_1 = float(parts[0])
                        temp_2 = float(parts[1])
                        hum = float(parts[2])
                        pH_current = float(parts[3])
                        pH = pH_current * pH_slope + pH_intercept

                        pCO2_voltage = float(parts[4])
                        # Use pCO2_voltage instead of an undefined "voltage"
                        pCO2 = pCO2_voltage * pCO2_slope + pCO2_intercept

                        # Write to file: timestamp + the data line
                        f.write(f"{timestamp},{elapsed_time:.2f},{pCO2:.2f},{pCO2_voltage:.2f},{pH:.2f},{pH_current:.2f},{temp_1:.2f},{temp_2:.2f},{hum:.2f},{ref_pCO2_value:.2f},{ref_temp_value:.3f},{nod_pCO2_value:.2f},{nod_temp_value:.2f},{calculated_flux:.4f}\n")
                        f.flush()

                        # Also print to console (optional)
                        print(f"{timestamp},{elapsed_time:.2f},{pCO2:.2f},{pCO2_voltage:.2f},{pH:.2f},{pH_current:.2f},{temp_1:.2f},{temp_2:.2f},{hum:.2f},{ref_pCO2_value:.2f},{ref_temp_value:.3f},{nod_pCO2_value:.2f},{nod_temp_value:.2f},{calculated_flux:.4f}")
                    else:
                        print("Invalid data received, skipping...")

    except KeyboardInterrupt:
        print("Logging stopped by user.")
        ser.close()
        client1.close()
        #client2.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()