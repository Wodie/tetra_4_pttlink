PROGRAM = 'TETRA 4 PTTLink'
DESCRIPTION = 'SQL script to interface TETRA with PTTLink'



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
LOGDEBUG1 = 4
LOGDEBUG2 = 5
LOGDEBUG3 = 6

TETRA_LOGIC_VERSION = '19122021'

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

# AI Service
# This parameter is used to determine the type of service to be used
# in air interface call set up signalling. The services are all
# defined in EN 300 392-2 [3] or EN 300 396-3 [25].
TETRA_SPEECH=0
UNPROTECTED_DATA=1
PACKET_DATA=8
SDS_TYPE1=9
SDS_TYPE2=10
SDS_TYPE3=11
SDS_TYPE4=12
STATUS_SDS=13

# direction of Sds
OUTGOING = 0
INCOMING = 1

# type of Sds
STATE = 0
TEXT = 1
LIP_SHORT = 2
COMPLEX_SDS_TL = 3
RAW = 4

# Sds sent state
SDS_SEND_OK = 4
SDS_SEND_FAILED = 5


RadioID_URL = 'https://database.radioid.net/api/dmr/'



m_message = {
	'AT' : 'AT',
	'^OK' : 'OK',
	'^\\+CME ERROR' : 'ERROR',
	'^\\+CTSDSR:' : 'SDS',
	'^\\+CTICN:' : 'CALL_BEGIN',
	'^\\+CTCR:' : 'CALL_RELEASED',
	'^\\+CTCC:' : 'CALL_CONNECT',
	'^\\+CDTXC:' : 'TRANSMISSION_END',
	'^\\+CTXG:' : 'TRANSMISSION_GRANT',
	'^\\+CTXD:' : 'TX_DEMAND',
	'^\\+CTXI:' : 'TX_INTERRUPT',
	'^\\+CTXW:' : 'TX_WAIT',
	'^\\+CNUM:' : 'MS_CNUM',
	'^\\+CTOM: [0-9 $' : 'OP_MODE',
	'^\\+CMGS:' : 'CMGS',
	'^\\+CNUMF:' : 'CNUMF',
	'^\\+CTGS:' : 'CTGS',
	'^\\+CTDGR:' : 'CTDGR',
	'^\\+CLVL:' : 'CLVL',
	'^01' : 'OTAK',
	'^02' : 'SIMPLE_TEXT_SDS',
	'^03' : 'SIMPLE_LIP_SDS',
	'^04' : 'WAP_PROTOCOL',
	'^0A[0-9A-F {19}' : 'LIP_SDS',
	'^[8-9A-F [0-9A-F {3}$' : 'STATE_SDS',
	'^8210[0-9A-F {4}' : 'ACK_SDS',
	'^8[23 [0-9A-F {3,}' : 'TEXT_SDS',
#	'^83' : 'LOCATION_SYSTEM_TSDU',
#	'^84' : 'WAP_MESSAGE',
	'^0C' : 'CONCAT_SDS',
}


m_cmds = {
	'1' : 'AT+CTOM:6,0',
	'2' : 'AT+CTSP:1,3,131',
	'3' : 'AT+CTSP:1,3,130',
	'4' : 'AT+CTSP:1,3,138',
	'5' : 'AT+CTSP:1,2,20',
	'6' : 'AT+CTSP:2,0,0',
	'7' : '+CTSP:1,3,24',
	'8' : '+CTSP:1,3,25',
	'9' : '+CTSP:1,3,3',
	'10' : '+CTSP:1,3,10',
	'11' : '+CTSP:1,1,11',
	'12' : '+CTSDC:0,0,0,1,1,0,1,1,0,0',
	'13' : '+CNUMF?'
}


peiError = {
	'0' : "0 - The MT was unable to send the data over the air (e.g. to the SwMI)",
	'1' : "1 - The MT can not establish a reliable communication with the TE",
	'2' : "2 - The PEI link of the MT is being used already",
	'3' : "3 - This is a general error report code which indicates that the MT supports\n the command but not in its current state. This code shall be used when no\n other code is more appropriate for the specific context",
	'4' : "4 - The MT does not support the command",
	'5' : "5 - The MT can not process any command until the PIN for the SIM is provided",
	'6' : "6 - Reserved",
	'7' : "7 - Reserved",
	'8' : "8 - Reserved",
	'9' : "9 - Reserved",
	'10' : "10 - The MT can not process the command due to the absence of a SIM",
	'11' : "11 - The SIM PIN1 is required for the MT to execute the command",
	'12' : "12 - MMI unblocking of the SIM PIN1 is required",
	'13' : "13 - The MT failed to access the SIM",
	'14' : "14 - The MT can not currently execute the command due to the SIM not being\n ready to proceed",
	'15' : "15 - The MT does not recognize this SIM",
	'16' : "16 - The entered PIN for the SIM is incorrect",
	'17' : "17 - The SIM PIN2 is required for the MT to execute the command",
	'18' : "18 - MMI unblocking of the SIM PIN2 is required",
	'19' : "19 - Reserved",
	'20' : "20 - The MT message stack is full",
	'21' : "21 - The requested message index in the message stack does not exist",
	'22' : "22 - The requested message index does not correspond to any message",
	'23' : "23 - The MT failed to store or access to its message stack",
	'24' : "24 - The text string associated with a status value is too long",
	'25' : "25 - The text string associated with a status value contains invalid characters",
	'26' : "26 - The <dial string> is longer than 25 digits",
	'27' : "27 - The <dial string> contains invalid characters",
	'28' : "28 - Reserved",
	'29' : "29 - Reserved",
	'30' : "30 - The MS is currently out of service and can not process the command",
	'31' : "31 - The MT did not receive any Layer 2 acknowledgement from the SwMI",
	'32' : "32 - <user data> decoding failed",
	'33' : "33 - At least one of the parameters is of the wrong type e.g. string instead\n of number or vice-versa",
	'34' : "34 - At least one of the supported parameters in the command is out of range",
	'35' : "35 - Syntax error. The syntax of the command is incorrect e.g. mandatory\n parameters are missing or are exceeding Data received without command",
	'36' : "36 - The MT received <user data> without AT+CMGS= ...<CR>",
	'37' : "37 - AT+CMGS command received, but timeout expired waiting for <userdata>",
	'38' : "38 - The TE has already registered the Protocol Identifier with the MT",
	'39' : "39 - Registration table in SDS-TL is full. The MT can no longer register\n a new Protocol Identifier until a registered Protocol identifier is\n deregistered",
	'40' : "40 - The MT supports the requested service but not while it is in DMO",
	'41' : "41 - The MT is in Transmit inhibit mode and is not able to process the\n command in this state",
	'42' : "42 - The MT is involved in a signalling activity and is not able to process\n the available command until the current transaction ends. In V+D,\n the signalling activity could be e.g. group attachment, group report, SDS\n processing, processing of DGNA, registration, authentication or any\n transaction requiring a response from the MS or the SwMI. In DMO, the\n signalling activity could be e.g. Call or SDS processing.",
	'43' : "43 - The MT supports the requested service but not while it is in V+D",
	'44' : "44 - The MT supports handling of unknown parameters",
	'45' : "45 - Reserved"
}




# TetraLib
RADIUS = 6378.16 # Earth radius

TxGrant = {
	'0' : "0 - Transmission granted",
	'1' : "1 - Transmission not granted",
	'2' : "2 - Transmission queued",
	'3' : "3 - Transmission granted to another"
}

CallStatus = {
	'0' : "0 - Call progressing",
	'1' : "1 - Call queued",
	'2' : "2 - Called party paged",
	'3' : "3 - Call continue",
	'4' : "4 - Hang time expired"
}

CalledPartyIdentityType = {
	'0' : "0 - SSI",
	'1' : "1 - TSI",
	'2' : "2 - SNA (V+D only)",
	'3' : "3 - PABX external subscriber number (V+D or DMO if via a gateway)",
	'4' : "4 - PSTN external subscriber number (V+D or DMO if via a gateway)",
	'5' : "5 - Extended TSI"
}

AiMode = {
	'0' : "0 - V+D (trunked mode operation)",
	'1' : "1 - DMO",
	'2' : "2 - V+D with dual watch of DMO",
	'3' : "3 - DMO with dual watch of V+D",
	'4' : "4 - V+D and DMO (used in conjunction CTSP command)",
	'5' : "5 - NN",
	'6' : "6 - DMO Repeater mode"
}

TxDemandPriority = {
	'0' : "0 - Low",
	'1' : "1 - High",
	'2' : "2 - Pre-emptive",
	'3' : "3 - Emergency"
}

TransientComType = {
	'0' : "0 - Voice + Data",
	'1' : "1 - DMO-Direct MS-MS",
	'2' : "2 - DMO-Via DM-REP",
	'3' : "3 - DMO-Via DM-GATE",
	'4' : "4 - DMO-Via DM-REP/GATE",
	'5' : "5 - Reserved",
	'6' : "6 - Direct MS-MS, but maintain gateway registration"
}

RegStat = {
	'0' : "0 - Registering or searching a network, one or more networks are available",
	'1' : "1 - Registered, home network",
	'2' : "2 - Not registered, no network currently available",
	'3' : "3 - System reject, no other network available",
	'4' : "4 - Unknown",
	'5' : "5 - Registered, visited network"
}

AiService = {
	'0' : "0 - TETRA speech",
	'1' : "1 - 7,2 kbit/s unprotected data",
	'2' : "2 - Low protection 4,8 kbit/s short interleaving depth = 1",
	'3' : "3 - Low protection 4,8 kbit/s medium interleaving depth = 4",
	'4' : "4 - Low protection 4,8 kbit/s long interleaving depth = 8",
	'5' : "5 - High protection 2,4 kbit/s short interleaving depth = 1",
	'6' : "6 - High protection 2,4 kbit/s medium interleaving depth = 4",
	'7' : "7 - High protection 2,4 kbit/s high interleaving depth = 8",
	'8' : "8 - Packet Data (V+D only)",
	'9' : "9 - SDS type 1 (16 bits)",
	'10' : "10 - SDS type 2 (32 bits)",
	'11' : "11 - SDS type 3 (64 bits)",
	'12' : "12 - SDS type 4 (0 - 2 047 bits)",
	'13' : "13 - Status (16 bits, some values are reserved in EN 300 392-2 [3])"
}

DisconnectCause = {
	'0' : "0 - Not defined or unknown",
	'1' : "1 - User request",
	'2' : "2 - Called party busy",
	'3' : "3 - Called party not reachable",
	'4' : "4 - Called party does not support encryption",
	'5' : "5 - Network congestion",
	'6' : "6 - Not allowed traffic",
	'7' : "7 - Incompatible traffic",
	'8' : "8 - Service not available",
	'9' : "9 - Pre-emption",
	'10' : "10 - Invalid call identifier",
	'11' : "11 - Called party rejection",
	'12' : "12 - No idle CC entity",
	'13' : "13 - Timer expiry",
	'14' : "14 - SwMI disconnect",
	'15' : "15 - No acknowledgement",
	'16' : "16 - Unknown TETRA identity",
	'17' : "17 - Supplementary Service dependent",
	'18' : "18 - Unknown external subscriber number",
	'19' : "19 - Call restoration failed",
	'20' : "20 - Called party requires encryption",
	'21' : "21 - Concurrent set-up not supported",
	'22' : "22 - Called party is under the same DM-GATE as the calling party",
	'23' : "23 - Reserved",
	'24' : "24 - Reserved",
	'25' : "25 - Reserved",
	'26' : "26 - Reserved",
	'27' : "27 - Reserved",
	'28' : "28 - Reserved",
	'29' : "29 - Reserved",
	'30' : "30 - Reserved",
	'31' : "31 - Called party offered unacceptable service",
	'32' : "32 - Pre-emption by late entering gateway",
	'33' : "33 - Link to DM-REP not established or failed",
	'34' : "34 - Link to gateway failed",
	'35' : "35 - Call rejected by gateway",
	'36' : "36 - V+D call set-up failure",
	'37' : "37 - V+D resource lost or call timer expired",
	'38' : "38 - Transmit authorization lost",
	'39' : "39 - Channel has become occupied by other users",
	'40' : "40 - Security parameter mismatch"
}

DmCommunicationType = {
	'0' :  "0 - Any, MT decides",
	'1' :  "1 - Direct MS-MS",
	'2' :  "2 - Via DM-REP",
	'3' :  "3 - Via DM-GATE",
	'4' :  "4 - Via DM-REP/GATE",
	'5' :  "5 - Reserved",
	'6' :  "6 - Direct MS-MS, but maintain gateway registration"
};

NumType = {
	'0' :  "0 - Individual (ISSI or ITSI)",
	'1' :  "1 - Group (GSSI or GTSI)",
	'2' :  "2 - PSTN Gateway (ISSI or ITSI)",
	'3' :  "3 - PABX Gateway (ISSI or ITSI)",
	'4' :  "4 - Service Centre (ISSI or ITSI)",
	'5' :  "5 - Service Centre (E.164 number)",
	'6' :  "6 - Individual (extended TSI)",
	'7' :  "7 - Group (extended TSI)"
}

ReasonForSending = {
	'0' : "0 - Subscriber unit is powered ON",
	'1' : "1 - Subscriber unit is powered OFF",
	'2' : "2 - Emergency condition is detected",
	'3' : "3 - Push-to-talk condition is detected",
	'4' : "4 - Status",
	'5' : "5 - Transmit inhibit mode ON",
	'6' : "6 - Transmit inhibit mode OFF",
	'7' : "7 - System access (TMO ON)",
	'8' : "8 - DMO ON",
	'9' : "9 - Enter service (after being out of service)",
	'10' : "10 - Service loss",
	'11' : "11 - Cell reselection or change of serving cell",
	'12' : "12 - Low battery",
	'13' : "13 - Subscriber unit is connected to a car kit",
	'14' : "14 - Subscriber unit is disconnected from a car kit",
	'15' : "15 - Subscriber unit asks for transfer initialization configuration",
	'16' : "16 - Arrival at destination",
	'17' : "17 - Arrival at a defined location",
	'18' : "18 - Approaching a defined location",
	'19' : "19 - SDS type-1 entered",
	'20' : "20 - User application initiated",
	'21' : "21 - Reserved"
}

GroupType = {
	'0' : "0 - None",
	'1' : "1 - Select",
	'2' : "2 - Scan priority 1",
	'3' : "3 - Scan priority 2",
	'4' : "4 - Scan priority 3",
	'5' : "5 - Scan priority 4",
	'6' : "6 - Scan priority 5",
	'7' : "7 - Scan priority 6"
}

sdsStatus = {
	'0' : "0 - Incoming message stored and unread",
	'1' : "1 - Incoming message stored and read",
	'2' : "2 - Outgoing message stored and unsent",
	'3' : "3 - Outgoing message stored and sent"
}





























