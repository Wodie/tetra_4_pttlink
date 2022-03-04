#!/usr/bin/env python

import time
import serial
import os
import defs
import RPi.GPIO as GPIO



AppName = 'PEI TETRA'
VersionInfo = '1'
MinorVersionInfo = '00'
RevisionInfo = '0'
Version = VersionInfo + '.' + MinorVersionInfo + '.' + RevisionInfo;
print "\n##################################################################"
print "	*** " + AppName + " v" + Version + " ***"
print "	Released: March 03, 2022. Created March 01, 2022."
print "	Created by:"
print "	Juan Carlos Perez De Castro (Wodie) KM4NNO / XE1F"
print "	www.wodielite.com";
print "	wodielite at mac.com";
print "	km4nno at yahoo.com\n";
print "	License:";
print "	This software is licenced under the GPL v3.";
print "	If you are using it, please let me know, I will be glad to know it.\n";
print "	This project is based on the work and information from:";
print "	Juan Carlos Perez KM4NNO / XE1F";
print "	APRS is a registed trademark and creation of Bob Bruninga WB4APR";
print "\n##################################################################\n";

# Detect Target OS.
import sys
sys.platform
if sys.platform.startswith("linux"): # could be "linux", "linux2", "linux3", ...
	# Linux
	print (sys.platform)
elif sys.platform == "darwin" :
	# MAC OS X
	print (sys.platform)
elif sys.platform == "win32" :
	# Windows (either 32-bit or 64-bit)
	print (sys.platform)

# HotKeys Init
# Windows
if os.name == 'nt':
	import msvcrt

# Posix (Linux, OS X)
else:
	import sys
	import termios
	import atexit
	from select import select

# GPIO
PTT_GPIO = 16
SQL_GPIO = 19
AUX_GPIO = 18
GPIO.setwarnings(False) # Ignore warning for now
GPIO.setmode(GPIO.BCM) # Use GPIO number
#GPIO.setmode(GPIO.BOARD) # Use physical pin numbering
GPIO.setup(PTT_GPIO, GPIO.IN, pull_up_down = GPIO.PUD_UP)
GPIO.setup(SQL_GPIO, GPIO.OUT)
GPIO.setup(AUX_GPIO, GPIO.OUT)
GPIO.output(SQL_GPIO, 1)
GPIO.output(AUX_GPIO, 1)



# Constants
OK = 0
ERROR = 1
CALL_BEGIN = 3
GROUPCALL_END = 4

SDS = 6
TEXT_SDS = 7
CNUMF = 8
CALL_CONNECT = 9
TRANSMISSION_END = 10
CALL_RELEASED = 11
LIP_SDS = 12
REGISTER_TSI = 13
STATE_SDS = 14
OP_MODE = 15
TRANSMISSION_GRANT = 16
TX_DEMAND = 17
TX_WAIT = 18
TX_INTERRUPT = 19
SIMPLE_LIP_SDS = 20
COMPLEX_SDS = 21
MS_CNUM = 22
WAP_PROTOCOL = 23
SIMPLE_TEXT_SDS = 24
ACK_SDS = 25
CMGS = 26
CONCAT_SDS = 27
CTGS = 28
CTDGR = 29
CLVL = 30
OTAK = 31
WAP_MESSAGE = 32
LOCATION_SYSTEM_TSDU = 33

DMO_OFF = 7
DMO_ON = 8

INVALID = 254
TIMEOUT = 255

LOGERROR = 0
LOGWARN =1
LOGINFO = 2
LOGDEBUG = 3

TETRA_LOGIC_VERSION = "19122021"

IDLE = 1
CHECK_AT = 2
INIT = 3
IGNORE_ERRORS = 4
INIT_COMPLETE = 5
WAIT = 6
AT_CMD_WAIT = 7
INIT_0 = 10
INIT_1 = 11
INIT_2 = 12
INIT_3 = 13
INIT_4 = 14
INIT_5 = 15
INIT_6 = 16
INIT_7 = 17
INIT_8 = 18
INIT_9 = 19
INIT_10 = 20
INIT_11 = 21
INIT_12 = 22
INIT_13 = 23




SDS_SEND_OK = 4
SDS_SEND_FAILED = 5



# Misc
mute_rx_on_tx = True
mute_tx_on_rx = True
rgr_sound_always = False
mcc = ""
mnc = ""
issi = ""
gssi = 1
port = "/dev/ttyUSB0"
baudrate = 9600 # 115200
initstr = ""
pei = 0
sds_pty = 0
peistream = ""
debug = LOGERROR
talkgroup_up = False
sds_when_dmo_on = False
sds_when_dmo_off = False
sds_when_proximity = False
peiComTimer = 2000
#Timer::TYPE_ONESHOT = False
peiActivityTimer = 10000
#Timer::TYPE_ONESHOT + True
peiBreakCommandTimer = 3000
#Timer::TYPE_ONESHOT = False
proximity_warning = 3.1
time_between_sds = 3600
own_lat = 0.0,
own_lon = 0.0
endCmd = ""
new_sds = False
inTransmission = False
cmgs_received = True
share_userinfo = True
current_cci = 0
dmnc = 0
dmcc = 0
infosds = ""



kb = 0
peirequest = INIT_0
pei_Buffer = "" # Clear Rx buffer.
last_sdsinstance = ''

tetra_modem_sql = False
Run = 1



#################################################################################
# Main ##########################################################################
#################################################################################
def main():
	# Serial Port
	global pei # Serial port
	global baudrate
	if sys.platform.startswith("linux"):
		# configure the serial connections (the parameters differs on the device you are connecting to)
		pei = serial.Serial(
			port='/dev/ttyUSB0',
			baudrate=baudrate,
			parity=serial.PARITY_NONE,
			stopbits=serial.STOPBITS_ONE,
			bytesize=serial.EIGHTBITS,
			timeout=1
		)
	elif sys.platform == "darwin" : # MAC OS X
		# configure the serial connections (the parameters differs on the device you are connecting to)
		pei = serial.Serial(
			port='/dev/tty.usbserial',
			baudrate=baudrate,
			parity=serial.PARITY_NONE,
			stopbits=serial.STOPBITS_ONE,
			bytesize=serial.EIGHTBITS,
			timeout=1
		)
	pei.isOpen()

	# GPIO Events
	global GPIO
	GPIO.add_event_detect(PTT_GPIO, GPIO.BOTH, callback = GPIO_Callback) # Setup event on pin 10 rising edge

	# Default values.
	global kb
	kb = KBHit()
	print('Hit any key, or ESC to exit')

	global Run
	while (Run):
		MainLoop()
	# Program exit:
	print "----------------------------------------------------------------------"
	kb.set_normal_term()
	pei.close
	GPIO.cleanup()
#	if ($APRS_IS and $APRS_IS->connected()) {
#		$APRS_IS->disconnect();
#		print color('yellow'), "APRS-IS Disconected.\n", color('reset');

	print "Good bye cruel World."
	print "----------------------------------------------------------------------\n"
	exit()



#################################################################################
# Main Loop #####################################################################
#################################################################################
def MainLoop():
	HotKeys() # Keystrokes events.
	
	initPei()

	Read_Serial()

	# let's wait one second before reading output (let's give device time to answer)
	time.sleep(0.01)
#	print "Looping the right way."
	return



##################################################################
# Serial #########################################################
##################################################################
def Read_Serial():
	global pei_Buffer # Clear Rx buffer.
	global pei

	#print "Read_Serial"
	# Check if incoming bytes are waiting to be read from the serial input 
	# buffer.
	# NB: for PySerial v3.0 or later, use property `in_waiting` instead of
	# function `inWaiting()` below!
	#if (ser.inWaiting() > 0):
	if (pei.in_waiting > 0):
		# read the bytes and convert from binary array to ASCII
		#data_str = ser.read(ser.inWaiting()).decode('ascii') 
		# print the incoming string without putting a new-line
		# ('\n') automatically after every print()
		#print(data_str, end='') 

#		SerialBuffer = pei.readline(pei.in_waiting) # Read Rx chars.
#		Serial_Rx(SerialBuffer, 0); # Process a full data stream.
		#print "Len(SerialBuffer) = " + str(len(SerialBuffer))

		Buffer = pei.read(pei.in_waiting) # Read Rx chars.
#		print "Buffer = " + Buffer
#		print "  Len(Buffer) = " + str(len(Buffer))
		Buf_Len = len(Buffer)
		if (Buf_Len >= 1):
			#Bytes_2_HexString(Buffer);
			for x in range(0, Buf_Len):
				#print "  x=" + str(x) + " byte " + str(ord(Buffer[x : x + 1]))
				if (ord(Buffer[x : x + 1]) == 0x0D): # if CR
					#print "len(Buffer) = " + str(len(Buffer))
					peiBufer = pei_Buffer.replace(chr(0x0D), '')
					peiBufer = pei_Buffer.replace(chr(0x0A), '')
					if (len(pei_Buffer) > 0):
						handlePeiAnswer(pei_Buffer) # Process a full line of data.
						#print "  len(pei_Buffer) = " + str(len(pei_Buffer))
					pei_Buffer = "" # Clear Rx buffer.
				elif (ord(Buffer[x : x + 1]) == 0x0A): # if LF
					pass
				else :
					pei_Buffer = pei_Buffer + Buffer[x : x + 1]
	return



##################################################################
# PEI ############################################################
##################################################################

def initPei():
	global peirequest
	#global peiBreakCommandTimer

	if (peirequest == AT_CMD_WAIT):
		#peiBreakCommandTimer.reset()
		#peiBreakCommandTimer.setEnable(true)
		pass

	if (peirequest == INIT_0):
		cmd = ""
		cmd = ""
		sendPei(cmd)
		time.sleep(0.2)
		peirequest = INIT_1
		return
	elif (peirequest == INIT_1):
		cmd = "AT"
		sendPei(cmd)
		peirequest = INIT_2
		return

	elif (peirequest == INIT_2):
		cmd = "AT+CTOM=6,0"
		sendPei(cmd)
		peirequest = INIT_3
		return
	elif (peirequest == INIT_3):
		cmd = "AT+CTSP=1,3,131"
		sendPei(cmd)
		peirequest = INIT_4
		return
	elif (peirequest == INIT_4):
		cmd = "AT+CTSP=1,3,130"
		sendPei(cmd)
		peirequest = INIT_5
		return
	elif (peirequest == INIT_5):
		cmd = "AT+CTSP=1,3,138"
		sendPei(cmd)
		peirequest = INIT_6
		return
	elif (peirequest == INIT_6):
		cmd = "AT+CTSP=1,2,20"
		sendPei(cmd)
		peirequest = INIT_7
		return
	elif (peirequest == INIT_7):
		cmd = "AT+CTSP=2,0,0"
		sendPei(cmd)
		peirequest = INIT_8
		return
	elif (peirequest == INIT_8):
		cmd = "AT+CTSP=1,3,24"
		sendPei(cmd)
		peirequest = INIT_9
		return
	elif (peirequest == INIT_9):
		cmd = "AT+CTSP=1,3,25"
		sendPei(cmd)
		peirequest = INIT_10
		return
	elif (peirequest == INIT_10):
		cmd = "AT+CTSP=1,3,3"
		sendPei(cmd)
		peirequest = INIT_11
		return
	elif (peirequest == INIT_11):
		cmd = "AT+CTSP=1,3,10"
		sendPei(cmd)
		peirequest = INIT_12
		return
	elif (peirequest == INIT_12):
		cmd = "AT+CTSP=1,1,11"
		sendPei(cmd)
		peirequest = INIT_13
		return
	elif (peirequest == INIT_13):
		cmd = "AT+CTSDC=0,0,0,1,1,0,1,1,0,0"
		sendPei(cmd)
		peirequest = INIT
		return

	elif (peirequest == INIT):
		cmd = "AT+CNUMF?" # get the MCC,MNC,ISSI from MS
		sendPei(cmd)
		print "pei_init_finished"
		sendUserInfo() # send userinfo to reflector
		peirequest = INIT_COMPLETE
	return

##################################################################
def sendUserInfo():
	return

##################################################################
def handlePeiAnswer(m_message):
	global debug
	global peistate
	global peirequest
	response = ''

	if (debug >= LOGINFO):
		print "From PEI:" + m_message
		#print "  len(m_message)" + str(len(m_message))

	if (m_message[0 : 2] == 'OK'):
		peistate = OK
		response = OK
#		if (new_sds and not inTransmission):
#			checkSds()
		return

	elif (m_message[0 : 11] == '+CME ERROR:'):
		peistate = ERROR
		response = ERROR
		if (len(m_message) > 11):
			Error = int(m_message.split(':', 1)[-1])
			print " +CME ERROR: " + str(Error)
		return

	elif (m_message[0 : 7] == '+CNUMF:' ): # CNUMF
		handleCnumf(m_message)
		return

	elif (m_message[0 : 7] == '+CTICN:' ): # CALL_BEGIN
		handleCallBegin(m_message)
		return

	elif (m_message[0 : 7] == '+CDTXC:' ): # TRANSMISSION_END
		handleTransmissionEnd(m_message)
		return

	elif (m_message[0 : 6] == '+CTCR:'): # CALL_RELEASED
		handleCallReleased(m_message)
		return

	elif (m_message[0 : 8] == '+CTSDSR:'): # SDS
		handleSds(m_message)
		return

#	elif (m_message[0 : 7] == '8[23 [0-9A-F {3,}' ): # TEXT_SDS
		handleSdsMsg(m_message)
		return

	elif (m_message[0 : 2] == '02'): # SIMPLE_TEXT_SDS
		handleSdsMsg(m_message)
		return

#	elif (m_message[0 : 7] == ''): # SIMPLE_TEXT_SDS
#	elif (m_message[0 : 7] == '[8-9A-F [0-9A-F {3}$'): # STATE_SDS
		handleSdsMsg(m_message)
		return

#	elif (m_message[0 : 7] == ''): # COMPLEX_SDS
	elif (m_message[0 : 2] == '0C'): # CONCAT_SDS
#	elif (m_message[0 : 7] == ''): # LIP_SDS
		handleSdsMsg(m_message)
		return

	elif (m_message[0 : 6] == '+CMGS:'): # CMGS
		# sds state send be MS
		handleCmgs(m_message)
		return

	elif (m_message[0 : 6] == '+CTXD:'): # TX_DEMAND
		return

	elif (m_message[0 : 6] == '+CTXG:'): # TRANSMISSION_GRANT
		handleTxGrant(m_message)
		return

	elif (m_message[0 : 6] == '+CTCC:'): # CALL_CONNECT
		handleCci(m_message)
		return

#	elif (m_message[0 : 7] == '+CTOM: [0-9 $'): # OP_MODE
		getAiMode(m_message)
		return

	elif (m_message[0 : 6] == '+CTGS:'): # CTGS
		handleCtgs(m_message)
		return

	elif (m_message[0 : 7] == '+CTDGR:'): # CTDGR
		handleCtdgr(m_message)
		return

	elif (m_message[0 : 6] == '+CLVL:'): # CLVL
		handleClvl(m_message)
		return

	elif (m_message[0 : 7] == 'INVALID'):
		print "+++ Pei answer not known, ignoring ;"
		return

	else:
		print "Uknown Command m_message = " + m_message
		#print "  Len(m_message) = " + str(len(m_message))
		OpCode = m_message.split(':')[0]
		#print "  OpCode " + OpCode
		Data = m_message.split(':', 1)[-1]
		#print "  Data " + Data
		return

	if (peirequest == INIT and (response == OK or response == ERROR)):
		initPei()
	return

##################################################################
def initGroupCall(gc_gssi):
	global inTransmission
	inTransmission = True
	cmd = "AT+CTSDC=0,0,0,1,1,0,1,1,0,0,0"
	sendPei(cmd)
	cmd = "ATD" + str(gc_gssi)
	sendPei(cmd)
	print "init_group_call " + str(gc_gssi)
	return

##################################################################
def handleCallBegin(message):
	squelchOpen(True) # open the Squelch

	message = message.replace('+CTICN: ', '')
	global instance
	global callstatus
	global aistatus
	global origin_cpit
	global mcc
	global mnc
	h = message.split(",")
	t_ci_instance = h[0]
	t_ci_callstatus = h[1]
	t_ci_aistatus = h[2]
	t_ci_origin_cpit = h[3]
#	print "  t_ci.instance = " + str(t_ci_instance)
#	print "  t_ci.callstatus = " + str(t_ci_callstatus)
#	print "  t_ci.aistatus = " + str(t_ci_aistatus)
#	print "  t_ci.origin_cpit = " + str(t_ci_origin_cpit)

	o_tsi = h[4]
	if (len(o_tsi) < 9):
		print "o_tsi " + d_tsi
#		t_ci.o_issi = atoi(o_tsi.c_str());
		t = mcc
		t += mnc
		t += getISSI(o_tsi)
		o_tsi = t;
		t_ci_o_mcc = dmcc
		t_ci_o_mnc = dmnc
		o_mcc = int(o_tsi[0:4])
		o_mnc = int(o_tsi[4:9])
		o_issi = int(o_tsi[9:17])
		print "  o_mcc = " + str(o_mcc)
		print "  o_mnc = " + str(o_mnc)
		print "  o_issi = " + str(o_issi)
		print "  t_ci.o_mnc = " + str(t_ci_o_mnc)
		print "  t_ci.o_mcc = " + str(t_ci_o_mcc)
	else:
#		splitTsi(o_tsi, t_ci.o_mcc, t_ci.o_mnc, t_ci.o_issi);
		o_mcc = int(o_tsi[0:4])
		o_mnc = int(o_tsi[4:9])
		o_issi = int(o_tsi[9:17])
		print "  o_mcc = " + str(o_mcc)
		print "  o_mnc = " + str(o_mnc)
		print "  o_issi = " + str(o_issi)

	t_ci_hook = h[5]
	t_ci_simplex = h[6]
	t_ci_e2eencryption = h[7]
	t_ci_commstype = h[8]
	t_ci_codec = h[9]
	t_ci_dest_cpit = h[10]
#	print "  t_ci.hook = " + str(t_ci_hook)
#	print "  t_ci.simplex = " + str(t_ci_simplex)
#	print "  t_ci.e2eencryption = " + str(t_ci_e2eencryption)
#	print "  t_ci.commstype = " + str(t_ci_commstype)
#	print "  t_ci.codec = " + str(t_ci_codec)
#	print "  t_ci.dest_cpit = " + str(t_ci_dest_cpit)

	d_tsi = str(h[11])
	if (len(d_tsi) < 9):
		print "d_tsi " + d_tsi
#		t_ci.d_issi = atoi(d_tsi.c_str());
		t = mcc
		t += mnc
		t += getISSI(d_tsi)
		d_tsi = t
		t_ci_d_mnc = dmnc
		t_ci_d_mcc = dmcc
		d_mcc = int(d_tsi[0:4])
		d_mnc = int(d_tsi[4:9])
		d_issi = int(d_tsi[9:17])
		print "  d_mcc = " + str(d_mcc)
		print "  d_mnc = " + str(d_mnc)
		print "  d_issi = " + str(d_issi)
		print "  t_ci.d_mnc = " + str(t_ci_d_mnc)
		print "  t_ci.d_mcc = " + str(t_ci_d_mcc)
	else:
#		splitTsi(d_tsi, t_ci.d_mcc, t_ci.d_mnc, t_ci.d_issi)
		d_mcc = int(d_tsi[0:4])
		d_mnc = int(d_tsi[4:9])
		d_issi = int(d_tsi[9:17])
		print "  d_mcc = " + str(d_mcc)
		print "  d_mnc = " + str(d_mnc)
		print "  d_issi = " + str(d_issi)
	
#	t_ci.prio = atoi(h.c_str())

	# store call specific data into a Callinfo struct
#	callinfo[t_ci.instance] = t_ci;

	# check if the user is stored? no -> default
#	std::map<std::string, User>::iterator iu = userdata.find(o_tsi);
#	if (iu == userdata.end()):
#		Sds t_sds;
#		t_sds.direction = OUTGOING;
#		t_sds.message = infosds;
#		t_sds.tsi = o_tsi;
#		t_sds.type = TEXT;
#		firstContact(t_sds);
#		return

#	userdata[o_tsi].last_activity = time(NULL);

	# store info in Qso struct
#	Qso.tsi = o_tsi;
#	Qso.start = time(NULL);

	# prepare event for tetra users to be send over the network

	print "groupcall_begin " + str(o_issi) + " " + str(d_issi)

#	m_aprsmesg << aprspath << ">" << iu->second.call << " initiated groupcall: " 
#	<< t_ci.o_issi << " -> " << t_ci.d_issi;
#	sendAprs(iu->second.call, m_aprsmesg.str());
	
# Missing a lot of code to pass here
	
	return

##################################################################
def handleSds(m_message):
	Data = m_message.replace('+CTSDSR: ', '')
	sds = Data.split(",")

	# store header of sds for further handling
#	pSDS.aiservice = sds[0] # type of SDS (TypeOfService 0-12)
#	pSDS.fromtsi = getTSI(sds[1]) # sender Tsi (23404)
	pass											# (0)
#	pSDS.totsi = getTSI(sds[3]); # destination Issi
	pass											# (0)
	pass											# Sds length (112)
#	pSDS.last_activity = time()

	return

##################################################################
def handleSdsMsg(sds):
# A lot to do
	return

##################################################################
def handleClvl(m_message):
	m_message = m_message.replace('+CLVL: ', '')
	audio_level = m_message.split(",")
	print "audio_level " + audio_level[0]
	return

##################################################################
def handleCmgs(m_message):
	global debug
	m_message = m_message.replace('+CMGS: ', '')
	Val = m_message.split(",")
	sds_inst = Val[0]
	state = Val[1]
	id_ = Val[2]

	if (last_sdsinstance == sds_inst):
		if (state == SDS_SEND_FAILED):
			if (debug >= LOGERROR):
				print "*** ERROR: Send message failed. Will send again..."
#			pending_sds.tos = 0;
		elif (state == SDS_SEND_OK):
			if (debug >= LOGINFO):
				print "+++ Message sent OK, #" + id_
			cmgs_received = True
	cmgs_received = True
	last_sdsinstance = sds_inst
	checkSds()
	return

##################################################################
def handleTextSds(m_message):
	if (len(m_message) > 8):
		m_message = m_message[8 : len(m_message) - 8] # delete 00A3xxxx
	return decodeSDS(m_message)

##################################################################
def handleAckSds(m_message, tsi):
	t_msg = tsi
	return t_msg

##################################################################
def handleSimpleTextSds(m_message):
	if (len(m_message) > 4):
		m_message = m_message[4 : len(m_message) - 4] # delete 0201
	return decodeSDS(m_message);

##################################################################
def handleTxGrant(txgrant):
	squelchOpen(True) # open Squelch
	print "tx_grant"

##################################################################
def getTSI(issi):
	pass
#	stringstream ss;
#	char is[18];
#	int len = issi.length(); 
#	int t_mcc;
#	std::string t_issi;

#	if (len < 9):
#		sprintf(is, "%08d", atoi(issi.c_str()));
#		ss << mcc << mnc << is;
#		return ss.str();

	# get MCC (3 or 4 digits)
#	if (issi.substr(0,1) == "0")
#		t_mcc = atoi(issi.substr(0,4).c_str());
#		issi.erase(0,4);
#	else:
#		t_mcc = atoi(issi.substr(0,3).c_str());
#		issi.erase(0,3);

	# get ISSI (8 digits)
#	t_issi = issi.substr(len-8,8);
#	issi.erase(len-8,8);

#	sprintf(is, "%04d%05d%s", t_mcc, atoi(issi.c_str()), t_issi.c_str());
#	ss << is;

#	return ss.str();

##################################################################
def handleStateSds(isds):
	global debug
#	stringstream ss;

	if (debug >= LOGINFO):
		print "+++ State Sds received: " + str(isds)

#	std::map<unsigned int, string>::iterator it = sds_to_command.find(isds);

#	if (it != sds_to_command.end())
		# to connect/disconnect Links
#		ss << it->second << "#";
#		injectDtmf(ss.str(), 10);

#	it = state_sds.find(isds);
#	if (it != state_sds.end())
		# process macro, if defined
#		ss << "D" << isds << "#";
#		injectDtmf(ss.str(), 10);

##################################################################
def handleTransmissionEnd(message):
	squelchOpen(False)
	print "groupcall_end"
	return
	
##################################################################
def handleCallReleased(message):
	global tetra_modem_sql
	global talkgroup_up
	global inTransmission
#	Qso.stop = time(NULL)
	message = message.replace('+CTCR: ', '')
	Val = message.split(",")
	cci = int(Val[0])
	if (tetra_modem_sql == True):
		squelchOpen(False) # close Squelch
		print "out_of_range " + str(int(Val[1]))
	else:
		print "call_end " + defs.DisconnectCause[Val[1]]

	# Send to APRS Transmission ended
#	m_aprsmesg += ">Transmission ended"
#	sendAprs(userdata[Qso.tsi].call, m_aprsmesg);
	talkgroup_up = False

	inTransmission = False
#	checkSds() # resend Sds after MS got into Rx mode
	return

##################################################################
def sendPei(cmd):
	# a sdsmsg must end with 0x1a
	#if (ord(cmd[-1:]) != 0x0A):
		#cmd += chr(0x0A)
	pei.write(cmd + chr(0x0D) + chr(0x0A))
	if (debug >= LOGDEBUG):
		print "  To PEI:" + cmd
	return

##################################################################
def handleCnumf(m_message):
	global dmcc
	global dmnc
	global peirequest
	
	print "PEI:Rx +CNUMF: "
	print "  m_message = " + m_message
	m_message = m_message.replace('+CNUMF: ', '')

	Value = m_message.split(",") # Create an array separating values by ','

	m_numtype = int(Value[0])
	if (debug >= LOGINFO):
		print "<num type> is " + str(m_numtype) 

	if (m_numtype == 6 or m_numtype == 0):
		# get the tsi and split it into mcc,mnc,issi
		#splitTsi(m_message, t_mcc, t_mnc, t_issi);
		tsi = Value[1]
		t_mcc = int(tsi[0:4])
		t_mnc = int(tsi[4:9])
		t_issi = int(tsi[9:17])
		print "  t_mcc = " + str(t_mcc)
		print "  t_mnc = " + str(t_mnc)
		print "  t_issi = " + str(t_issi)

	dmcc = t_mcc
	dmnc = t_mnc
	
	peirequest = INIT_COMPLETE
	
	return



##################################################################
def splitTsi(tsi, mcc, mnc, issi):
	print "splitTsi" + tsi
	ret = False
	size = len(tsi)
	print "len(tsi) = " + str(size)

	mcc = int(tsi[0:4])
	mnc = int(tsi[4:9])
	issi = int(tsi[9:17])
	return



##################################################################
def getAiMode(aimode):
	global debug
	if (len(aimode) > 6):
#		t = atoi(aimode.erase(0,6).c_str());
		if (debug >= LOGINFO):
			print "+++ New Tetra mode: " + AiMode[t]
		print "tetra_mode " + t
	return



##################################################################
def handleCci(m_message):
	m_message = m_message.replace('+CTCC: ', '')
	Val = m_message.split(",")
	return Val[0]



##################################################################
def transmitterStateChange(is_transmitting):
	global talkgroup_up
	global gssi
	global current_cci
	global mute_rx_on_tx
	
	if (is_transmitting):
		if (not talkgroup_up):
			initGroupCall(gssi)
			talkgroup_up = True
		else:
			cmd = "AT+CTXD="
			cmd += str(current_cci)
			cmd += ",1"
			sendPei(cmd)
	else:
		cmd = "AT+CUTXC="
		cmd += str(current_cci)
		sendPei(cmd)
	
	if (mute_rx_on_tx):
		#rx().setMuteState(is_transmitting ? Rx::MUTE_ALL : Rx::MUTE_NONE);
		pass
	#Logic::transmitterStateChange(is_transmitting);
	return

##################################################################
def squelchOpen(is_open):
	global tetra_modem_sql
	global SQL_GPIO
	#if (tx().isTransmitting()):
	#	return

	tetra_modem_sql = is_open;
	#rx().setSql(is_open);
	#Logic::squelchOpen(is_open);	#GPIO19=SQL
	GPIO.output(SQL_GPIO, not is_open)
	return









#################################################################################
# Misc Subs #####################################################################
#################################################################################
def getPeiError(Error):
	print " +CME ERROR: " + defs.peiError[Error]
	return



# return the ISSI as part of the TEI
def getISSI(tsi):
	size = len(tsi)
	if (size < 8):
		t_issi = "00000000" + tsi
		return str(t_issi[size - 8 : 8])
	t_issi = tsi[size - 8 : 8]
	return str(t_issi)

###############################################################################
# Hot Keys
###############################################################################
def HotKeys():
	global Run
	if kb.kbhit():
		c = kb.getch()
		if ord(c) == 27: # Esc
			print "Esc key pressed."
			Run = 0
		elif c == 'q': # Quit
			print "q key pressed."
			Run = 0
		elif c == 'a': # AT Command
			print "a key pressed."
			sendPei("AT")
		elif c == 'T': # AT Command
			print "T key pressed."
			transmitterStateChange(True)
		elif c == 't': # AT Command
			print "t key pressed."
			transmitterStateChange(False)

		else :
			print "Leter " + c
class KBHit:
	def __init__(self):
		'''Creates a KBHit object that you can call to do various keyboard things.
		'''

		if os.name == 'nt':
			pass
		else:
			# Save the terminal settings
			self.fd = sys.stdin.fileno()
			self.new_term = termios.tcgetattr(self.fd)
			self.old_term = termios.tcgetattr(self.fd)
			# New terminal setting unbuffered
			self.new_term[3] = (self.new_term[3] & ~termios.ICANON & ~termios.ECHO)
			termios.tcsetattr(self.fd, termios.TCSAFLUSH, self.new_term)
			# Support normal-terminal reset at exit
			atexit.register(self.set_normal_term)

	def set_normal_term(self):
		''' Resets to normal terminal.	On Windows this is a no-op.
		'''
		if os.name == 'nt':
			pass
		else:
			termios.tcsetattr(self.fd, termios.TCSAFLUSH, self.old_term)

	def getch(self):
		''' Returns a keyboard character after kbhit() has been called.
			Should not be called in the same program as getarrow().
		'''
		s = ''
		if os.name == 'nt':
			return msvcrt.getch().decode('utf-8')
		else:
			return sys.stdin.read(1)

	def getarrow(self):
		''' Returns an arrow-key code after kbhit() has been called. Codes are
		0 : up
		1 : right
		2 : down
		3 : left
		Should not be called in the same program as getch().
		'''
		if os.name == 'nt':
			msvcrt.getch() # skip 0xE0
			c = msvcrt.getch()
			vals = [72, 77, 80, 75]
		else:
			c = sys.stdin.read(3)[2]
			vals = [65, 67, 66, 68]
		return vals.index(ord(c.decode('utf-8')))

	def kbhit(self):
		''' Returns True if keyboard character was hit, False otherwise.
		'''
		if os.name == 'nt':
			return msvcrt.kbhit()
		else:
			dr,dw,de = select([sys.stdin], [], [], 0)
			return dr != []






###############################################################################
# GPIO
###############################################################################
def GPIO_Callback(channel): # Change to High
	global PTT_GPIO
	if (channel == PTT_GPIO):
		PTT = GPIO.input(PTT_GPIO)
		print "PTT_GPIO = " + PTT













if __name__ == "__main__":
	try:
		main()
	except KeyboardInterrupt:
		pass
