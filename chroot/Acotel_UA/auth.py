#
# Acotel_UA
#
# auth.py  
#
# Last update : 2020-11-10
#

from ssl import SSLError
from OpenSSL import crypto

import base64

import requests
import json
import os
import asyncio
import subprocess

import azure.iot.device.exceptions as azureException

from azure.iot.device import X509
from azure.iot.device.aio import ProvisioningDeviceClient
from azure.iot.device.aio import IoTHubDeviceClient


import TRACER as tracer

###################################

PROVISIONING_HOST = "acld-tst-dps.azure-devices-provisioning.net"
ID_SCOPE          = "0ne001B5226"
#ID_SCOPE          = "0ne001B522" #WRONG FOR TEST

################
CERT_FILE_FOR_DPS = "device.cer"
KEY_FILE_FOR_DPS = "device.key"
CSR_FILE = "device.csr"
GET_AUTH_DATA_RETRY_SECONDS = 600

async def get_auth_data(b_remove_saved_auth_data):
    device = subprocess.Popen("uci get env.var.serial -q", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()

    tracer.Info("Device serial code : " + device)

    if saved_auth_data_found():
        if b_remove_saved_auth_data:
            saved_auth_data_remove()
        else:
            return CERT_FILE_FOR_DPS, KEY_FILE_FOR_DPS, device
        

    tracer.Info("Certificate and key files for DPS NOT FOUND. Asking to backend...")
    while (True):
        subject = getCertificateSubject(device)
        key = generatePrivateKey(KEY_FILE_FOR_DPS)
        csr = generateCsr(CSR_FILE, key, subject)
        cer = sendDeviceCertificateRequest(csr)

        if cer is None:
            tracer.Info("Can not get certificate for DPS : will retry after " + str(GET_AUTH_DATA_RETRY_SECONDS) + " seconds")
            await asyncio.sleep(GET_AUTH_DATA_RETRY_SECONDS)
        else:
            tracer.Info("Got certificate for DPS from backend")
            break

    return CERT_FILE_FOR_DPS, KEY_FILE_FOR_DPS, device

def saved_auth_data_found():
    if os.path.isfile(CERT_FILE_FOR_DPS) and os.path.isfile(KEY_FILE_FOR_DPS):
        tracer.Info("Found certificate and key files for DPS")
        return True
        
    return False

def saved_auth_data_remove():
    os.remove(CERT_FILE_FOR_DPS)
    os.remove(KEY_FILE_FOR_DPS)
    tracer.Info("Certificate and key files for DPS REMOVED")

def getCertificateSubject(device):
    result = dict();
    result["C"] = b"IT"
    result["ST"] = b"Italia"
    result["L"] = b"Roma    "
    result["O"] = b"Acotel Group"
    result["OU"] = b"Organization Unit"
    result["CN"] = device
    return result

def generatePrivateKey(filePath):
    key = crypto.PKey()
    key.generate_key(crypto.TYPE_RSA, 2048)
    content = crypto.dump_privatekey(crypto.FILETYPE_PEM, key)
    with open(filePath, "wb") as file:
        file.write(content)
    key = crypto.load_privatekey(crypto.FILETYPE_PEM, content);
    return key

def generateCsr(filePath, key, subject):
    req = crypto.X509Req();
    key_usage = [ b"Digital Signature", b"Non Repudiation", b"Key Encipherment" ]
    req.get_subject().C = subject["C"]
    req.get_subject().ST = subject["ST"]
    req.get_subject().L  = subject["L"]
    req.get_subject().O  = subject["O"]
    req.get_subject().OU = subject["OU"]
    req.get_subject().CN = subject["CN"]
    req.add_extensions([
        crypto.X509Extension( b"basicConstraints", False, b"CA:FALSE"),
        crypto.X509Extension( b"keyUsage", False, b",".join(key_usage)),
        #crypto.X509Extension( b"device", True, device),
    ])
    req.set_pubkey(key)
    req.sign(key, "sha256")
    csr = crypto.dump_certificate_request(crypto.FILETYPE_PEM, req)
    with open(filePath, "wb") as file:
        file.write(csr)
    return req

def sendDeviceCertificateRequest(csr):
    url = "https://test.acotelcloud.com/router/certificate"

    csrBytes = crypto.dump_certificate_request(crypto.FILETYPE_PEM, csr)
    csrBase64 = base64.b64encode(csrBytes).decode("ascii")
    body = { "csr": csrBase64 }

    try:    
        response = getApiToken()
        
        if response.ok:
            jsonResponse = response.json()
            token = jsonResponse['access_token']
            tracer.Info("Got access token from backend")
             
            request = requests.post(url, json=body, headers={ 'Authorization': 'Bearer '+token });
            
            if(request.ok):
                content = request.content;
                with open(CERT_FILE_FOR_DPS, "wb") as file:
                    file.write(content)
                cer = crypto.load_certificate(crypto.FILETYPE_PEM, content)
                tracer.Info("Got certificate from backend")
                return cer
            else:
                tracer.Info("Http error " + str(request.status_code) + " getting certificate from backend")
        else:
            tracer.Info("Http error " + str(response.status_code) + " getting token from backend")
            
        return None
        
    except Exception as err:
        tracer.Info("sendDeviceCertificateRequest() exception : " + str(err))
        return None


def getApiToken():
    url = "https://login.microsoftonline.com/3fc8e040-1b01-4290-b8fc-7dc8a31319db/oauth2/v2.0/token"
    payload = 'grant_type=client_credentials&client_id=643b0ec8-971a-4309-b7d7-a5d8fbee9a46&scope=api%3A//bdb4b564-1abc-4eeb-a468-af796dc35c30/.default&client_secret=.%7EYog2t_t8%7E9pl95V-fYTs6A5E54tzIgCz'
    headers = { 'Content-Type': 'application/x-www-form-urlencoded' }
    return requests.request("GET", url, headers=headers, data = payload)
  



async def get_device_client(cert, key, device):
    ENV = (os.path.dirname(os.path.realpath(__file__)))
    x509 = X509(
        cert_file=ENV+"/"+cert,
        key_file=ENV+"/"+key
    )

    try:
        provisioning_device_client = ProvisioningDeviceClient.create_from_x509_certificate(
            provisioning_host=PROVISIONING_HOST,
            registration_id=device,
            id_scope=ID_SCOPE,
            x509=x509
        )
        
        #tracer.Info("Provisioning device client : " + str(provisioning_device_client))
        tracer.Info("Registering to provisioning host : " + PROVISIONING_HOST)
        registration_result = await provisioning_device_client.register()
        #tracer.Info("The complete registration result is <<< " + str(registration_result.registration_state) + " >>>")

        tracer.Info("Registration result is : " + registration_result.status)

        if registration_result.status == "assigned":
            tracer.Info("Will send data to IotHub : " + registration_result.registration_state.assigned_hub)
            tracer.Info("... from the provisioned device with deviceID : " + registration_result.registration_state.device_id)

            device_client = IoTHubDeviceClient.create_from_x509_certificate(
                x509=x509,
                hostname=registration_result.registration_state.assigned_hub,
                device_id=registration_result.registration_state.device_id
                #x509=x509,
                #hostname=registration_result.registration_state.assigned_hub,
                #device_id="pippo"
            )
            
            # Connect the client.
            await device_client.connect()
            #print("Connected to IotHub")
            tracer.Info("Connected to IotHub : " + registration_result.registration_state.assigned_hub)
            
            return device_client
        else:
            #print("Can not send telemetry from the provisioned device")
            tracer.Info("Can not send telemetry from the provisioned device")
    
    except Exception as err:
        tracer.Info("get_device_client() exception : " + str(err))
        
    return None

#except azureException.CredentialError as message:
#    tracer.Info("provisioning CredentialError : " + str(message))

#except azureException.ClientError as message:
#    tracer.Info("provisioning ClientError : " + str(message))

#except azureException.ServiceError as message:
#    tracer.Info("provisioning ServiceError : " + str(message))
    
#except SSLError as message:
#    tracer.Info("provisioning SSL exception : " + str(message))
