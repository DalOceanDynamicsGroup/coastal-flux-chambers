Raspberry Pi SPI0 Connection Table (Shared Bus)

+--------------------+---------------------------+---------------------+------------------+------------------+

| MAX31865 Pin Name  | Raspberry Pi Hardware Pin | Physical Pin Number | Board A (GPIO 8) | Board B (GPIO 7) |
+--------------------+---------------------------+---------------------+------------------+------------------+

| VIN                | 3.3V Power                | Physical Pin 1      | Connect          | Connect          |
| GND                | Ground                    | Physical Pin 6      | Connect          | Connect          |
| CLK (SCLK)         | GPIO 11 (SPI0 SCLK)       | Physical Pin 23     | Connect          | Connect          |
| SDO (MISO)         | GPIO 9 (SPI0 MISO)        | Physical Pin 21     | Connect          | Connect          |
| SDI (MOSI)         | GPIO 10 (SPI0 MOSI)       | Physical Pin 19     | Connect          | Connect          |
| CS (Chip Select)   | GPIO 8 (SPI0 CE0)         | Physical Pin 24     | CONNECT HERE     | Do Not Connect   |
| CS (Chip Select)   | GPIO 7 (SPI0 CE1)         | Physical Pin 26     | Do Not Connect   | CONNECT HERE     |
+--------------------+---------------------------+---------------------+------------------+------------------+

Note: You do not need to wire the "3V" or "RDY" pins on the Adafruit breakout boards for this configuration.
