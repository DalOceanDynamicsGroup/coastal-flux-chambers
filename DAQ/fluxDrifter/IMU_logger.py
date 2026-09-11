"""
    Richard A Cheel
    Sept. 11, 2026

    This code is not yet tested on the pi
"""


import qwiic_ism330dhcx
import qwiic_mmc5983ma
import time
import csv
import sys
from datetime import datetime

def main():
    # 1. Generate filename with exact start timestamp
    # Format: imu_log_YYYYMMDD_HHMMSS.csv
    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"imu_log_{timestamp_str}.csv"

    # 2. Target Frequency Setup (Adjust TARGET_HZ to fit between 50 and 100)
    TARGET_HZ = 100.0  
    SAMPLE_INTERVAL = 1.0 / TARGET_HZ

    # 3. Initialize Sensors
    imu = qwiic_ism330dhcx.QwiicIsm330dhcx()
    mag = qwiic_mmc5983ma.QwiicMmc5983ma()

    if not imu.is_connected() or not mag.is_connected():
        print("Error: Hardware validation failed. Check Qwiic physical connection.", file=sys.stderr)
        return

    imu.begin()
    imu.initialize()
    mag.begin()

    print(f"Recording triggered. Saving telemetry directly to: {filename}")
    print(f"Targeting active pace: {TARGET_HZ} Hz. Press Ctrl+C to stop.")

    # 4. Open File and Stream Header
    headers = ["timestamp", "accel_x", "accel_y", "accel_z", "gyro_x", "gyro_y", "gyro_z", "mag_x", "mag_y", "mag_z"]
    
    # We open with buffering=1 (line buffered) so data writes directly to disk on newline 
    # instead of staying caught in python memory structures if your system gets unplugged.
    with open(filename, mode='w', newline='', buffering=1) as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(headers)

        total_samples = 0
        next_sample_time = time.perf_counter()

        try:
            while True:
                current_time = time.perf_counter()

                # Pacing gate: execute only when time step interval is reached
                if current_time >= next_sample_time:
                    # Sync interval window ahead
                    next_sample_time += SAMPLE_INTERVAL

                    # Query 6DoF registers
                    accel = imu.get_accel_data()
                    gyro = imu.get_gyro_data()

                    # Query Magnetometer registers
                    mag_data = mag.get_measurement()

                    # Format log metrics
                    now_epoch = time.time() # Accurate system wall clock timestamp
                    row = [
                        now_epoch,
                        accel['x'], accel['y'], accel['z'],
                        gyro['x'], gyro['y'], gyro['z'],
                        mag_data['x'], mag_data['y'], mag_data['z']
                    ]
                    
                    writer.writerow(row)
                    total_samples += 1

                    # Minimal print layout: Only status print once every 200 items 
                    # (approx every 2 seconds if targeting 100Hz) to prevent console lag.
                    if total_samples % 200 == 0:
                        sys.stdout.write(f"\r[Active Logging] Total recorded ticks: {total_samples} samples...")
                        sys.stdout.flush()

                else:
                    # Relinquish microscopic CPU thread chunks to keep Pi core cold 
                    # while waiting on the next clock interval window
                    time.sleep(0.001)

        except KeyboardInterrupt:
            print(f"\n\nSession Terminated. Successfully stored {total_samples} records to '{filename}'.")

if __name__ == '__main__':
    main()
