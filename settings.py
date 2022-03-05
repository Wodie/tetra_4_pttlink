# Settings for TETRA 4 PTTLink


# General settings
Callsign = 'XE1F'
Radio_ISSI = 9999



# Settings
serial_port = '/dev/ttyUSB0'
baudrate = 9600 # 115200
debug = 3
# LOGERROR = 0
# LOGWARN =1
# LOGINFO = 2
# LOGDEBUG = 3



# GPIO ports, not Raspberry Pi pins!
PTT_GPIO = 16
SQL_GPIO = 19
AUX_GPIO = 18



# APRS
# APRS callsign suffix for APRS (example N0CALL/R2, only set R2).
Suffix = 'T1'
# APRS passcode for your call (example N0CALL).
Passcode = 6881
# Optional, comment Server if you don't use APRS-IS.
# good server selections:
#	euro.aprs2.net:14580 (Europe)
#	noam.aprs2.net:14580 (North America)
#	soam.aprs2.net:14580 (South America)
#	asia.aprs2.net:14580 (Asia)
#	aunz.aprs2.net:14580 (Australia)
#	rotate.aprs2.net:14580 (World Wide, recommended to balance trafic between servers)
Server = 'noam.aprs2.net:14580'
# APRS user Objects file
APRS_File = '/opt/p25link/aprs.txt'
# APRS IG interval in minutes
APRS_Interval = 30
# Your gw coordinates in decimal degrees (not in APRS format! Decimal I said!)
# positive is north and east, negative is south and west.
Latitude = 19.3835
Longitude = -99.1446
Symbol = 'N&'
# Altitude in meters Above Sea Level
Altitude = 2232
# QSY information format:
# The format of the transmitted frequency is FFF.FFF MHz.
Frequency = 433.525
# Tone for up-link, carrier for down-link (please avoid carrier squelch).
# "tOFF A lower case "t" indicates Narrow. Tone = OFF (without encoding and decoding).
# "T088" An upper case "T" indicates Wide. Tone frequency of 88.5 Hz (encoding).
# "t088" A lower case "t" indicates Narrow. Tone frequency of 88.5 Hz (encoding).
# (Recommended use of tone for up-link and down-link)
# "C088" An upper case "C" indicates Wide. Tone frequency of 88.5 Hz (encoding/decoding).
# "c088" A lower case "c" indicates Narrow. Tone frequency of 88.5 Hz (encoding/decoding).
# (Recommended use for up-link and down-link)
# "D023" An upper case "D" indicates Wide. Tone frequency of 88.5 Hz (encoding/decoding).
# "d023" A lower case "d" indicates Narrow. Tone frequency of 88.5 Hz (encoding/decoding).
# Use 3 digits for Tone or digital tone with no decimals.
# Examples T167 t100 C123 c085 D023 d023, etc.
# Leave blank if using digital only.
AccessTone = ''
# The value of the offset shall be a 3-digit number (x 10 KHz/50 KHz step) with 2 decimals,no dot.
# "+" Plus shift (a default offset frequency applied)
# Example 0.600 MHz = "+060"
# "-" Minus shift (a default offset frequency applied)
# -5.000 MHZ = "-500"
Offset = ''
# Network Access Code
NAC = 293
APRSComment = 'TETRA Node 51467'
Verbose = 2






