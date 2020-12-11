#
# Acotel_UA
#
# main.py  
#
# Last update : 2020-10-30    
#

import sys
import os
import asyncio
import datetime

import TRACER as tracer

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from datamodel import get_properties, get_telemetries
from auth import get_cert_key, get_device_client
from command import command_handling_init



g_outer_interval_minutes = 60
g_inner_interval_minutes = 15
#g_outer_interval_minutes = 6
#g_inner_interval_minutes = 2
g_remaining_inner_intervals_init = g_outer_interval_minutes / g_inner_interval_minutes


strAGENT_VERSION = "Router Agent Ver.2.0 2020-10-30 12:50"

#
#
#   main()
#
#
async def main():
    global g_device_client
    global g_inner_interval_minutes
    global g_outer_interval_minutes
    global g_remaining_inner_intervals_init
    
    try:
        # Change the current working Directory
        print("Change the current working Directory")
        os.chdir("/Acotel_UA/")
        #os.chdir("/Acotel_UA/paolo/Acotel_UA/")
        
    except OSError:
        print("Can't change the Current Working Directory")
        sys.exit()
        
    #print("Current Working Directory " , os.getcwd())
    tracer.Info("Current Working Directory " + os.getcwd())
    tracer.Info("START " + strAGENT_VERSION)
    
    # Get credentials for DPS
    cert, key = await get_cert_key()
    # Register to DPS and connect to IotHub, returning device_client object for communication with IotHub
    g_device_client = await get_device_client(cert, key)
    
    # Init command handling
    command_handling_init(g_device_client)

    # Init intervals handling
    outer_interval_init()
    
    scheduler = AsyncIOScheduler()
    scheduler.add_job(periodic_data_send, 'interval', minutes=g_inner_interval_minutes)
    scheduler.start()

    while True:
        tracer.Info("MAIN sleeping")
        await asyncio.sleep(10)
        

        
#
#
#   periodic_data_send()
#
#
async def periodic_data_send():
    global g_device_client

    tracer.Info("Before retrieving telemetries")
    telemetries = await get_telemetries()
    tracer.Info("After retrieving telemetries")
     
    tracer.Info("Telemetries message to send" + telemetries)
    await g_device_client.send_message(telemetries)
    tracer.Info("Telemetries message successfully sent")

    
    if is_outer_interval_elapsed():
        tracer.Info("Before retrieving properties")
        properties = await get_properties()
        tracer.Info("After retrieving properties")
         
        tracer.Info("Properties message to send" + properties)
        await g_device_client.send_message(properties)
        tracer.Info("Properties message successfully sent")


#
#
#   is_outer_interval_elapsed()
#
#
def is_outer_interval_elapsed():
    global g_remaining_inner_intervals
    
    g_remaining_inner_intervals = g_remaining_inner_intervals - 1
    
    if g_remaining_inner_intervals == 0:
        outer_interval_init()
        return True
        
    return False
        

#
#
#   outer_interval_init()
#
#
def outer_interval_init():
    global g_remaining_inner_intervals
    global g_remaining_inner_intervals_init
    
    g_remaining_inner_intervals = g_remaining_inner_intervals_init

    
if __name__ == '__main__':
    asyncio.run(main())
