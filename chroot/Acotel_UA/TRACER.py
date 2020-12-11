#------------------------------------------------------------------------------
# 
# TRACER.py
#
# 2020-10-26 : Ported to python3
#
# Last update : 2020-10-26
#------------------------------------------------------------------------------
import os
import time
import datetime

TRACER_INFO = True
TRACER_WARNING = True
TRACER_DEBUG = True

#------------------------------------------------------------------------------
# Set
#------------------------------------------------------------------------------
def Set (Info, Warning, Debug):
	
	global TRACER_INFO
	global TRACER_WARNING
	global TRACER_DEBUG
	
	TRACER_INFO = Info
	TRACER_WARNING = Warning
	TRACER_DEBUG = Debug
	
	
	#print "TRACER_INFO=" + str(TRACER_INFO)
	#print "TRACER_WARNING=" + str(TRACER_WARNING)
	#print "TRACER_DEBUG=" + str(TRACER_DEBUG)

#------------------------------------------------------------------------------
# ShowException
#------------------------------------------------------------------------------
def ShowException(type, value, tb):
	#logger.exception("Uncaught exception: {0}".format(str(value)))
	PrintDebug("Uncaught exception: {0}".format(str(value)))
	PrintDebug(tb)

#------------------------------------------------------------------------------
# Debug
#------------------------------------------------------------------------------
def Debug (StringOut):
	
    global TRACER_DEBUG
	
    if TRACER_DEBUG == True:
		#print time.strftime("DEBUG - %d/%m/%Y %H:%M:%S"), StringOut
        LogText = "DEBUG   - " + str(datetime.datetime.now()) + "-" + StringOut
        print (LogText)
        WriteLog (LogText)

#------------------------------------------------------------------------------
# Warning
#------------------------------------------------------------------------------	
def Warning (StringOut):
	
    global TRACER_WARNING
    
    if TRACER_WARNING == True:
		#print time.strftime("WARNING - %d/%m/%Y %H:%M:%S"), StringOut
        LogText = "WARNING - " + str(datetime.datetime.now()) + StringOut
        print (LogText)
        WriteLog (LogText)
	
#------------------------------------------------------------------------------
# Info
#------------------------------------------------------------------------------
def Info (StringOut):
	
    global TRACER_INFO
    
    if TRACER_INFO == True:
		#print time.strftime("INFO - %d/%m/%Y %H:%M:%S"), StringOut
        LogText = "INFO    - " + str(datetime.datetime.now()) + "-" + StringOut
        print (LogText)
        WriteLog (LogText)
        
#------------------------------------------------------------------------------
# Write log file
#------------------------------------------------------------------------------
def WriteLog (LogText):

    Now = datetime.datetime.now()
    #LogFilename = Now.strftime("%Y-%m-%d") + ".log"
    LogFilename = Now.strftime("TRACER") + ".log"
    #print "FILE=" + LogFilename
    
    Size = os.path.getsize(LogFilename)
    #print "Size=" + str(Size)
    
    if (Size > 5000000):
        Log = open(LogFilename, "w")
    else:
        Log = open(LogFilename, "a")
    
    Log.write(LogText + chr(13) + chr(10) )
    Log.close  
