# -*- coding: utf-8 -*-
"""
Created on Thu Jan 30 12:31:11 2025

@author: souhaelmousadik

modified: 2026-04-09
Richard A Cheel
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
BASE_DIR = r"C:\Data\FluxChamber" # specify path to the data folder


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
        print("============================================")
        print("Initializing connection to the eosFD nodes:")
        # ------------------------------------
        # Create Modbus Client 1 for Reference
        # -------------------------------------
        refClient = ModbusClient(
            # method='rtu', method parameter used in older versions
            port=REF_PORT,
            baudrate=REF_BAUDRATE,
            parity=REF_PARITY,
            stopbits=REF_STOPBITS,
            bytesize=REF_BYTESIZE,
            timeout=REF_TIMEOUT
        )
        if not refClient.connect():
            print(f"Unable to open {REF_PORT}")
        else:
            print(f"Connected to {REF_PORT} (Address = {REF_ADDRESS})")

        # ------------------------------------
        # Create Modbus Client 2 for Node
        # ------------------------------------

        nodeClient = ModbusClient(
            # method='rtu',
            port=NOD_PORT,
            baudrate=NOD_BAUDRATE,
            parity=NOD_PARITY,
            stopbits=NOD_STOPBITS,
            bytesize=NOD_BYTESIZE,
            timeout=NOD_TIMEOUT
        )
        if not nodeClient.connect():
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

                # Poll reference and sample nodes
                ref_pCO2_value, ref_temp_value = poll_sensor(refClient, REF_ADDRESS)
                nod_pCO2_value, nod_temp_value = poll_sensor(nodeClient, NOD_ADDRESS)

                calculated_flux = NFD_G_CST*((nod_pCO2_value+NFD_NOD_OFFSET)-(ref_pCO2_value+NFD_REF_OFFSET))


    except KeyboardInterrupt:
        print("Logging stopped by user.")
        ser.close()
        refClient.close()
        #nodeClient.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()