# -*- coding: utf-8 -*-
"""
Created on Tue Jun  2 14:10:29 2026

@author: R A Cheel
"""

import os
import time
import csv
from datetime import datetime
from pymodbus.client import ModbusSerialClient as ModbusClient
import serial
import struct

# New imports for Adafruit MAX31865 SPI boards
import board
import busio
import digitalio
import adafruit_max31865

print("TODO: change udev rules for perma-serial-port!")

# -----------------------
# User configuration
# -----------------------
POLLING_RATE = 1.0
BASE_DIR = r"/home/flux/Data/FluxChamber"

# EOSENSE
REF_ADDRESS = 1
NOD_ADDRESS = 2
MODBUS_PORT = '/dev/ttyUSB1'
BAUDRATE = 19200

# SOLU-BLU
PO_PORT = '/dev/ttyUSB0'
PO_BAUD = 19200

# -----------------------
# MAX31865 Configuration
# -----------------------
# Change to 1000.0 if using PT1000 probes
RTD_NOMINAL = 1000.0   

# Change to 4300.0 if your board is modified for PT1000
REF_RESISTANCE = 4300.0 

# Change to 2 or 4 if your probes are not 3-wire
RTD_WIRES = 3         

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
            device_id=slave_address   # ✅ correct for your setup
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


def get_Timestamp()->str:
    now = datetime.now()
    ms = now.microsecond // 1000
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{ms:03d}"

    return timestamp

# -----------------------
# MAIN
# -----------------------
def main():
    # Keep track of hardware handles so we can clean up if needed
    client = None
    ser_PO = None
    
    try:
        # --- Modbus client ---
        try:
            client = ModbusClient(
                port=MODBUS_PORT,
                baudrate=BAUDRATE,
                parity='N',
                stopbits=2,
                bytesize=8,
                timeout=1
            )
            if not client.connect():
                print("Warning: Failed to connect to eosFD Modbus client")
            else:
                print("Connected to eosFD")
        except Exception as e:
            print("Error initializing Modbus client:", e)

        # --- Solu-Blu serial ---
        try:
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
        except Exception as e:
            print("Error initializing Solu-Blu Serial:", e)

        # --- MAX31865 Initialization ---
        print("Initializing MAX31865 boards on SPI0...")
        try:
            # Shared SPI0 Bus (Pins: SCLK=GPIO11, MOSI=GPIO10, MISO=GPIO9)
            spi = busio.SPI(board.SCK, board.MOSI, board.MISO)

            # Assign Chip Select Pins (GPIO 8 and GPIO 7)
            cs_a = digitalio.DigitalInOut(board.D8)
            cs_b = digitalio.DigitalInOut(board.D7)

            # Initialize the two sensor instances
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
            print("MAX31865 boards successfully initialized")
        except Exception as e:
            print("Fatal Error initializing MAX31865 SPI boards:", e)
            raise e

        start_time = time.time()

        with open(LOGFILE, 'a', encoding='utf-8') as f:
            print(f"\nLogging to {LOGFILE}\n")

            f.write(f"SYS, RTD resistance: {RTD_NOMINAL}, ")
            f.write(f"REF resistance: {REF_RESISTANCE}, ")
            f.write(f"number of wires: {RTD_WIRES}\n")

            while True:
                loop_start = time.time()

                try:
                    # -----------------------
                    # Timestamp
                    # -----------------------
                    # now = datetime.now()
                    # ms = now.microsecond // 1000
                    # timestamp = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{ms:03d}"
                    timestamp = get_Timestamp()

                    elapsed = time.time() - start_time

                    # -----------------------
                    # EOSENSE
                    # -----------------------
                    ref_pCO2, ref_temp = 0.0, 0.0
                    nod_pCO2, nod_temp = 0.0, 0.0
                    
                    if client and client.connected:
                        ref = poll_sensor(client, REF_ADDRESS)
                        node = poll_sensor(client, NOD_ADDRESS)

                        if ref is not None:
                            ref_pCO2, ref_temp = ref
                        if node is not None:
                            nod_pCO2, nod_temp = node

                    # -----------------------
                    # SOLU-BLU
                    # -----------------------
                    po_line = ""
                    if ser_PO and ser_PO.is_open:
                        try:
                            if ser_PO.in_waiting > 0:
                                po_line = ser_PO.readline().decode('utf-8', errors='replace').strip()
                        except Exception as e:
                            print("Error reading Solu-Blu:", e)

                    # -----------------------
                    # MAX31865 Temperature Boards
                    # -----------------------
                    temp_a = float('nan')
                    temp_b = float('nan')

                    # Read Sensor A (GPIO 8)
                    try:
                        temp_a = sensor_a.temperature
                    except Exception as e:
                        print("Error reading MAX31865 Sensor A (GPIO8):", e)

                    # Read Sensor B (GPIO 7)
                    try:
                        temp_b = sensor_b.temperature
                    except Exception as e:
                        print("Error reading MAX31865 Sensor B (GPIO7):", e)

                    # now = datetime.now()
                    # ms = now.microsecond // 1000
                    # timestampTHERM = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{ms:03d}"
                    timestampTHERM = get_Timestamp()

                    # Format the custom string for both temperatures on one line
                    therm_line = f"{temp_a:.2f},{temp_b:.2f}"

                    # -----------------------
                    # PRINT
                    # -----------------------
                    timeString = get_Timestamp()
                    print(
                        # f"{timestamp} | "
                        f"EOS: {timeString}, REF {ref_pCO2:.1f} ppm | NODE {nod_pCO2:.1f} ppm | \n"
                        f"PO: {timeString}, {po_line}\n"
                        f"THERM: {timeString}, {therm_line}\n"
                    )

                    # -----------------------
                    # LOG
                    # -----------------------
                    line = (
                        f"EOS,"
                        f"{timeString},"
                        f"{elapsed:.2f},"
                        f"{ref_pCO2:.2f},{ref_temp:.2f},"
                        f"{nod_pCO2:.2f},{nod_temp:.2f}\n"
                    )

                    POline = f"PO,{timeString}, {po_line}\n"
                    THERMline = f"THERM,{timeString}, {therm_line}\n"

                    f.write(line)
                    f.write(POline)
                    f.write(THERMline)
                    
                    # Force data to write to disk immediately (vital for systemd)
                    f.flush()

                except Exception as e:
                    print("Loop error:", e)

                # maintain timing
                dt = time.time() - loop_start
                time.sleep(max(0, POLLING_RATE - dt))

    except KeyboardInterrupt:
        print("Logging stopped manually")

    except Exception as e:
        print("Fatal error in main execution loop:", e)
        
    finally:
        if client:
            client.close()
        if ser_PO:
            ser_PO.close()

if __name__ == "__main__":
    main()
