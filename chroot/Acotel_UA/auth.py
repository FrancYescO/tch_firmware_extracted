#
# Acotel_UA
#
# auth.py  
#
# Last update : 2020-10-30
#

import json
import requests
import os
from azure.iot.device import X509
from azure.iot.device.aio import ProvisioningDeviceClient
from azure.iot.device.aio import IoTHubDeviceClient

import TRACER as tracer

###################################

provisioning_host = "timdpsprod.azure-devices-provisioning.net"
id_scope          = "0ne0018C1AA"
registration_id   = "deviceaemtelecom21"

################


async def get_cert_key():
    bearer_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6MywiZXhwIjoxNjI5MzI2NzI1fQ.BAwIGjS9gEouGvUqFHKyD41eTKZzwRaZBxkexm5x-24"
    endpoint = "https://router.acoteldc.com/v1.0/api/router/certificate"
    payload = {"device_id": "123245", "csr": "122344"}
    crt =  get_token(endpoint,bearer_token,payload)
    #print(crt)
    device_crt_api = crt.get("certificate")
    device_crt = open("device_formello_crt.pem", "w")
    n = device_crt.write(str(device_crt_api))
    device_crt.close()
    
    cert = "device_formello_crt.pem"
    key = "device_formello_key.pem"
    
    return cert, key

def get_token(endpoint,bearer_token,payload):
    response = requests.post(endpoint, headers={'Content-Type': 'application/json','Authorization': bearer_token},data=json.dumps(payload))
    if response.ok:
        result = response.json()
        return result
    else:
        return "GET ERROR"


async def get_device_client(cert,key):
    ENV = (os.path.dirname(os.path.realpath(__file__)))
    x509 = X509(
        cert_file=ENV+"/"+cert,
        key_file=ENV+"/"+key,
        pass_phrase="formello",
    )
    provisioning_device_client = ProvisioningDeviceClient.create_from_x509_certificate(
        provisioning_host=provisioning_host,
        registration_id=registration_id,
        id_scope=id_scope,
        x509=x509,
    )
    
    #tracer.Info("Provisioning device client : " + str(provisioning_device_client))
    registration_result = await provisioning_device_client.register()
    #tracer.Info("The complete registration result is <<< " + str(registration_result.registration_state) + " >>>")

    tracer.Info("Registration result is : " + registration_result.status)

    if registration_result.status == "assigned":
        tracer.Info("Will send data to IotHub : " + registration_result.registration_state.assigned_hub)
        tracer.Info("... from the provisioned device with deviceID : " + registration_result.registration_state.device_id)
        device_client = IoTHubDeviceClient.create_from_x509_certificate(
            x509=x509,
            hostname=registration_result.registration_state.assigned_hub,
            device_id=registration_result.registration_state.device_id,
        )
        
        # Connect the client.
        await device_client.connect()
        #print("Connected to IotHub")
        tracer.Info("Connected to IotHub : " + registration_result.registration_state.assigned_hub)
        
        return device_client
    else:
        #print("Can not send telemetry from the provisioned device")
        tracer.Info("Can not send telemetry from the provisioned device")
