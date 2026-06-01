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
import threading

# -----------------------
# User configuration
# -----------------------
POLLING_RATE = 1.0 # seconds
BASE_DIR = r"C:\Data\FluxChamber" # specify path to the data folder


# -----------------------
# Reference Node Configuration
# -----------------------
REF_ADDRESS  = 1
REF_PORT     = 'COM8'  # or e.g., 'COM4' on Windows
REF_BAUDRATE = 19200
REF_PARITY   = 'N'
REF_STOPBITS = 2
REF_BYTESIZE = 8
REF_TIMEOUT  = 1

# -----------------------
# Sample Node Configuration
# -----------------------
NOD_ADDRESS  = 2
NOD_PORT     = 'COM8'  # or e.g., 'COM5' on Windows
NOD_BAUDRATE = 19200
NOD_PARITY   = 'N'
NOD_STOPBITS = 2
NOD_BYTESIZE = 8
NOD_TIMEOUT  = 1

# -----------------------
# Pro-Oceanus Configuration
# -----------------------
SERIAL_PORT_PO = 'COM7'
BAUD_RATE_PO =  19200

# -----------------------
# Thermistor Configuration
# -----------------------
SERIAL_PORT_TEMP = 'COMY'
BAUD_RATE_TEMP =  9600

# -----------------------
# Nortek Configuration
# -----------------------
SERIAL_PORT_NTK = 'COMZ'
BAUD_RATE_NTK =  9600


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
    response = client.read_holding_registers(0, count=8, device_id=slave_address)

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

def read_from_port(ser):
    while True:
        if ser.in_waiting > 0:
            data = ser.readline().decode('utf-8').strip()
            print(f"Data from {ser.port}: {data}")

def parse_PO(line:str) -> str:
    # splits the PO line and creates line for our log file
    # want field numbers 1-7, 10-14
    split_line = line.split(',')
    out_string = 'PO'
    for ll in [0,1,2,3,4,5,6,9,10,11,12,13]:
        out_string = out_string + +"," + split_line[ll]
    
    return out_string #.join() # timestamp,param1,param2,...

def parse_TEMP(line:str) -> str:
    """
        parses the serial string that contains the water and air temperature data
    """
    out_string = line

    return out_string



def main():
    try:
        # ------------------------------------
        # Open the ESP32 serial port
        # ------------------------------------
        """
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        time.sleep(5)
        print(f"Connected to {SERIAL_PORT} at {BAUD_RATE} baud.")
        ser.flushOutput()
        ser.flushInput()
        """
        
        # Initialize ports
        ser_PO = serial.Serial(SERIAL_PORT_PO,BAUD_RATE_PO)
        #ser_TEMP = serial.Serial(SERIAL_PORT_TEMP,BAUD_RATE_TEMP)
        #ser_NTK = serial.Serial(SERIAL_PORT_NTK,BAUD_RATE_NTK)

        # Create and start threads
        thread_PO = threading.Thread(target=read_from_port, args=(ser_PO,), daemon=True)
        thread_PO.start()
        #thread_TEMP = threading.Thread(target=read_from_port, args=(SERIAL_PORT_TEMP,), daemon=True)
        #thread_TEMP.start()
        #thread_NTK = threading.Thread(target=read_from_port, args=(SERIAL_PORT_NTK,), daemon=True)
        #thread_NTK.start()

        
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
            print(f"Unable to open ref {REF_PORT}")
        else:
            print(f"Connected to ref {REF_PORT} (Address = {REF_ADDRESS})")

        # ------------------------------------
        # Create Modbus Client 2 for Node
        # ------------------------------------
        """
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
            print(f"Unable to open node {NOD_PORT}")
        else:
            print(f"Connected to {NOD_PORT} node (Address = {NOD_ADDRESS})")
        """ 
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


                # add serial read for prooceanus and write to LOGFILE with unique prefix

                # add serial read for Temperature uC and write to LOGFILE with unique prefix

                # Calculate the elapsed time since the experiment started
                elapsed_time = time.time() - start_time

                line = ser_PO.readline().decode('utf-8', errors='replace')
                #PO_data = parse_PO(line)
                PO_data = "PO_data" + "," + line + "\n"
                print(PO_data)
                # line = SERIAL_PORT_TEMP.readline().decode('utf-8', errors='replace')
                TEMP_data = "TEMP" + "," + "\n" #parse_TEMP(line)
                # line = SERIAL_PORT_NTK.readline().decode('utf-8', errors='replace')
                NTK_data = "NTK" + "," + "\n" #parse_NTK(line)

                # write serial data to logfile
                #f.write(f"{PO_data}")
                f.write(f"{TEMP_data}")
                f.write(f"{NTK_data}")


                # Poll reference and sample nodes
                ref_pCO2_value, ref_temp_value = poll_sensor(refClient, REF_ADDRESS)
                nod_pCO2_value, nod_temp_value = poll_sensor(refClient, NOD_ADDRESS)

                # create eossense output string
                EOS_data = "EOS," + str(ref_pCO2_value) + "," + str(ref_temp_value) + "," + str(nod_pCO2_value) + "," + str(nod_temp_value) + "\n"#+","+datetime.strftime()

                #calculated_flux = NFD_G_CST*((nod_pCO2_value+NFD_NOD_OFFSET)-(ref_pCO2_value+NFD_REF_OFFSET))

                # write eos sense data to logfile
                print(ref_pCO2_value, nod_pCO2_value)
                f.write(f"{EOS_data}")

                """ modify to have unique prefix -> FC or something and only write the flux chamber
                 f.write(f"{timestamp},{elapsed_time:.2f},{pCO2:.2f},{pCO2_voltage:.2f},{pH:.2f},{pH_current:.2f},{temp_1:.2f},{temp_2:.2f},{hum:.2f},{ref_pCO2_value:.2f},{ref_temp_value:.3f},{nod_pCO2_value:.2f},{nod_temp_value:.2f},{calculated_flux:.4f}\n")
                        f.flush()
                """
                f.flush()

                # handle length of True loop to get even sampling rate



    except KeyboardInterrupt:
        print("Logging stopped by user.")
        ser.close()
        refClient.close()
        #nodeClient.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()





"""




"""