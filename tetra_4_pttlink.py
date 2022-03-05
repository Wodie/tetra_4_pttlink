#!/usr/bin/env python

import time
import serial
import os
import defs
import settings
import RPi.GPIO as GPIO
import math
import aprs



AppName = 'TETRA 4 PTTLink'
VersionInfo = '1'
MinorVersionInfo = '00'
RevisionInfo = '0'
Version = VersionInfo + '.' + MinorVersionInfo + '.' + RevisionInfo
print('\n##################################################################')
print(f'	*** {AppName} v{Version} ***')
print('	Released: March 05, 2022. Created March 01, 2022.')
print('	Created by:')
print('	Juan Carlos Perez De Castro (Wodie) KM4NNO / XE1F')
print('	www.wodielite.com')
print('	wodielite at mac.com')
print('	km4nno at yahoo.com\n')
print('	License:')
print('	This software is licenced under the GPL v3.')
print('	If you are using it, please let me know, I will be glad to know it.\n')
print('	This project is based on the work and information from:')
print('	Juan Carlos Perez KM4NNO / XE1F')
print('	APRS is a registed trademark and creation of Bob Bruninga WB4APR')
print('\n##################################################################\n')

# Detect Target OS.
import sys
sys.platform
if sys.platform.startswith('linux'): # could be 'linux', 'linux2', 'linux3', ...
	# Linux
	print(sys.platform)
elif sys.platform == 'darwin' :
	# MAC OS X
	print(sys.platform)
elif sys.platform == 'win32' :
	# Windows (either 32-bit or 64-bit)
	print(sys.platform)

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

# Raspberry GPIO
GPIO.setwarnings(False) # Ignore warning for now
GPIO.setmode(GPIO.BCM) # Use GPIO number
#GPIO.setmode(GPIO.BOARD) # Use physical pin numbering
GPIO.setup(settings.PTT_GPIO, GPIO.IN, pull_up_down = GPIO.PUD_UP)
GPIO.setup(settings.SQL_GPIO, GPIO.OUT)
GPIO.setup(settings.AUX_GPIO, GPIO.OUT)
GPIO.output(settings.SQL_GPIO, 1)
GPIO.output(settings.AUX_GPIO, 1)


# Tetra program variables
class C_Tetra(object):
	mute_rx_on_tx = True
#	mute_tx_on_rx = True
#	rgr_sound_always = False
	mcc = ''
	mnc = ''
	issi = ''
	gssi = 1
	initstr = ''
	pei = ''
	sds_pty = 0
	peistream = ''
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
	endCmd = ''
	new_sds = False
	inTransmission = False
	cmgs_received = True
	share_userinfo = True
	current_cci = 0
	dmnc = 0
	dmcc = 0
	infosds = ''

	peirequest = defs.INIT_0
	last_sdsinstance = ''
	tetra_modem_sql = False
	pei_Buffer = [ord('A')]
 # Clear Rx buffer.
	# Timer
	pei_TimerEnabled = True
	pei_NextTimer = 0;
	pei_Timeout = 0;
	pei_TimerInterval = 10; # Seconds.

tetra = C_Tetra()

class C_Call(object):
	mute_rx_on_tx = ''
	mute_tx_on_rx = ''
	rgr_sound_always = ''
	mcc = ''
	mnc = ''
	issi = ''
	gssi = ''
	port = ''
	baudrate = ''
	initstr = ''
	pei = ''
	sds_pty = ''
	dapnetclient = ''

class C_Callinfo(object):
	instance = ''
	callstatus = ''
	aistatus = ''
	origin_cpit = ''
	o_mcc = ''
	o_mnc = ''
	o_issi = ''
	hook = ''
	simplex = ''
	e2eencryption = ''
	commstype = ''
	codec = ''
	dest_cpit = ''
	d_mcc = ''
	d_mnc = ''
	d_issi = ''
	prio = ''

class C_Qso(object):
	tsi = ''
	start = ''
	stop = ''
	members = ''
Qso = C_Qso()

class C_Sds(object):
	id = 0					# message reference id
	tsi = ''				# destination TSI
	remark = ''				# description/state/remark
	message = ''			# Sds as text
	tos = 0					# Unix time of sending
	tod = 0					# Unix time of delivery
	_type = ''				# STATE, LIP_SHORT,..
	direction = ''			# INCOMING, OUTGOING
	nroftries = 0			# number of tries
	aiservice = ''			# AI service / type of service
pending_sds = C_Sds() # the Sds that will actually be handled

class C_User(object):
	issi =''
	call = ''
	name = ''
	comment = ''
	location =''
	lat = 0.0
	lon = 0.0
	state = ''
	reasonforsending = 1
	aprs_sym =''
	aprs_tab = ''
	last_activity = ''
	sent_last_sds = ''
userdata = C_User()

class C_DmoRpt(object):
	issi = 0
	mni = ''
	state = 0
	last_activity = 0
dmo_rpt_gw = C_DmoRpt()

class C_pSds(object):
	sdstype = ''
	aiservice = ''
	fromtsi = ''
	totsi = ''
	last_activity = ''
pSDS = C_pSds()

class LipInfo(object):
	time_elapsed = 0
	latitude = 0.0
	longitude = 0.0
	positionerror = 0.0
	horizontalvelocity = 0.0
	directionoftravel = 0.0
	reasonforsending = ''











class C_APRS(object):
	path = ''
	symbol = ''

APRS = C_APRS()



# Misc
kb = ''
Run = True



###############################################################################
# Main ########################################################################
###############################################################################
def main():
	# Serial Port
	if sys.platform.startswith('linux'):
		# configure the serial connections (the parameters differs on the device you are connecting to)
		tetra.pei = serial.Serial(
			port = settings.serial_port,
			baudrate = settings.baudrate,
			parity = serial.PARITY_NONE,
			stopbits = serial.STOPBITS_ONE,
			bytesize = serial.EIGHTBITS,
			timeout = 1
		)
	elif sys.platform == 'darwin' : # MAC OS X
		# configure the serial connections (the parameters differs on the device you are connecting to)
		tetra.pei = serial.Serial(
			port = '/dev/tty.usbserial',
			baudrate = settings.baudrate,
			parity = serial.PARITY_NONE,
			stopbits = serial.STOPBITS_ONE,
			bytesize = serial.EIGHTBITS,
			timeout = 1
		)
	tetra.pei.isOpen()

	# GPIO Events
	global GPIO
	GPIO.add_event_detect(settings.PTT_GPIO, GPIO.BOTH, callback = GPIO_Callback) # Setup event on pin 10 rising edge

	# APRS
	tetra.aprspath = "APRS,qAR,"
	tetra.aprspath += settings.Callsign
	tetra.aprspath += "-10:"

	# Default values.
	global kb
	kb = KBHit()
	print('Hit any key, or ESC to exit')

	global Run
	while (Run):
		MainLoop()
	# Program exit:
	print('----------------------------------------------------------------------')
	kb.set_normal_term()
	transmitterStateChange(False)
	tetra.pei.close()
	GPIO.cleanup()
#	if ($APRS_IS and $APRS_IS->connected()) {
#		$APRS_IS->disconnect();
#		print color('yellow'), 'APRS-IS Disconected.\n', color('reset');

	print('Good bye cruel World.')
	print('----------------------------------------------------------------------\n')
	exit()



###############################################################################
# Main Loop ###################################################################
###############################################################################
def MainLoop():
	HotKeys() # Keystrokes events.
	
	initPei()

	Read_Serial()

	pei_Timer()

	# let's wait one second before reading output (let's give device time to answer)
	time.sleep(0.01)
#	print('Looping the right way.'
	return



###############################################################################
# Serial ######################################################################
###############################################################################
def Read_Serial():
	#print('Read_Serial'
	# Check if incoming bytes are waiting to be read from the serial input 
	# buffer.
	# NB: for PySerial v3.0 or later, use property `in_waiting` instead of
	# function `inWaiting()` below!
	#if (ser.inWaiting() > 0):
	if (tetra.pei.in_waiting > 0):
		# read the bytes and convert from binary array to ASCII
		#data_str = ser.read(ser.inWaiting()).decode('ascii') 
		# print the incoming string without putting a new-line
		# ('\n') automatically after every print()
		#print(data_str, end='') 

#		SerialBuffer = pei.readline(pei.in_waiting) # Read Rx chars.
#		Serial_Rx(SerialBuffer, 0); # Process a full data stream.
		#print('Len(SerialBuffer) = ' + str(len(SerialBuffer))

		RxBytes = tetra.pei.read(tetra.pei.in_waiting) # Read Rx chars.
		#print('RxBytes = ' + str(RxBytes))
		#print('  Len(RxBytes) = ' + str(len(RxBytes)))
		Buf_Len = len(RxBytes)
		if (Buf_Len >= 1):
			for x in range(0, Buf_Len):
				#print('x = ' + str(x) + ' byte ' + str(ord(RxBytes[x : x + 1])))
				if (ord(RxBytes[x : x + 1]) == 0x0D): # if CR
					#print('CR len(tetra.pei_Buffer) = ' + str(len(tetra.pei_Buffer)))
					if (len(tetra.pei_Buffer) > 0):
						message = ''
						for i in tetra.pei_Buffer:
							#print('i = ' + str(i))
							message += chr(i)
						#print('message = ' + message)
						#print('  pei_Buffer = ' + str(tetra.pei_Buffer))
						#print('  len(tetra.pei_Buffer) = ' + str(len(tetra.pei_Buffer)))
						handlePeiAnswer(message) # Process a full line of data.
					tetra.pei_Buffer.clear()
				elif (ord(RxBytes[x : x + 1]) == 0x0A): # if LF
					pass
				else :
					tetra.pei_Buffer.append(ord(RxBytes[x : x + 1]))
	return



###############################################################################
# TetraLogic ##################################################################
###############################################################################
def transmitterStateChange(is_transmitting):
	if (is_transmitting):
		if (not tetra.talkgroup_up):
			initGroupCall(tetra.gssi)
			tetra.talkgroup_up = True
		else:
			cmd = 'AT+CTXD='
			cmd += str(tetra.current_cci)
			cmd += ',1'
			sendPei(cmd)
	else:
		cmd = 'AT+CUTXC='
		cmd += str(tetra.current_cci)
		sendPei(cmd)
	
	if (tetra.mute_rx_on_tx):
		# rx().setMuteState(is_transmitting ? Rx::MUTE_ALL : Rx::MUTE_NONE);
		pass
	#Logic::transmitterStateChange(is_transmitting);
	return

###############################################################################
def squelchOpen(is_open):
	global GPIO
	#if (tx().isTransmitting()):
	#	return

	tetra.tetra_modem_sql = is_open
	setSql(is_open)
	#rx().setSql(is_open);
	#Logic::squelchOpen(is_open);	#GPIO19=SQL
	GPIO.output(settings.SQL_GPIO, not is_open)

	if (is_open):
		os.system('sudo python change_sql.py --sql 0')
	else:
		os.system('sudo python change_sql.py --sql 1')
	return



###############################################################################
# PEI #########################################################################
###############################################################################
# Initialize the Pei device, here some commends that being used
# to (re)direct the answers to the Pei port. See EN 300 392-5
# V2.2.0 manual, page 62 for further info
# TETRA Service Profile +CTSP:
# +CTSP=<service profile>, <service layer1>, [<service layer2>],
#       [<AI mode>], [<link identifier>]
# AT+CTOM=1           set MRT into DMO-MS mode (0-TMO, 6-DMO-Repeater)
# AT+CTSP=1,3,131     Short Data Service type 4 with Transport Layer (SDS-TL)
#                     service
#                     131 - GPS
# AT+CTSP=1,3,130     130 - Text Messaging
# AT+CTSP=1,2,20      Short Data Service (SDS)
#                     20 - Status
# AT+CTSP=2,0,0       0 - Voice
# AT+CTSP=1,3,24      24 - SDS type 4, PID values 0 to 127
# AT+CTSP=1,3,25      25 - SDS type 4, PID values 128 to 255
# AT+CTSP=1,3,3       3 - Simple GPS
# AT+CTSP=1,3,10      10 - Location information protocol
# AT+CTSP=1,1,11      11 - Group Management
# TETRA service definition for Circuit Mode services +CTSDC
# +CTSDC=<AI service>, <called party identity type>, [<area>], [<hook>],
#        [<simplex>], [<end to end encryption>],[<comms type>],
#        [<slots/codec>], [<RqTx>], [<priority>], [<CLIR control>]
# AT+CTSDC=0,0,0,1,1,0,1,1,0,0
def initPei():
	#global peiBreakCommandTimer

	if (tetra.peirequest == defs.AT_CMD_WAIT):
		#peiBreakCommandTimer.reset()
		#peiBreakCommandTimer.setEnable(true)
		pass

	if (tetra.peirequest == defs.INIT_0):
		cmd = ''
		cmd = ''
		sendPei(cmd)
		time.sleep(0.2)
		tetra.peirequest = defs.INIT_1
		return
	elif (tetra.peirequest == defs.INIT_1):
		cmd = 'AT'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_2
		return

	elif (tetra.peirequest == defs.INIT_2):
		cmd = 'AT+CTOM=6,0'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_3
		return
	elif (tetra.peirequest == defs.INIT_3):
		cmd = 'AT+CTSP=1,3,131'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_4
		return
	elif (tetra.peirequest == defs.INIT_4):
		cmd = 'AT+CTSP=1,3,130'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_5
		return
	elif (tetra.peirequest == defs.INIT_5):
		cmd = 'AT+CTSP=1,3,138'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_6
		return
	elif (tetra.peirequest == defs.INIT_6):
		cmd = 'AT+CTSP=1,2,20'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_7
		return
	elif (tetra.peirequest == defs.INIT_7):
		cmd = 'AT+CTSP=2,0,0'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_8
		return
	elif (tetra.peirequest == defs.INIT_8):
		cmd = 'AT+CTSP=1,3,24'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_9
		return
	elif (tetra.peirequest == defs.INIT_9):
		cmd = 'AT+CTSP=1,3,25'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_10
		return
	elif (tetra.peirequest == defs.INIT_10):
		cmd = 'AT+CTSP=1,3,3'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_11
		return
	elif (tetra.peirequest == defs.INIT_11):
		cmd = 'AT+CTSP=1,3,10'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_12
		return
	elif (tetra.peirequest == defs.INIT_12):
		cmd = 'AT+CTSP=1,1,11'
		sendPei(cmd)
		tetra.peirequest = defs.INIT_13
		return
	elif (tetra.peirequest == defs.INIT_13):
		cmd = 'AT+CTSDC=0,0,0,1,1,0,1,1,0,0'
		sendPei(cmd)
		tetra.peirequest = defs.INIT
		return

	elif (tetra.peirequest == defs.INIT):
		cmd = 'AT+CNUMF?' # get the MCC,MNC,ISSI from MS
		sendPei(cmd)
		ss = 'pei_init_finished'
		print(ss)
		sendUserInfo() # send userinfo to reflector
		tetra.peirequest = defs.INIT_COMPLETE
	return

###############################################################################
def sendUserInfo():

# To Do

	return

###############################################################################
def handlePeiAnswer(m_message):
	response = ''

	if (settings.debug >= defs.LOGINFO):
		print('From PEI:' + m_message)
		#print('	len(m_message)' + str(len(m_message))

	if (m_message.startswith('OK')):
		tetra.peistate = defs.OK
		response = defs.OK
#		if (new_sds and not inTransmission):
#			checkSds()
		return

	elif (m_message.startswith('+CME ERROR:')):
		tetra.peistate = defs.ERROR
		response = defs.ERROR
		if (len(m_message) > 11):
			Error = int(m_message.split(':', 1)[-1])
			print(' +CME ERROR: ' + str(Error))
		return

	elif (m_message.startswith('+CNUMF:')): # CNUMF, Local Radio MCC, MNC and ISSI
		handleCnumf(m_message)
		return

	elif (m_message.startswith('+CTICN:')): # CALL_BEGIN
		handleCallBegin(m_message)
		return

	elif (m_message.startswith('+CDTXC:')): # TRANSMISSION_END
		handleTransmissionEnd(m_message)
		return

	elif (m_message.startswith('+CTCR:')): # CALL_RELEASED
		handleCallReleased(m_message)
		return

	elif (m_message.startswith('+CTSDSR:')): # SDS
		handleSds(m_message)
		return

	#elif (m_message[0 : 7] == '^8210[0-9A-F {4}'): # ACK_SDS
	elif (m_message.startswith('8210')): # ACK_SDS
		print('ACK_SDS')
		return

	#elif (m_message[0 : 7] == '8[23 [0-9A-F {3,}' ): # TEXT_SDS
	elif (m_message.startswith('8')): # TEXT_SDS
		handleSdsMsg(m_message)
		return

	elif (m_message.startswith('02')): # SIMPLE_TEXT_SDS
		handleSdsMsg(m_message)
		return

	#elif (m_message[0 : 7] == '[8-9A-F [0-9A-F {3}$'): # STATE_SDS
	elif (	len(m_message) == 4 and # STATE_SDS
			(ord(m_message[0 : 1]) >= 0x38 and ord(m_message[0 : 1]) <= 0x39) and
			(ord(m_message[1 : 2]) >= 0x30 and ord(m_message[1 : 2]) <= 0x39 or
			ord(m_message[1 : 2]) >= 0x41 and ord(m_message[1 : 2]) <= 0x46) and
			(ord(m_message[2 : 3]) >= 0x30 and ord(m_message[2 : 3]) <= 0x39 or
			ord(m_message[2 : 3]) >= 0x41 and ord(m_message[2 : 3]) <= 0x46) and
			(ord(m_message[3 : 4]) >= 0x30 and ord(m_message[3 : 4]) <= 0x39 or
			ord(m_message[3 : 4]) >= 0x41 and ord(m_message[3 : 4]) <= 0x46) ):
		handleSdsMsg(m_message)
		return

	#elif (m_message[0 : 1] == ''): # COMPLEX_SDS
		handleSdsMsg(m_message)
		return

	elif (m_message.startswith('0C')): # CONCAT_SDS
		handleSdsMsg(m_message)
		return

	elif (	m_message.startswith('0A') and # LIP_SDS
			(ord(m_message[2 : 3]) >= 0x30 and ord(m_message[2 : 3]) <= 0x39 or
			ord(m_message[2 : 3]) >= 0x41 and ord(m_message[2 : 3]) <= 0x46) and
			(ord(m_message[3 : 4]) >= 0x30 and ord(m_message[3 : 4]) <= 0x39 or
			ord(m_message[3 : 4]) >= 0x41 and ord(m_message[3 : 4]) <= 0x46) and
			(ord(m_message[4 : 5]) >= 0x30 and ord(m_message[4 : 5]) <= 0x39 or
			ord(m_message[4 : 5]) >= 0x41 and ord(m_message[4 : 5]) <= 0x46) and
			(ord(m_message[5 : 6]) >= 0x30 and ord(m_message[5 : 6]) <= 0x39 or
			ord(m_message[5 : 6]) >= 0x41 and ord(m_message[5 : 6]) <= 0x46) and
			(ord(m_message[6 : 7]) >= 0x30 and ord(m_message[6 : 7]) <= 0x39 or
			ord(m_message[6 : 7]) >= 0x41 and ord(m_message[6 : 7]) <= 0x46) and
			(ord(m_message[7 : 8]) >= 0x30 and ord(m_message[7 : 8]) <= 0x39 or
			ord(m_message[7 : 8]) >= 0x41 and ord(m_message[7 : 8]) <= 0x46) and
			(ord(m_message[8 : 9]) >= 0x30 and ord(m_message[8 : 9]) <= 0x39 or
			ord(m_message[8 : 9]) >= 0x41 and ord(m_message[8 : 9]) <= 0x46) and
			(ord(m_message[9 : 10]) >= 0x30 and ord(m_message[9 : 10]) <= 0x39 or
			ord(m_message[9 : 10]) >= 0x41 and ord(m_message[9 : 10]) <= 0x46) and
			(ord(m_message[10 : 11]) >= 0x30 and ord(m_message[10 : 11]) <= 0x39 or
			ord(m_message[10 : 11]) >= 0x41 and ord(m_message[10 : 11]) <= 0x46) and
			(ord(m_message[11 : 12]) >= 0x30 and ord(m_message[11 : 12]) <= 0x39 or
			ord(m_message[11 : 12]) >= 0x41 and ord(m_message[11 : 12]) <= 0x46) and
			(ord(m_message[12 : 13]) >= 0x30 and ord(m_message[12 : 13]) <= 0x39 or
			ord(m_message[12 : 13]) >= 0x41 and ord(m_message[12 : 13]) <= 0x46) and
			(ord(m_message[13 : 14]) >= 0x30 and ord(m_message[13 : 14]) <= 0x39 or
			ord(m_message[13 : 14]) >= 0x41 and ord(m_message[13 : 14]) <= 0x46) ):
		handleSdsMsg(m_message)
		return

	elif (m_message.startswith('+CMGS:')): # CMGS
		# +CMGS: <SDS Instance>[, <SDS status> [, <message reference>]]
		# sds state send be MS
		handleCmgs(m_message)
		return

	elif (m_message.startswith('+CTXD:')): # TX_DEMAND
		return

	elif (m_message.startswith('+CTXG:')): # TRANSMISSION_GRANT
		handleTxGrant(m_message)
		return

	elif (m_message.startswith('+CTCC:')): # CALL_CONNECT
		tetra.current_cci = handleCci(m_message)
		return

	#elif (m_message[0 : 7] == '+CTOM: [0-9 $'): # OP_MODE
	elif (m_message.startswith('+CTOM: ') and  # OP_MODE
			ord(m_message[7 : 8]) >= 0x30 and ord(m_message[7 : 8]) <= 0x39):
		getAiMode(m_message)
		return

	elif (m_message.startswith('+CTGS:')): # CTGS
		handleCtgs(m_message)
		return

	elif (m_message.startswith('+CTDGR:')): # CTDGR
		handleCtdgr(m_message)
		return

	elif (m_message.startswith('+CLVL:')): # CLVL
		handleClvl(m_message)
		return

	elif (m_message.startswith('INVALID')):
		if (settings.debug >= defs.LOGWARN):
			print('+++ Pei answer not known, ignoring ;')
		return

	else:
		if (settings.debug >= defs.LOGWARN):
			print('Uknown Command m_message = ' + m_message)
			print('	Len(m_message) = ' + str(len(m_message)))
			OpCode = m_message.split(':')[0]
			#print('	OpCode ' + OpCode
			Data = m_message.split(':', 1)[-1]
			#print('	Data ' + Data
		return

	if (peirequest == defs.INIT and (response == defs.OK or response == defs.ERROR)):
		initPei()
	return

###############################################################################
def initGroupCall(gc_gssi):

	tetra.inTransmission = True
	cmd = 'AT+CTSDC=0,0,0,1,1,0,1,1,0,0,0'
	sendPei(cmd)
	cmd = 'ATD' + str(gc_gssi)
	sendPei(cmd)
	ss = 'Init groupcall to GSSI: ' + str(gc_gssi)
	print(ss)
	return

###############################################################################
# TETRA Incoming Call Notification +CTICN
# +CTICN: <CC instance >, <call status>, <AI service>,
# [<calling party identity type>], [<calling party identity>],
# [<hook>], [<simplex>], [<end to end encryption>],
# [<comms type>], [<slots/codec>], [<called party identity type>],
# [<called party identity>], [<priority level>]
#  Example:        MCC| MNC| ISSI  |             MCC| MNC|  GSSI |
#  +CTICN: 1,0,0,5,09011638300023404,1,1,0,1,1,5,09011638300000001,0
#  OR               ISSI             GSSI
#  +CTICN: 1,0,0,5,23404,1,1,0,1,1,5,1000,0
def handleCallBegin(message):
	squelchOpen(True) # open the Squelch

	t_ci = C_Callinfo()

	message = message.replace('+CTICN: ', '')
	h = message.split(',')

	# split the message received from the Pei into single parameters
	# for further use, not all of them are interesting
	t_ci.instance = h[0]
	t_ci.callstatus = h[1]
	t_ci.aistatus = h[2]
	t_ci.origin_cpit = h[3]
	
	if (settings.debug >= defs.LOGDEBUG2):
		print('	t_ci.instance = ' + str(t_ci.instance))
		print('	t_ci.callstatus = ' + str(t_ci.callstatus))
		print('	t_ci.aistatus = ' + str(t_ci.aistatus))
		print('	t_ci.origin_cpit = ' + str(t_ci.origin_cpit))

	o_tsi = h[4]
	if (len(o_tsi) < 9):
		if (settings.debug >= defs.LOGDEBUG):
			print('o_tsi ' + d_tsi)
		t_ci.o_issi = str(o_tsi)
		t = tetra.mcc
		t += tetra.mnc
		t += getISSI(o_tsi)
		o_tsi = t
		t_ci.o_mnc = dmnc
		t_ci.o_mcc = dmcc
		if (settings.debug >= defs.LOGDEBUG1):
			print('	t_ci.o_mcc = ' + str(t_ci.o_mcc))
			print('	t_ci.o_mnc = ' + str(t_ci.o_mnc))
			print('	t_ci.o_issi = ' + str(t_ci.o_issi))
	else:
		#splitTsi(o_tsi, t_ci.o_mcc, t_ci.o_mnc, t_ci.o_issi);
		t_ci.o_mcc = int(o_tsi[0:4])
		t_ci.o_mnc = int(o_tsi[4:9])
		t_ci.o_issi = int(o_tsi[9:17])
		if (settings.debug >= defs.LOGDEBUG1):
			print('	t_ci.o_mcc = ' + str(t_ci.o_mcc))
			print('	t_ci.o_mnc = ' + str(t_ci.o_mnc))
			print('	t_ci.o_issi = ' + str(t_ci.o_issi))

	t_ci.hook = h[5]
	t_ci.simplex = h[6]
	t_ci.e2eencryption = h[7]
	t_ci.commstype = h[8]
	t_ci.codec = h[9]
	t_ci.dest_cpit = h[10]
	if (settings.debug >= defs.LOGDEBUG2):
		print('	t_ci.hook = ' + str(t_ci.hook))
		print('	t_ci.simplex = ' + str(t_ci.simplex))
		print('	t_ci.e2eencryption = ' + str(t_ci.e2eencryption))
		print('	t_ci.commstype = ' + str(t_ci.commstype))
		print('	t_ci.codec = ' + str(t_ci.codec))
		print('	t_ci.dest_cpit = ' + str(t_ci.dest_cpit))

	d_tsi = str(h[11])
	if (len(d_tsi) < 9):
		print('d_tsi ' + d_tsi)
		#t_ci.d_issi = atoi(d_tsi.c_str());
		t = mcc
		t += mnc
		t += getISSI(d_tsi)
		d_tsi = t
		t_ci.d_mnc = dmnc
		t_ci.d_mcc = dmcc
		t_ci.d_mcc = int(d_tsi[0:4])
		if (settings.debug >= defs.LOGDEBUG1):
			print('	t_ci.d_mcc = ' + str(t_ci.d_mcc))
			print('	t_ci.d_mnc = ' + str(t_ci.d_mnc))
			print('	t_ci.d_issi = ' + str(t_ci.d_issi))
	else:
		#splitTsi(d_tsi, t_ci.d_mcc, t_ci.d_mnc, t_ci.d_issi)
		t_ci.d_mcc = int(d_tsi[0:4])
		t_ci.d_mnc = int(d_tsi[4:9])
		t_ci.d_issi = int(d_tsi[9:17])
		if (settings.debug >= defs.LOGDEBUG1):
			print('	t_ci.d_mcc = ' + str(t_ci.d_mcc))
			print('	t_ci.d_mnc = ' + str(t_ci.d_mnc))
			print('	t_ci.d_issi = ' + str(t_ci.d_issi))

	t_ci.prio = str(h[12])

	# store call specific data into a Callinfo struct
#	callinfo[t_ci.instance] = t_ci;

	# check if the user is stored? no -> default
#	std::map<std::string, User>::iterator iu = userdata.find(o_tsi);
#	if (iu == userdata.end()):
#		t_sds = C_Sds()
#		t_sds.direction = defs.OUTGOING
#		t_sds.message = infosds
#		t_sds.tsi = o_tsi
#		t_sds._type = TEXT
#		firstContact(t_sds)
#		return

#	userdata[o_tsi].last_activity = time.time();

	# store info in Qso struct
	Qso.tsi = o_tsi;
	Qso.start = time.time()

	# prepare event for tetra users to be send over the network
#	Json::Value qsoinfo(Json::objectValue);

#	qsoinfo["qso_active"] = True
#	qsoinfo["gateway"] = callsign()
#	qsoinfo["dest_mcc"] = t_ci.d_mcc
#	qsoinfo["dest_mnc"] = t_ci.d_mnc
#	qsoinfo["dest_issi"] = t_ci.d_issi
#	qsoinfo["aimode"] = t_ci.aistatus
#	qsoinfo["cci"] = t_ci.instance
#	ti = time.time()
#	qsoinfo["last_activity"] = ti

#	std::list<std::string>::iterator it
#	it = find(Qso.members.begin(), Qso.members.end(), iu->second.call)
#	if (it == Qso.members.end()):
#		Qso.members.push_back(iu->second.call)

#	qsoinfo["qso_members"] = joinList(Qso.members)
#	publishInfo("QsoInfo:state", qsoinfo)
	# end of publish messages

	ss = 'groupcall_begin ' + str(t_ci.o_issi) + ' to ' + str(t_ci.d_issi)
	print(ss)

#	m_aprsmesg = aprs.path + ">" + iu->second.call + " initiated groupcall: " + t_ci.o_issi + " -> " + t_ci.d_issi
#	sendAPRS(iu->second.call, str(m_aprsmesg)
	return

###############################################################################
# TETRA SDS Receive +CTSDSR
# CTSDSR unsolicited Result Codes
# +CTSDSR: <AI service>, [<calling party identity>],
# [<calling party identity type>], <called party identity>,
# <called party identity type>, <length>,
# [<end to end encryption>]<CR><LF>user data
# Example:
# +CTSDSR: 12,23404,0,23401,0,112
# (82040801476A61746A616A676A61)
def handleSds(m_message): # From PEI:+CTSDSR: 12,1148920,0,9999,0,84
	m_message = m_message.replace('+CTSDSR: ', '')
	value = m_message.split(',')

	# store header of sds for further handling
	pSDS.aiservice = value[0]						# type of SDS (TypeOfService 0-12)
	#pSDS.fromtsi = getTSI(Value[1])				# sender Tsi (23404)
	pSDS.fromtsi = value[1]							# sender Tsi (23404)
	pass											# (0)
	#pSDS.totsi = getTSI(Value[3])					# destination Issi
	pSDS.totsi = value[3]							# destination Issi
	pass											# (0)
	pass											# Sds length (112)
	pSDS.last_activity = time.time()
	return

###############################################################################
def firstContact(tsds):
#	userdata[tsds.tsi].call = "NoCall"
#	userdata[tsds.tsi].name = "NoName"
#	userdata[tsds.tsi].aprs_sym = t_aprs_sym
#	userdata[tsds.tsi].aprs_tab = t_aprs_tab
#	userdata[tsds.tsi].last_activity = time.time()

	if (len(infosds) > 0):
		tsds.direction = OUTGOING
		tsds.message = infosds
		tsds._type = TEXT
		tsds.remark = "Welcome Sds to a new user"
		if (settings.debug >= defs.LOGINFO):
			print("Sending info Sds to new user " + tsds.tsi + " \"" + infosds + "\"")
#		queueSds(tsds)

###############################################################################
# Handle the sds message
# Example:
# (+CTSDSR: 12,23404,0,23401,0,112)
# 82040801476A61746A616A676A61
def handleSdsMsg(sds):
	t_sds = C_Sds()
	lipinfo = LipInfo()

	t_sds.tos = pSDS.last_activity # last activity
	t_sds.direction = defs.INCOMING # 1 = received
	t_sds.tsi = pSDS.fromtsi

#	if (iu == userdata.end()):
#		firstContact(t_sds)

	# update last activity of sender
#	userdata[t_sds.tsi].last_activity = time.time()

	#m_sdstype = defs.handleMessage(sds)
	#t_sds._type = m_sdstype
	if (	sds[0 : 2] == '0A' and # LIP_SDS
			(ord(sds[2 : 3]) >= 0x30 and ord(sds[2 : 3]) <= 0x39 or
			ord(sds[2 : 3]) >= 0x41 and ord(sds[2 : 3]) <= 0x46) and
			(ord(sds[3 : 4]) >= 0x30 and ord(sds[3 : 4]) <= 0x39 or
			ord(sds[3 : 4]) >= 0x41 and ord(sds[3 : 4]) <= 0x46) and
			(ord(sds[4 : 5]) >= 0x30 and ord(sds[4 : 5]) <= 0x39 or
			ord(sds[4 : 5]) >= 0x41 and ord(sds[4 : 5]) <= 0x46) and
			(ord(sds[5 : 6]) >= 0x30 and ord(sds[5 : 6]) <= 0x39 or
			ord(sds[5 : 6]) >= 0x41 and ord(sds[5 : 6]) <= 0x46) and
			(ord(sds[6 : 7]) >= 0x30 and ord(sds[6 : 7]) <= 0x39 or
			ord(sds[6 : 7]) >= 0x41 and ord(sds[6 : 7]) <= 0x46) and
			(ord(sds[7 : 8]) >= 0x30 and ord(sds[7 : 8]) <= 0x39 or
			ord(sds[7 : 8]) >= 0x41 and ord(sds[7 : 8]) <= 0x46) and
			(ord(sds[8 : 9]) >= 0x30 and ord(sds[8 : 9]) <= 0x39 or
			ord(sds[8 : 9]) >= 0x41 and ord(sds[8 : 9]) <= 0x46) and
			(ord(sds[9 : 10]) >= 0x30 and ord(sds[9 : 10]) <= 0x39 or
			ord(sds[9 : 10]) >= 0x41 and ord(sds[9 : 10]) <= 0x46) and
			(ord(sds[10 : 11]) >= 0x30 and ord(sds[10 : 11]) <= 0x39 or
			ord(sds[10 : 11]) >= 0x41 and ord(sds[10 : 11]) <= 0x46) and
			(ord(sds[11 : 12]) >= 0x30 and ord(sds[11 : 12]) <= 0x39 or
			ord(sds[11 : 12]) >= 0x41 and ord(sds[11 : 12]) <= 0x46) and
			(ord(sds[12 : 13]) >= 0x30 and ord(sds[12 : 13]) <= 0x39 or
			ord(sds[12 : 13]) >= 0x41 and ord(sds[12 : 13]) <= 0x46) and
			(ord(sds[13 : 14]) >= 0x30 and ord(sds[13 : 14]) <= 0x39 or
			ord(sds[13 : 14]) >= 0x41 and ord(sds[13 : 14]) <= 0x46) ):

		# From PEI:0A0B97ED68DC8712FFE820
		# To APRS:APRS,qAR,XE1F-10:!1922.94N-09908.82W1Carlos, XE1F (Tetra Mexico DMO)

#		handleLipSds(sds, lipinfo)
#		m_aprsinfo = "!" + dec2nmea_lat(lipinfo.latitude) +
#			iu->second.aprs_sym + dec2nmea_lon(lipinfo.longitude)# +
#			iu->second.aprs_tab + iu->second.name + ", " +
#			iu->second.comment
		ss = "lip_sds_received " + t_sds.tsi + " "
		ss += str(lipinfo.latitude) + " " + str(lipinfo.longitude)
		print(ss)
#		userdata[t_sds.tsi].lat = lipinfo.latitude
#		userdata[t_sds.tsi].lon = lipinfo.longitude
#		userdata[t_sds.tsi].reasonforsending = lipinfo.reasonforsending

		# Power-On -> send welcome sds to a new station
		sendWelcomeSds(t_sds.tsi, lipinfo.reasonforsending)

		# send an info sds to all other stations that somebody is in vicinity
		# sendInfoSds(tsi of new station, readonofsending);
		sendInfoSds(t_sds.tsi, lipinfo.reasonforsending)

		# calculate distance RPT<->MS
		sstcl = "distance_rpt_ms " + t_sds.tsi + " "
		sstcl += str(calcDistance(settings.Latitude, settings.Longitude, lipinfo.latitude, lipinfo.longitude))
		sstcl += " "
		sstcl += str(calcBearing(settings.Latitude, settings.Longitude, lipinfo.latitude, lipinfo.longitude))
#		processEvent(str(sstcl))

#		sdsinfo["lat"] = lipinfo.latitude
#		sdsinfo["lon"] = lipinfo.longitude
#		sdsinfo["reasonforsending"] = lipinfo.reasonforsending
		return

	#elif (sds[0 : 7] == '[8-9A-F [0-9A-F {3}$'): # STATE_SDS
	elif (	len(sds) == 4 and # STATE_SDS
			(ord(sds[0 : 1]) >= 0x38 and ord(sds[0 : 1]) <= 0x39) and
			(ord(sds[1 : 2]) >= 0x30 and ord(sds[1 : 2]) <= 0x39 or
			ord(sds[1 : 2]) >= 0x41 and ord(sds[1 : 2]) <= 0x46) and
			(ord(sds[2 : 3]) >= 0x30 and ord(sds[2 : 3]) <= 0x39 or
			ord(sds[2 : 3]) >= 0x41 and ord(sds[2 : 3]) <= 0x46) and
			(ord(sds[3 : 4]) >= 0x30 and ord(sds[3 : 4]) <= 0x39 or
			ord(sds[3 : 4]) >= 0x41 and ord(sds[3 : 4]) <= 0x46) ):
		isds = int(sds, 16) # hex2int
		handleStateSds(isds)
#		userdata[t_sds.tsi].state = isds
		m_aprsinfo = ">" + "State:"
#		if ((it = state_sds.find(isds)) != state_sds.end())
#			m_aprsinfo += it->second
		m_aprsinfo += " (" + str(isds) + ")"

		ss = "state_sds_received " + str(t_sds.tsi) + " " + str(isds)
		print(ss)
#		sdsinfo["state"] = isds;
		return

	elif (sds[0 : 1] == '8'): # TEXT_SDS
		sds_txt = handleTextSds(sds)
		cfmTxtSdsReceived(sds, t_sds.tsi)
		ss = "text_sds_received " + t_sds.tsi + " \"" + sds_txt + "\""
		print(ss)
		if ( not checkIfDapmessage(sds_txt)):
			m_aprsinfo = ">" + sds_txt
#		sdsinfo["content"] = sds_txt
		return

	elif (sds[0 : 2] == '02'): # SIMPLE_TEXT_SDS
		sds_txt = handleSimpleTextSds(sds)
		m_aprsinfo = ">" + sds_txt
		cfmSdsReceived(t_sds.tsi)
		ss = "text_sds_received " + t_sds.tsi + " \"" + sds_txt + "\""
		print(ss)
		return

	elif (sds[0 : 4] == '8210'): # ACK_SDS
		# +CTSDSR: 12,23404,0,23401,0,32
		# 82100002
		# sds msg received by MS from remote
		t_sds.tod = time.time()
		sds_txt = handleAckSds(sds, t_sds.tsi)
		m_aprsinfo = '>ACK'
		ss = 'sds_received_ack ' + sds_txt
		print(ss)
		return
		
	elif (sds[0 : 4] == '8210'): # REGISTER_TSI
		ss = 'register_tsi ' + t_sds.tsi
		print(ss)
		cfmSdsReceived(t_sds.tsi);
		return

	elif (sds[0 : 7] == 'INVALID'):
		ss = 'unknown_sds_received'
		print(ss)
		if (settings.debug >= defs.LOGWARN):
			print('*** Unknown type of SDS')
		return

	else:
		if (settings.debug >= defs.LOGWARN):
			print('*** Unknown type of SDS = ' + sds)
			#print('	Len(sds) = ' + str(len(sds)))
		return

	ti = time.time()
#	sdsinfo["last_activity"] = ti
#	sdsinfo["sendertsi"] = t_sds.tsi
#	sdsinfo["type"] = m_sdstype
#	sdsinfo["from"] = userdata[t_sds.tsi].call
#	sdsinfo["to"] = userdata[pSDS.totsi].call
#	sdsinfo["receivertsi"] = pSDS.totsi
#	sdsinfo["gateway"] = callsign()
#	event.append(sdsinfo)
#	publishInfo("Sds:info", event)

	# send sds info of a user to aprs network
	if (len(m_aprsinfo) > 0):
		m_aprsmessage = tetra.aprspath
		m_aprsmessage += str(m_aprsinfo)
#		sendAprs(userdata[t_sds.tsi].call, m_aprsmessage)

	if (len(ss) > 0):
		print(ss)
#		processEvent(ss.str())

	return

###############################################################################
# 6.15.6 TETRA Group Set up
# +CTGS [<group type>], <called party identity> ... [,[<group type>], 
#       < called party identity>]
# In V+D group type shall be used. In DMO the group type may be omitted,
# as it will be ignored.
# PEI: +CTGS: 1,09011638300000001
def handleCtgs(m_message):
	message = message.replace('+CTGS: ', '')
	return m_message

###############################################################################
# 6.14.10 TETRA DMO visible gateways/repeaters
# * +CTDGR: [<DM communication type>], [<gateway/repeater address>], [<MNI>],
# *         [<presence information>]
# * TETRA DMO visible gateways/repeaters +CTDGR
# * +CTDGR: 2,1001,90116383,0
def handleCtdgr(m_message):
	m_message = m_message[8 : len(m_message) - 8] # delete 00A3xxxx

	value = m_message.split(',')
	n = len(value)
	
	drp = DmoRpt()
#	struct tm mtime = {0}

	if (n == 3):
		dmct = value[0]
		drp.issi =  value[1]
		drp.mni =  value[2]
		drp.state =  value[3]
#		drp.last_activity = mktime(&mtime);

		ssret = "INFO: Station " + TransientComType[dmct] + " detected (ISSI="
		ssret += drp.issi + ", MNI=" + drp.mni + ", state=" + drp.state + ")"

		dmo_rep_gw.emplace(drp.issi, drp)

		ss = "dmo_gw_rpt " + dmct + " " + drp.issi + " " + drp.mni + " "
		ss += drp.state
		print(ss)
#		processEvent(ss.str())

	return str(ssret)

###############################################################################
def handleClvl(m_message):
	m_message = m_message.replace('+CLVL: ', '')
	audio_level = m_message.split(',')
	ss = 'audio_level ' + audio_level[0]
	print(ss)
#	processEvent(ss.str())
	return

###############################################################################
# CMGS Set and Unsolicited Result Code Text
# The set result code only indicates delivery to the MT. In addition to the 
# normal <OK> it contains a message reference <SDS instance>, which can be 
# used to identify message upon unsolicited delivery status report result 
# codes. For SDS-TL messages the SDS-TL message reference is returned. The 
# unsolicited result code can be used to indicate later transmission over 
# the air interface or the sending has failed.
# +CMGS: <SDS Instance>, [<SDS status>], [<message reference>]
# +CMGS: 0,4,65 <- decimal
# +CMGS: 0
def handleCmgs(m_message):
	m_message = m_message.replace('+CMGS: ', '')
	Val = m_message.split(',')
	sds_inst = Val[0]
	state = Val[1]
	id_ = Val[2]

	if (last_sdsinstance == defs.sds_inst):
		if (state == defs.SDS_SEND_FAILED):
			if (settings.debug >= defs.LOGERROR):
				print('*** ERROR: Send message failed. Will send again...')
			pending_sds.tos = 0
		elif (state == defs.SDS_SEND_OK):
			if (settings.debug >= defs.LOGINFO):
				print('+++ Message sent OK, #' + id_)
			cmgs_received = True
	cmgs_received = True
	last_sdsinstance = defs.sds_inst
	checkSds()
	return

###############################################################################
def handleTextSds(m_message):
	if (len(m_message) > 8):
		m_message = m_message[8 : len(m_message) - 8] # delete 00A3xxxx
	return decodeSDS(m_message)

###############################################################################
def handleAckSds(m_message, tsi):
	t_msg = tsi
	return t_msg

###############################################################################
def handleSimpleTextSds(m_message):
	if (len(m_message) > 4):
		m_message = m_message[4 : len(m_message) - 4] # delete 0201
	return decodeSDS(m_message);

###############################################################################
# 6.15.10 Transmission Grant +CTXG
# +CTXG: <CC instance>, <TxGrant>, <TxRqPrmsn>, <end to end encryption>,
#        [<TPI type>], [<TPI>]
# e.g.:
# +CTXG: 1,3,0,0,3,09011638300023404
def handleTxGrant(txgrant):
	squelchOpen(True) # open Squelch
	print('tx_grant')

###############################################################################
def getTSI(issi):
#	char is[18];
	length = len(issi)
#	int t_mcc;
#	std::string t_issi;

	if (len < 9):
#		sprintf(is, '%08d', atoi(issi.c_str()));
		ss = mcc + mnc + _is
		return str(ss)

	# get MCC (3 or 4 digits)
#	if (issi[0:1] == '0'):
#		t_mcc = atoi(issi.substr(0,4).c_str());
#		issi.erase(0,4);
#	else:
#		t_mcc = atoi(issi.substr(0,3).c_str());
#		issi.erase(0,3);

	# get ISSI (8 digits)
	t_issi = issi[length - 8,8]
#	issi.erase(len-8,8);

#	sprintf(is, '%04d%05d%s', t_mcc, atoi(issi.c_str()), t_issi.c_str());
#	ss << is;

	return str(ss)

###############################################################################
def handleStateSds(isds):
#	stringstream ss;

	if (settings.debug >= defs.LOGINFO):
		print('+++ State Sds received: ' + str(isds))

#	std::map<unsigned int, string>::iterator it = sds_to_command.find(isds);

#	if (it != sds_to_command.end())
		# to connect/disconnect Links
#		ss << it->second << '#';
#		injectDtmf(ss.str(), 10);

#	it = state_sds.find(isds);
#	if (it != state_sds.end())
		# process macro, if defined
#		ss << 'D' << isds << '#';
#		injectDtmf(ss.str(), 10);

###############################################################################
# 6.15.11 Down Transmission Ceased +CDTXC
# * +CDTXC: <CC instance>, <TxRqPrmsn>
# * +CDTXC: 1,0
def handleTransmissionEnd(message):
	squelchOpen(False)
	ss = 'groupcall_end'
	print(ss)
	return
	
###############################################################################
# 6.15.3 TETRA Call ReleaseTETRA Call Release
# +CTCR: <CC instance >, <disconnect cause>
# +CTCR: 1,13
def handleCallReleased(message):
	Qso.stop = time.time()
	message = message.replace('+CTCR: ', '')
	Val = message.split(',')
	cci = int(Val[0])
	if (tetra.tetra_modem_sql == True):
		squelchOpen(False) # close Squelch
		ss = 'out_of_range ' + str(int(Val[1]))
	else:
		ss = 'call_end ' + defs.DisconnectCause[Val[1]]
	print(ss)

	# send call/qso end to aprs network
	m_aprsmesg = tetra.aprspath
#	if (!Qso.members.empty()):
#		m_aprsmesg += ">Qso ended ("
#		m_aprsmesg += joinList(Qso.members)
#		m_aprsmesg += ")"


		# prepare event for tetra users to be send over the network
#		Json::Value qsoinfo(Json::objectValue)

#		ti = time.time()
#		qsoinfo["last_activity"] = ti
#		qsoinfo["qso_active"] = False
#		qsoinfo["qso_members"] = joinList(Qso.members)
#		qsoinfo["gateway"] = callsign()
#		qsoinfo["cci"] = cci
#		qsoinfo["aimode"] = callinfo[cci].aistatus
#		qsoinfo["dest_mcc"] = callinfo[cci].d_mcc
#		qsoinfo["dest_mnc"] = callinfo[cci].d_mn;
#		qsoinfo["dest_issi"] = callinfo[cci].d_issi
#		publishInfo("QsoInfo:state", qsoinfo)
#	else:
#		m_aprsmesg += ">Transmission ended"
#	sendAprs(userdata[Qso.tsi].call, m_aprsmesg)

	tetra.talkgroup_up = False
#	Qso.members.clear()
	tetra.inTransmission = False
#	checkSds() # resend Sds after MS got into Rx mode
	return


###############################################################################
def joinList(members):
#	for (const auto &it : members):
#		qi += it
#		qi += ","
#	return qi.substr(0,qi.length()-1);
	pass

###############################################################################
def sendPei(cmd):
	# a sdsmsg must end with 0x1a
	#if (ord(cmd[-1:]) != 0x0A):
		#cmd += chr(0x0A)

	cmd = cmd + chr(0x0D) + chr(0x0A)#'\r\n'
	#print('len(cmd) = ' + str(len(cmd)))

	arr = [ord(cmd[0 : 1])]
	arr.clear()
	for x in cmd:
		#print (str(x))
		arr.append(ord(x))
	tetra.pei.write(arr)
#	if (settings.debug >= defs.LOGDEBUG):
#		print('  To PEI:' + str(cmd))
#		print('     RAW:' + str(arr))
	return

###############################################################################
def onPeiActivityTimeout():
	sendPei('AT')
	tetra.peirequest = defs.CHECK_AT
	return

###############################################################################
# Create a confirmation sds and sends them to the Tetra radio
def cfmSdsReceived(tsi):
	msg("OK")
	t_sds = Sds()
	t_sds.message = msg
	t_sds.tsi = tsi
	t_sds.direction = OUTGOING
	queueSds(t_sds)
	return

###############################################################################
# +CTSDSR: 12,23404,0,23401,0,96, 82041D014164676A6D707477 */
def cfmTxtSdsReceived( message, tsi):
	if (len(message) < 8):
		return
	_id = message[4:2]
	msg("821000") # confirm a sds received
	msg += _id

	if (settings.debug >= defs.LOGINFO):
		print("+++ sending confirmation Sds to " + tsi)

	t_sds = Sds()
	t_sds.message = msg
	t_sds._id = int(_id, 16) # hex2int
	t_sds.remark = "confirmation Sds"
	t_sds.tsi = tsi
	t_sds._type = defs.ACK_SDS
	t_sds.direction = defs.OUTGOING
#	queueSds(t_sds)

###############################################################################
def handleCnumf(m_message):
	print('PEI:Rx +CNUMF: ')
	print('	m_message = ' + m_message)
	m_message = m_message.replace('+CNUMF: ', '')
	Value = m_message.split(',') # Create an array separating values by ','

	#e.g. +CNUMF: 6,09011638300023401
	m_numtype = int(Value[0])
	if (settings.debug >= defs.LOGINFO):
		print('<num type> is ' + str(m_numtype))

	if (m_numtype == 6 or m_numtype == 0):
		# get the tsi and split it into mcc,mnc,issi
		#splitTsi(m_message, t_mcc, t_mnc, t_issi);
		tsi = Value[1]
		t_mcc = int(tsi[0:4])
		t_mnc = int(tsi[4:9])
		t_issi = int(tsi[9:17])
		print('	t_mcc = ' + str(t_mcc))
		print('	t_mnc = ' + str(t_mnc))
		print('	t_issi = ' + str(t_issi))

	tetra.dmcc = t_mcc
	tetra.dmnc = t_mnc

	tetra.peirequest = defs.INIT_COMPLETE
	return

###############################################################################
def sendInfoSds(tsi, reason):

	return







###############################################################################
def getAiMode(aimode):
	if (len(aimode) > 6):
#		t = atoi(aimode.erase(0,6).c_str());
		if (settings.debug >= defs.LOGINFO):
			print('+++ New Tetra mode: ' + AiMode[t])
		print('tetra_mode ' + t)
	return

###############################################################################
def queueSds(t_sds):
	
	return

###############################################################################
def checkSds():

	return

###############################################################################
def sendWelcomeSds(tsi, r4s):

#	std::map<int, string>::iterator oa = sds_on_activity.find(r4s);

	# send welcome sds to new station, if defined	
#	if (oa != sds_on_activity.end())
	t_sds = C_Sds()
	t_sds.direction = defs.OUTGOING
	t_sds.tsi = tsi
	t_sds.remark = "welcome sds"
	t_sds.message = 'Testing PNG' # oa->second

	if (settings.debug >= defs.LOGINFO):
		print('Send SDS:' + str(t_sds.tsi) + ', ' + t_sds.message)
#	queueSds(t_sds)
	return

	
	
	

###############################################################################
def splitTsi(tsi, mcc, mnc, issi):
	print('splitTsi' + tsi)
	ret = False
	length = len(tsi)
	print('len(tsi) = ' + str(length))

	mcc = int(tsi[0:4])
	mnc = int(tsi[4:9])
	issi = int(tsi[9:17])
	return

###############################################################################
# @param: a message, e.g. +CTCC: 1,1,1,0,0,1,1
# * @return: the current caller identifier
def handleCci(m_message):
	m_message = m_message.replace('+CTCC: ', '')
	Val = m_message.split(',')
	print('handleCci ' + Val[0])
	return Val[0]

###############################################################################
def sendAprs(call, aprsmessage):
	# send group info to aprs network
#	if (LocationInfo::has_instance())
#		if (settings.debug >= defs.LOGINFO):
#			print(" To APRS:" + aprsmessage)
#		LocationInfo::instance()->update3rdState(call, aprsmessage)
	pass



###############################################################################
def pei_Timer(): # PEI keep alive.
	if (time.time() >= tetra.pei_NextTimer):
		if (settings.debug >= defs.LOGDEBUG):
			print("PEI_Timer event " + str(time.time()))
		if (tetra.pei_TimerEnabled):
			# Call your functions here:
			onPeiActivityTimeout()

			if (settings.debug >= defs.LOGDEBUG):
				print("----------------------------------------------------------------------")
		tetra.pei_NextTimer = time.time() + tetra.pei_TimerInterval















###############################################################################
# TetraLib.h ################################################################
###############################################################################
def calcDistance(lat1, lon1, lat2, lon2):
	dlon = math.pi * (lon2 - lon1) / 180.0
	dlat = math.pi * (lat2 - lat1) / 180.0

	a = (math.sin(dlat / 2) * math.sin(dlat / 2)) + math.cos(math.pi*lat1/180.0) * math.cos(math.pi*lat2/180) * (math.sin(dlon / 2) * math.sin(dlon / 2))
	angle = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
	return float(int(angle * defs.RADIUS * 100.0)) / 100.0
	
###############################################################################
def calcBearing(lat1, lon1, lat2, lon2):
	teta1 = math.radians(lat1)
	teta2 = math.radians(lat2)
	delta2 = math.radians(lon2-lon1)

	y = math.sin(delta2) * math.cos(teta2)
	x = math.cos(teta1) * math.sin(teta2) - math.sin(teta1) * math.cos(teta2) * math.cos(delta2)
	br = math.fmod(math.degrees(math.atan2(y,x)) + 360.0, 360.0)
	return float(int(br * 10.0)) / 10.0

###############################################################################
def getPeiError(Error):
	print(' +CME ERROR: ' + defs.peiError[Error])
	return

###############################################################################
def getISSI(tsi): # return the ISSI as part of the TEI
	length = len(tsi)
	if (length < 8):
		t_issi = '00000000' + tsi
		return str(t_issi[length - 8 : 8])
	t_issi = tsi[length - 8 : 8]
	return str(t_issi)







###############################################################################
# TetraLogic.h ################################################################
###############################################################################
def setSql(is_open):
#	setSignalDetected(is_open)
	return











###############################################################################
# Misc Subs ###################################################################
###############################################################################
def helpMenu():
	print("----------------------------------------------------------------------")
	print('Shortcuts menu:')
	print('  Q/q = Quit.                      H/h = Help..')
	print('  A/a = APRS  show/hide verbose.          ')
	print('  I/i = ID                         J/j = ID    show/hide verbose.')
	print('  P/p = PTT   Enable/Disable PTT.  T/t = Test.')
	print("----------------------------------------------------------------------")





###############################################################################
# Hot Keys
###############################################################################
def HotKeys():
	global Run
	if kb.kbhit():
		c = kb.getch()
		if ord(c) == 27: # Esc
			print('Esc key pressed.')
			Run = False

		elif c == 'a': # AT Command
			print('a key pressed.')
			aprs_is_Tx('XE1F-7', 'XE1F-7>APRS:>Hello TETRA World!')
		elif c == 'H': # Help
			helpMenu()
		elif c == 'h': # Help
			helpMenu()
		elif c == 'q': # Quit
			print('q key pressed.')
			Run = False
		elif c == 'P': # AT Command
			print('P key pressed.')
			transmitterStateChange(True)
		elif c == 'p': # AT Command
			print('p key pressed.')
			transmitterStateChange(False)
		elif c == 't': # AT Command
			print('t key pressed.')
			sendPei('AT')
		else :
			#print('HotKey ' + c)
			pass
			
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
	if (channel == settings.PTT_GPIO):
		PTT = GPIO.input(settings.PTT_GPIO)
		print('PTT_GPIO = ' + PTT)



###############################################################################
# APRS
###############################################################################
def aprs_Init():
	aprs.path = "APRS,qAR,"
	aprs.path += callsign()
	aprs.path += "-10:"
	if (len(aprs.symbol) != 2):
		aprs.symbol = DEFAULT_APRS_ICON



#def p(x): print(x)
#	a = aprs.TCP('W2GMD', '12345')
#	a.start()

#	a.receive(callback=p)



def aprs_is_Tx(des_callsign, frame):
	#frame = aprs.parse_frame('XE1F-7>APRS:>Hello TETRA World!')
	aprs_is = aprs.TCP(b'{settings.Callsign}', b'{settings.Passcode}')
	aprs_is.start()

	aprs_is.send(frame)








if __name__ == '__main__':
	try:
		main()
	except KeyboardInterrupt:
		pass