# Code for flux sensors projects

## MIToriginal
Code provided to us by MIT collaborators. This used an esp32 to record "ancillary" sensors along with eosSens (modbus)

## fluxChamber
Developing code for the flux chamber, which as a Solu-Blue CO2 sensor (rs-232/485), EOSense flux chambers (rs-485/modbus), and two thermistors connected to two adafruit MAX31865 boards that are connected to an arduino which is then streaming the data to a raspberry pi. The raspberry pi logs all the data into a single file with line prefixes denoting which instrument the data belong to.

## fluxDrifter
This is essentially a fork of the code for the flux chamber. The biggest difference is that there is no arduino, just a raspberry pi to log all the data.

## To run python on reboot
- create service file `sudo nano /etc/systemd/system/fluxchamber.service`
- reload services list `sudo systemctl daemon-reload`
- start logging script service `sudo systemctl start fluxchamber.service`
- check status `sudo systemctl status fluxchamber.service`
- realtime status `sudo journalctl -u fluxchamber.service -f`
- stop `sudo systemctl stop fluxchamber.service`
- restart manually `sudo systemctl restart fluxchamber.service`

## Notes
- Raspberry Pi SPI primary bus (SPI0) is 19 (MOSI), 21 (MISO), 23 (SCLK) and for chip select 8 (CS0) and 7 (CS1)
- Raspberry Pi is 3.3V tolerant for input levels
- ADAFRUIT 31865 also uses 3.3V logic

## Useful Notes
### Parsing data file
Basic, "no software" method is to grep for the unique line identifiers:
- linux, mac, unix, wsl:
  - `cat dataFileName | grep -i linePrefix > Prefix_outputFileName`
  - where `dataFileName` is the file name to be parsed, and `linePrefix` is one of `PO`, `EOS`, or `THERM`. `Prefix_outputFileName` is the file generated. So there will be three different uses of the above command, one for each prefix. Generating 3 output files total.
- powershell
  - `Select-String "^PO" main_file.txt | ForEach-Object {$_.Line} | Set-Content PO_file.txt`
  - where `"^PO"` can be replaced with `"^EOS"` or `"^THERM"`
  - likewise `PO_file.txt` should be replaced with a unique output for the different variables.
  - `Select-String "^PO" main_file.txt | ForEach-Object {$_.Line} | Set-Content PO_file.txt; Select-String "^EOS" main_file.txt | ForEach-Object {$_.Line} | Set-Content EOS_file.txt; Select-String "^THERM" main_file.txt | ForEach-Object {$_.Line} | Set-Content THERM_file.txt` should also work (untested as of writing), with changing of file names
### Transferring data off the pi
- scp shell program
  - navigate (`cd`) to the directory on the laptop you want the data to end up
  - `scp -r dodg@fluxpi:/path/to/data/dataFileName .`
- winscp can also be used, graphical interface to the file system