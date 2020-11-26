#
# Acotel_UA
#
# command.py  
#
# Last update : 2020-11-09
#

from azure.iot.device import MethodResponse

import subprocess
import TRACER as tracer


def command_handling_init(device_client):
    global g_device_client

    g_device_client = device_client

    # Set the method request handler on the client
    g_device_client.on_method_request_received = method_request_handler
    tracer.Info("Command handler initialized")


# Define behavior for handling methods
async def method_request_handler(method_request):
    global g_device_client
    
    # Determine how to respond to the method request based on the method name
    if method_request.name == "changechannel":
        tracer.Info("Method changechannel - Before subprocess.Popen")
        result =subprocess.Popen('ubus call wireless.radio.acs rescan \'{"name":"radio_2G","act":1}\'', shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
        result =subprocess.Popen('ubus call wireless.radio.acs rescan \'{"name":"radio_5G","act":1}\'', shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
        tracer.Info("Method changechannel - After subprocess.Popen")
        payload = {"result":"OK"}  # set response payload
        status = 200  # set return status code
        tracer.Info("executed method : " + method_request.name)
        
    #elif method_request.name == "method2":
    #    payload = {"result": True, "data": 1234}  # set response payload
    #    status = 200  # set return status code
    #    tracer.Info("executed method1")
        
    else:
        payload = {"result":"UNKNOWN_METHOD"}  # set response payload
        status = 400  # set return status code
        tracer.Info("executed unknown method: " + method_request.name)

    # Send the response
    method_response = MethodResponse.create_from_method_request(method_request, status, payload)
    await g_device_client.send_method_response(method_response)
    tracer.Info("Method response successfully sent")
