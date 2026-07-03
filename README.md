# Code for flux sensors projects

## MIToriginal
Code provided to us by MIT collaborators. This used an esp32 to record "ancillary" sensors along with eosSens (modbus)

## fluxChamber
Developing code for the flux chamber, which as a Solu-Blue CO2 sensor (rs-232/485), EOSense flux chambers (rs-485/modbus), and two thermistors connected to two adafruit MAX31865 boards that are connected to an arduino which is then streaming the data to a raspberry pi. The raspberry pi logs all the data into a single file with line prefixes denoting which instrument the data belong to.

## fluxDrifter
This is essentially a fork of the code for the flux chamber. The biggest difference is that there is no arduino, just a raspberry pi to log all the data.

## Notes
- Raspberry Pi SPI primary bus (SPI0) is 19 (MOSI), 21 (MISO), 23 (SCLK) and for chip select 8 (CS0) and 7 (CS1)
- Raspberry Pi is 3.3V tolerant for input levels
- ADAFRUIT 31865 also uses 3.3V logic