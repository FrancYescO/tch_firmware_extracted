#
# Acotel_UA
#
# main.py  
#
# Last update : 2020-11-10
#

import sys
import os
import asyncio
import datetime

import TRACER as tracer

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from datamodel import get_properties, get_telemetries
from auth import get_auth_data, get_device_client
from command import command_handling_init



g_outer_interval_minutes = 1440
g_inner_interval_minutes = 15
#g_outer_interval_minutes = 60
#g_inner_interval_minutes = 15
#g_outer_interval_minutes = 2
#g_inner_interval_minutes = 1
g_remaining_inner_intervals_init = g_outer_interval_minutes / g_inner_interval_minutes

LOGIN_RETRY_SECONDS = 600

strAGENT_VERSION = "Router Agent Ver.1.0.2 2020-11-10 14:45"

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
        #os.chdir("/Acotel_UA/paolo/")
        #os.chdir("/Acotel_UA/paolo/Acotel_UA/")
        
    except OSError:
        print("Can't change the Current Working Directory")
        sys.exit()
        
    #print("Current Working Directory " , os.getcwd())
    tracer.Info("Current Working Directory " + os.getcwd())
    tracer.Info("START " + strAGENT_VERSION)

    b_first_init = True

    while (True):
        b_remove_saved_auth_data = False
        while (True):
            # Get credentials for DPS
            cert, key, device = await get_auth_data(b_remove_saved_auth_data)
            # Register to DPS and connect to IotHub, returning device_client object for communication with IotHub
            g_device_client = await get_device_client(cert, key, device)

            if g_device_client:
                b_remove_saved_auth_data = False
                break
            else:
                tracer.Info("g_device_client is None... retry")
                b_remove_saved_auth_data = True
                await asyncio.sleep(LOGIN_RETRY_SECONDS)

        if b_first_init:
            # Init command handling
            command_handling_init(g_device_client)

            # Init intervals handling
            outer_interval_init()
            
            scheduler = AsyncIOScheduler()
            scheduler.add_job(periodic_data_send, 'interval', minutes=g_inner_interval_minutes)
            scheduler.start()
            
            b_first_init = False

        while True:
            if g_device_client:
                tracer.Info("Connection is UP")
            else:
                tracer.Info("Connection is DOWN")
                break
                
            await asyncio.sleep(10)
        

        
#
#
#   periodic_data_send()
#
#
async def periodic_data_send():
    global g_device_client

    if g_device_client: # Connection is UP
        tracer.Info("Before retrieving telemetries")
        telemetries = await get_telemetries()
        tracer.Info("After retrieving telemetries")
         
        tracer.Info("Telemetries message to send" + telemetries)
        if await data_send(telemetries):
            tracer.Info("Telemetries message successfully sent")
        else:
            tracer.Info("Telemetries message send failure")
            return

        
        if is_outer_interval_elapsed():
            tracer.Info("Before retrieving properties")
            properties = await get_properties()
            tracer.Info("After retrieving properties")
             
            tracer.Info("Properties message to send" + properties)
            if await data_send(properties):
                tracer.Info("Properties message successfully sent")
            else:
                tracer.Info("Properties message send failure")
            

#
#
#   data_send()
#
#
#FOR TEST
SENDOKBEFOREEXCEPT_NUM = 2
g_SendOkBeforeExcept_Count = SENDOKBEFOREEXCEPT_NUM
#################
async def data_send(data):
    global g_device_client
    global g_SendOkBeforeExcept_Count
    #try:
        #FOR TEST
        #g_SendOkBeforeExcept_Count = g_SendOkBeforeExcept_Count - 1
        #if g_SendOkBeforeExcept_Count == 0:
        #    g_SendOkBeforeExcept_Count = SENDOKBEFOREEXCEPT_NUM
        #    a = 2
        #    b = 2 / 0
        #################
    await g_device_client.send_message(data)
        
    return True
    #except Exception as err:
    #    tracer.Info("Send exception : " + str(err))
    #    g_device_client = None
    #    return False
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
