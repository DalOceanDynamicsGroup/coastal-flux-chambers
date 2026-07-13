# -*- coding: utf-8 -*-
"""
Created on Tue Jun  2 14:10:29 2026

@author: DODG
"""

import os
import time
import csv
from datetime import datetime
from pymodbus.client import ModbusSerialClient as ModbusClient
import serial
import struct

print("TODO: change udev rules for perma-serial-port!")

# -----------------------
# User configuration
# -----------------------
POLLING_RATE = 1.0
BASE_DIR = r"/home/dodg/Data/FluxChamber"

# EOSENSE
REF_ADDRESS = 1
NOD_ADDRESS = 2
MODBUS_PORT = '/dev/ttyUSB1'
BAUDRATE = 19200

# SOLU-BLU
PO_PORT = '/dev/ttyUSB0'
PO_BAUD = 19200

# Arduino T-logger/transmitter
THERM_PORT = '/dev/ttyACM0'
THERM_BAUD = 115200

# -----------------------
# File setup
# -----------------------
os.makedirs(BASE_DIR, exist_ok=True)

LOGFILE = os.path.join(
    BASE_DIR,
    f"fluxChamber_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.csv"
)

HEADER = [
    "TIME", "RUNTIME",
    "REF_pCO2", "REF_TEMP",
    "NODE_pCO2", "NODE_TEMP",
    "PO_RAW"
]

with open(LOGFILE, 'w', newline="") as f:
    writer = csv.writer(f)
    writer.writerow(HEADER)

# -----------------------
# EOS polling
# -----------------------
def poll_sensor(client, slave_address):
    try:
        response = client.read_holding_registers(
            address=0,
            count=8,
            slave=slave_address   # ✅ correct for your setup
        )

        if response.isError():
            print(f"Modbus Error (addr {slave_address}):", response)
            return None

        regs = response.registers

        raw_pCO2 = (regs[1] << 16) | regs[0]
        raw_temp = (regs[3] << 16) | regs[2]

        pCO2 = struct.unpack('>f', raw_pCO2.to_bytes(4, 'big'))[0]
        temp = struct.unpack('>f', raw_temp.to_bytes(4, 'big'))[0]

        return pCO2, temp

    except Exception as e:
        print(f"poll_sensor error (addr {slave_address}):", e)
        return None

# -----------------------
# Start Solu-Blu sampling
# -----------------------
def start_solu_blu(ser):
    try:
        print("Starting Solu-Blu sampling...")

        # Clear out any old data lingering in the Pi's buffers
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.5)

        # 1. Wake the sensor up
        print("Waking up sensor...")
        ser.write(b'\r')
        time.sleep(0.5)

        # 2. Enter the menu using the Escape key
        print("Entering menu...")
        ser.write(b'\x1b')
        ser.flush()

        # 3. WAIT for the menu to finish transmitting
        print("Waiting for Solu-Blu menu text...")
        
        # Save the original timeout so we can restore it later
        original_timeout = ser.timeout 
        # Set a short 1-second timeout so readline() doesn't hang forever
        ser.timeout = 1.0 

        while True:
            line = ser.readline()
            
            # If line is empty, the sensor has stopped sending text (timeout reached)
            if not line:
                print("Menu text stream paused.")
                break
                
            # Print out what the sensor is saying so you can monitor it
            try:
                decoded_line = line.decode('utf-8', errors='ignore').strip()
                if decoded_line:
                    print(f"[Solu-Blu Menu]: {decoded_line}")
            except Exception:
                pass

        # Restore your original serial timeout for normal data logging
        ser.timeout = original_timeout

        # 4. Now that the menu is fully loaded, send the "start sampling" choice
        print("Sending '1' to start sampling...")
        ser.write(b'1\r')
        ser.flush()
        
        # Short pause to let the sensor process the selection
        time.sleep(1)

        print("Solu-Blu started successfully!\n")
        
    except Exception as e:
        print("Error starting Solu-Blu:", e)


# -----------------------
# MAIN
# -----------------------
def main():
    try:
        # --- Modbus client ---
        client = ModbusClient(
            port=MODBUS_PORT,
            baudrate=BAUDRATE,
            parity='N',
            stopbits=2,
            bytesize=8,
            timeout=1
        )

        if not client.connect():
            raise Exception("Failed to connect to eosFD")

        print("Connected to eosFD")

        # wrap, in unique try blocks both solublue serial and therm serial

        # --- Solu-Blu serial ---
        ser_PO = serial.Serial(
            PO_PORT,
            PO_BAUD,
            bytesize=8,
            parity='N',
            stopbits=1,
            timeout=1
        )

        print("Connected to Solu-Blu")

        time.sleep(2)

        start_solu_blu(ser_PO)
        time.sleep(2)


        # connect to arduino
        ser_THERM = serial.Serial(
                THERM_PORT,
                THERM_BAUD,
                bytesize=8,
                parity='N',
                stopbits=1,
                timeout=1
        )
        print("Connected to temperature logger")

        start_time = time.time()

        with open(LOGFILE, 'a') as f:
            print(f"\nLogging to {LOGFILE}\n")

            while True:
                loop_start = time.time()

                try:
                    # -----------------------
                    # Timestamp
                    # -----------------------
                    now = datetime.now()
                    ms = now.microsecond // 1000
                    timestamp = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{ms:03d}"

                    elapsed = time.time() - start_time

                    # -----------------------
                    # EOSENSE
                    # -----------------------
                    ref = poll_sensor(client, REF_ADDRESS)
                    node = poll_sensor(client, NOD_ADDRESS)

                    if ref is None or node is None:
                        print("⚠ Modbus read failed\n")
                        continue

                    ref_pCO2, ref_temp = ref
                    nod_pCO2, nod_temp = node

                    # -----------------------
                    # SOLU-BLU
                    # -----------------------
                    po_line = ""

                    if ser_PO.in_waiting > 0:
                        po_line = ser_PO.readline().decode('utf-8', errors='replace').strip()
                    

                    #
                    # Temperature data
                    #
                    therm_line = ""
                    if ser_THERM.in_waiting > 0:
                        therm_line = ser_THERM.readline().strip()

                    # put the eos print and log variable creation in a try block

                    now = datetime.now()
                    timestampTherm = now.strftime("%Y-%m-%d %H:%M:%S")

                    # -----------------------
                    # PRINT
                    # -----------------------
                    print(
                        f"{timestamp} | "
                        f"REF {ref_pCO2:.1f} ppm | NODE {nod_pCO2:.1f} ppm | \n"
                        f"PO: {po_line}\n"
                        f"THERM: {timestamp}, {therm_line}\n"
                    )

                    # -----------------------
                    # LOG
                    # -----------------------
                    line = (
                        f"EOS,"
                        f"{timestamp},"
                        f"{elapsed:.2f},"
                        f"{ref_pCO2:.2f},{ref_temp:.2f},"
                        f"{nod_pCO2:.2f},{nod_temp:.2f}\n"#","
                        # f"{po_line}\n"
                    )

                    POline = f"PO,{po_line}\n"

                    THERMline = f"THERM, {therm_line}\n"

                    f.write(line)
                    f.write(POline)
                    f.write(THERMline)
                    f.flush()

                except Exception as e:
                    print("Loop error:", e)

                # maintain timing
                dt = time.time() - loop_start
                time.sleep(max(0, POLLING_RATE - dt))

    except KeyboardInterrupt:
        print("Logging stopped")

    except Exception as e:
        print("Fatal error:", e)

if __name__ == "__main__":
    main()
