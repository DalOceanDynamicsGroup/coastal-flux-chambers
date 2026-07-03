import serial
import serial.tools.list_ports
import sys
import time
import csv
from datetime import datetime, timezone
from pathlib import Path

# ===================== CONFIGURATION =====================
COM_PORT = "COM3"        # Set your COM port
BAUD_RATE = 9600         # Must match device
TIMEOUT = 1              # Seconds
LOG_DIR = "c:\Data\FluxChamber\serial_logs"
# ========================================================


def list_ports():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("ERROR: No serial ports detected.")
        return False

    print("Available serial ports:")
    for p in ports:
        print(f"  {p.device} - {p.description}")
    return True


def open_serial_port():
    try:
        return serial.Serial(
            port=COM_PORT,
            baudrate=BAUD_RATE,
            timeout=TIMEOUT
        )
    except serial.SerialException as e:
        print(f"ERROR: Cannot open {COM_PORT}: {e}")
        return None


def create_log_file():
    Path(LOG_DIR).mkdir(exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    log_path = Path(LOG_DIR) / f"serial_log_utc_{timestamp}.csv"

    try:
        f = open(log_path, "w", newline="", encoding="utf-8")
        writer = csv.writer(f)
        writer.writerow(["utc_timestamp", "data"])
        print(f"Logging to: {log_path}")
        return f, writer
    except OSError as e:
        print(f"ERROR: Unable to create log file: {e}")
        return None, None


def main():
    print("Starting serial CSV logger (UTC timestamps)...")

    if not list_ports():
        sys.exit(1)

    ser = open_serial_port()
    if ser is None:
        sys.exit(1)

    log_file, csv_writer = create_log_file()
    if log_file is None:
        ser.close()
        sys.exit(1)

    print(f"Connected to {COM_PORT} @ {BAUD_RATE} baud")
    print("Press Ctrl+C to stop\n")

    buffer = ""

    try:
        while True:
            if ser.in_waiting:
                incoming = ser.read(ser.in_waiting).decode("ascii", errors="ignore")
                buffer += incoming

                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()

                    if line:
                        utc_ts = datetime.now(timezone.utc).isoformat()
                        csv_writer.writerow([utc_ts, line])
                        log_file.flush()
                        print(f"{utc_ts}, {line}")

            time.sleep(0.01)

    except KeyboardInterrupt:
        print("\nStopping logger...")

    except serial.SerialException as e:
        print(f"\nERROR: Serial communication failure: {e}")

    finally:
        log_file.close()
        ser.close()
        print("Clean shutdown complete.")


if __name__ == "__main__":
    main()
