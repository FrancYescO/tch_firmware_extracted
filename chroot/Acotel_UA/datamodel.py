#
# Acotel_UA
#
# datamodel.py  
#
# Last update : 2020-11-10
#

import json
import subprocess
import asyncio
import ast
import re

import TRACER as tracer

#
#
#   get_telemetries()
#
#

NEIGHBORING_SKIP_NUM = 4
neighboring_skip_cnt = NEIGHBORING_SKIP_NUM

async def get_telemetries():
    global neighboring_skip_cnt

    # COMMANDS STRING
    command_clash = 'Device.'

    # CLASH FUCTIONS
    clash = clash_get(command_clash)

    # PERFORMANCE DATA
    AB1 = clash.get("Device.DeviceInfo.MemoryStatus.X_000E50_MemoryUtilization [string]", '').replace(" ","")
    AB2 = clash.get("Device.DeviceInfo.MemoryStatus.Free [unsignedInt]", '').replace(" ","")
    AB3 = clash.get("Device.DeviceInfo.ProcessStatus.ProcessNumberOfEntries [unsignedInt]", '').replace(" ","")
    AB4 = clash.get("Device.DeviceInfo.ProcessStatus.CPUUsage [unsignedInt]", '').replace(" ","")
    AB5 = subprocess.Popen("mpstat | awk 'NR == 4 {print $3}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB6 = subprocess.Popen("mpstat | awk 'NR == 4 {print $4}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB7 = subprocess.Popen("mpstat | awk 'NR == 4 {print $5}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB8 = subprocess.Popen("mpstat | awk 'NR == 4 {print $6}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB9 = subprocess.Popen("mpstat | awk 'NR == 4 {print $7}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB10 = subprocess.Popen("mpstat | awk 'NR == 4 {print $8}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB11 = subprocess.Popen("mpstat | awk 'NR == 4 {print $9}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB12 = subprocess.Popen("mpstat | awk 'NR == 4 {print $10}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB13 = subprocess.Popen("mpstat | awk 'NR == 4 {print $11}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()


    #AC1 = subprocess.Popen("ping  -c 5 8.8.8.8 |grep 'round-trip min/avg/max' | awk 'NR == 1 {print $4}' | awk -F'/' '{print $1}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    #AC2 = subprocess.Popen("ping  -c 5 8.8.8.8 |grep 'round-trip min/avg/max' | awk 'NR == 1 {print $4}' | awk -F'/' '{print $2}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    #AC3 = subprocess.Popen("ping  -c 5 8.8.8.8 |grep 'round-trip min/avg/max' | awk 'NR == 1 {print $4}' | awk -F'/' '{print $3}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    
    AF1 = clash.get("Device.DSL.Line.1.DownstreamMaxBitRate [unsignedInt]", '').replace(" ","")
    AF2 = clash.get("Device.DSL.Line.1.UpstreamMaxBitRate [unsignedInt]", '').replace(" ","")
    AF3 = clash.get("Device.DSL.Line.1.SNRMpbus [string]", '').replace(" ","")
    AF4 = clash.get("Device.DSL.Line.1.SNRMpbds [string]", '').replace(" ","")
    AF5 = clash.get("Device.DSL.Line.1.X_000E50_UpstreamAttenuation [string]", '').replace(" ","")
    AF6 = clash.get("Device.DSL.Line.1.X_000E50_DownstreamAttenuation [string]", '').replace(" ","")
    AF7 = clash.get("Device.DSL.Line.1.UpstreamPower [int]", '').replace(" ","")
    AF8 = clash.get("Device.DSL.Line.1.DownstreamPower [int", '').replace(" ","")

    AG1 = clash.get("Device.Optical.Interface.1.UpperOpticalThreshold [int]", '').replace(" ","")
    AG2 = clash.get("Device.Optical.Interface.1.LastChange [unsignedInt]", '').replace(" ","")
    AG3 = clash.get("Device.Optical.Interface.1.Stats.ErrorsReceived [unsignedInt]", '').replace(" ","")
    AG4 = clash.get("Device.Optical.Interface.1.Stats.ErrorsSent [unsignedInt]", '').replace(" ","")
    AG5 = clash.get("Device.Optical.Interface.1.Stats.BytesReceived [unsignedLong]", '').replace(" ","")
    AG6 = clash.get("Device.Optical.Interface.1.Stats.DiscardPacketsSent [unsignedInt]", '').replace(" ","")
    AG7 = clash.get("Device.Optical.Interface.1.Stats.PacketsSent [unsignedLong]", '').replace(" ","")
    AG8 = clash.get("Device.Optical.Interface.1.Stats.BytesSent [unsignedLong]", '').replace(" ","")
    AG9 = clash.get("Device.Optical.Interface.1.Stats.PacketsReceived [unsignedLong]", '').replace(" ","")
    AG10 = clash.get("Device.Optical.Interface.1.Stats.DiscardPacketsReceived [unsignedInt]", '').replace(" ","")
    AG11 = clash.get("Device.Optical.Interface.1.Stats.reset [boolean]", '').replace(" ","")
    
    AH1 = clash.get("Device.Ethernet.Interface.5.Stats.UnknownProtoPacketsReceived [unsignedInt]", '').replace(" ","")
    AH2 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsReceived [unsignedInt]", '').replace(" ","")
    AH3 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsReceived [unsignedInt]", '').replace(" ","")
    AH4 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsSent [unsignedLong]", '').replace(" ","")
    AH5 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsReceived [unsignedLong]", '').replace(" ","")
    AH6 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsSent [unsignedLong]", '').replace(" ","")
    AH7 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsSent [unsignedInt]", '').replace(" ","")
    AH8 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsReceived [unsignedLong]", '').replace(" ","")
    AH9 = clash.get("Device.Ethernet.Interface.5.Stats.BytesReceived [unsignedLong]", '').replace(" ","")
    AH10 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsSent [unsignedInt]", '').replace(" ","")
    AH11 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsSent [unsignedLong]", '').replace(" ","")
    AH12 = clash.get("Device.Ethernet.Interface.5.Stats.BytesSent [unsignedLong]", '').replace(" ","")
    AH13 = clash.get("Device.Ethernet.Interface.5.Stats.PacketsReceived [unsignedLong]", '').replace(" ","")
    AH14 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsReceived [unsignedLong]", '').replace(" ","")
    AH15 = clash.get("Device.Ethernet.Interface.5.Stats.PacketsSent [unsignedLong]", '').replace(" ","")

    AI1 = clash.get("Device.Ethernet.Interface.5.Stats.UnknownProtoPacketsReceived [unsignedInt]", '').replace(" ","")
    AI2 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsReceived [unsignedInt]", '').replace(" ","")
    AI3 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsReceived [unsignedInt]", '').replace(" ","")
    AI4 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsSent [unsignedLong]", '').replace(" ","")
    AI5 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsReceived [unsignedLong]", '').replace(" ","")
    AI6 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsSent [unsignedLong]", '').replace(" ","")
    AI7 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsSent [unsignedInt]", '').replace(" ","")
    AI8 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsReceived [unsignedLong]", '').replace(" ","")
    AI9 = clash.get("Device.Ethernet.Interface.5.Stats.BytesReceived [unsignedLong]", '').replace(" ","")
    AI10 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsSent [unsignedInt]", '').replace(" ","")
    AI11 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsSent [unsignedLong]", '').replace(" ","")
    AI12 = clash.get("Device.Ethernet.Interface.5.Stats.BytesSent [unsignedLong]", '').replace(" ","")
    AI13 = clash.get("Device.Ethernet.Interface.5.Stats.PacketsReceived [unsignedLong]", '').replace(" ","")
    AH14 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsReceived [unsignedLong]", '').replace(" ","")

    AI1 = clash.get("Device.WiFi.SSID.1.Stats.ErrorsReceived [unsignedInt]", '').replace(" ","")
    AI2 = clash.get("Device.WiFi.SSID.1.Stats.AggregatedPacketCount [unsignedInt]", '').replace(" ","")
    AI3 = clash.get("Device.WiFi.SSID.1.Stats.BroadcastPacketsSent [unsignedLong]", '').replace(" ","")
    AI4 = clash.get("Device.WiFi.SSID.1.Stats.MulticastPacketsReceived [unsignedLong]", '').replace(" ","")
    AI5 = clash.get("Device.WiFi.SSID.1.Stats.UnicastPacketsReceived [unsignedLong]", '').replace(" ","")
    AI6 = clash.get("Device.WiFi.SSID.1.Stats.DiscardPacketsReceived [unsignedInt]", '').replace(" ","")
    AI7 = clash.get("Device.WiFi.SSID.1.Stats.ErrorsSent [unsignedInt]", '').replace(" ","")
    AI8 = clash.get("Device.WiFi.SSID.1.Stats.DiscardPacketsSent [unsignedInt]", '').replace(" ","")
    AI9 = clash.get("Device.WiFi.SSID.1.Stats.BytesReceived [unsignedLong]", '').replace(" ","")
    AI10 = clash.get("Device.WiFi.SSID.1.Stats.UnicastPacketsSent [unsignedLong]", '').replace(" ","")
    AI11 = clash.get("Device.WiFi.SSID.1.Stats.MulticastPacketsSent [unsignedLong]", '').replace(" ","")
    AI12 = clash.get("Device.WiFi.SSID.1.Stats.BytesSent [unsignedLong]", '').replace(" ","")
    AI13 = clash.get("Device.WiFi.SSID.1.Stats.PacketsReceived [unsignedLong]", '').replace(" ","")
    AI14 = clash.get("Device.WiFi.SSID.1.Stats.BroadcastPacketsReceived [unsignedLong]", '').replace(" ","")
    AI15 = clash.get("Device.WiFi.SSID.1.Stats.PacketsSent [unsignedLong]", '').replace(" ","")


    AL1 = clash.get("Device.WiFi.SSID.2.Stats.ErrorsReceived [unsignedInt]", '').replace(" ","")
    AL2 = clash.get("Device.WiFi.SSID.2.Stats.AggregatedPacketCount [unsignedInt]", '').replace(" ","")
    AL3 = clash.get("Device.WiFi.SSID.2.Stats.BroadcastPacketsSent [unsignedLong]", '').replace(" ","")
    AL4 = clash.get("Device.WiFi.SSID.2.Stats.MulticastPacketsReceived [unsignedLong]", '').replace(" ","")
    AL5 = clash.get("Device.WiFi.SSID.2.Stats.UnicastPacketsReceived [unsignedLong]", '').replace(" ","")
    AL6 = clash.get("Device.WiFi.SSID.2.Stats.DiscardPacketsReceived [unsignedInt]", '').replace(" ","")
    AL7 = clash.get("Device.WiFi.SSID.2.Stats.ErrorsSent [unsignedInt]", '').replace(" ","")
    AL8 = clash.get("Device.WiFi.SSID.2.Stats.DiscardPacketsSent [unsignedInt]", '').replace(" ","")
    AL9 = clash.get("Device.WiFi.SSID.2.Stats.BytesReceived [unsignedLong]", '').replace(" ","")
    AL10 = clash.get("Device.WiFi.SSID.2.Stats.UnicastPacketsSent [unsignedLong]", '').replace(" ","")
    AL11 = clash.get("Device.WiFi.SSID.2.Stats.MulticastPacketsSent [unsignedLong]", '').replace(" ","")
    AL12 = clash.get("Device.WiFi.SSID.2.Stats.BytesSent [unsignedLong]", '').replace(" ","")
    AL13 = clash.get("Device.WiFi.SSID.2.Stats.PacketsReceived [unsignedLong]", '').replace(" ","")
    AL14 = clash.get("Device.WiFi.SSID.2.Stats.BroadcastPacketsReceived [unsignedLong]", '').replace(" ","")
    AL15 = clash.get("Device.WiFi.SSID.2.Stats.PacketsSent [unsignedLong]", '').replace(" ","")

    AM1 = clash.get("Device.WiFi.SSID.3.Stats.ErrorsReceived [unsignedInt]", '').replace(" ","")
    AM2 = clash.get("Device.WiFi.SSID.3.Stats.AggregatedPacketCount [unsignedInt]", '').replace(" ","")
    AM3 = clash.get("Device.WiFi.SSID.3.Stats.BroadcastPacketsSent [unsignedLong]", '').replace(" ","")
    AM4 = clash.get("Device.WiFi.SSID.3.Stats.MulticastPacketsReceived [unsignedLong]", '').replace(" ","")
    AM5 = clash.get("Device.WiFi.SSID.3.Stats.UnicastPacketsReceived [unsignedLong]", '').replace(" ","")
    AM6 = clash.get("Device.WiFi.SSID.3.Stats.DiscardPacketsReceived [unsignedInt]", '').replace(" ","")
    AM7 = clash.get("Device.WiFi.SSID.3.Stats.ErrorsSent [unsignedInt]", '').replace(" ","")
    AM8 = clash.get("Device.WiFi.SSID.3.Stats.DiscardPacketsSent [unsignedInt]", '').replace(" ","")
    AM9 = clash.get("Device.WiFi.SSID.3.Stats.BytesReceived [unsignedLong]", '').replace(" ","")
    AM10 = clash.get("Device.WiFi.SSID.3.Stats.UnicastPacketsSent [unsignedLong]", '').replace(" ","")
    AM11 = clash.get("Device.WiFi.SSID.3.Stats.MulticastPacketsSent [unsignedLong]", '').replace(" ","")
    AM12 = clash.get("Device.WiFi.SSID.3.Stats.BytesSent [unsignedLong]", '').replace(" ","")
    AM13 = clash.get("Device.WiFi.SSID.3.Stats.PacketsReceived [unsignedLong]", '').replace(" ","")
    AM14 = clash.get("Device.WiFi.SSID.3.Stats.BroadcastPacketsReceived [unsignedLong]", '').replace(" ","")
    AM15 = clash.get("Device.WiFi.SSID.3.Stats.PacketsSent [unsignedLong]", '').replace(" ","")

    AN1 = clash.get("Device.WiFi.SSID.4.Stats.ErrorsReceived [unsignedInt]", '').replace(" ","")
    AN2 = clash.get("Device.WiFi.SSID.4.Stats.AggregatedPacketCount [unsignedInt]", '').replace(" ","")
    AN3 = clash.get("Device.WiFi.SSID.4.Stats.BroadcastPacketsSent [unsignedLong]", '').replace(" ","")
    AN4 = clash.get("Device.WiFi.SSID.4.Stats.MulticastPacketsReceived [unsignedLong]", '').replace(" ","")
    AN5 = clash.get("Device.WiFi.SSID.4.Stats.UnicastPacketsReceived [unsignedLong]", '').replace(" ","")
    AN6 = clash.get("Device.WiFi.SSID.4.Stats.DiscardPacketsReceived [unsignedInt]", '').replace(" ","")
    AN7 = clash.get("Device.WiFi.SSID.4.Stats.ErrorsSent [unsignedInt]", '').replace(" ","")
    AN8 = clash.get("Device.WiFi.SSID.4.Stats.DiscardPacketsSent [unsignedInt]", '').replace(" ","")
    AN9 = clash.get("Device.WiFi.SSID.4.Stats.BytesReceived [unsignedLong]", '').replace(" ","")
    AN10 = clash.get("Device.WiFi.SSID.4.Stats.UnicastPacketsSent [unsignedLong]", '').replace(" ","")
    AN11 = clash.get("Device.WiFi.SSID.4.Stats.MulticastPacketsSent [unsignedLong]", '').replace(" ","")
    AN12 = clash.get("Device.WiFi.SSID.4.Stats.BytesSent [unsignedLong]", '').replace(" ","")
    AN13 = clash.get("Device.WiFi.SSID.4.Stats.PacketsReceived [unsignedLong]", '').replace(" ","")
    AN14 = clash.get("Device.WiFi.SSID.4.Stats.BroadcastPacketsReceived [unsignedLong]", '').replace(" ","")
    AN15 = clash.get("Device.WiFi.SSID.4.Stats.PacketsSent [unsignedLong]", '').replace(" ","")
    
    dict_performance = {"performance":
                        {"SYS":{"AB1":AB1,"AB2":AB2,"AB3":AB3,"AB4":AB4,"AB5":AB5,"AB6":AB6,"AB7":AB7,"AB8":AB8,"AB9":AB9,"AB10":AB10,"AB11":AB11,"AB12":AB12,"AB13":AB13},
                        #"NET":{"AC1":AC1,"AC2":AC2,"AC3":AC3},
                        "XDSL":{"AF1":AF1,"AF2":AF2,"AF3":AF3,"AF4":AF4,"AF5":AF5,"AF6":AF6,"AF7":AF7,"AF8":AF8},
                        "SFP":{"AG1":AG1,"AG2":AG2,"AG3":AG3,"AG4":AG4,"AG5":AG5,"AG6":AG6,"AG7":AG7,"AG8":AG8,"AG9":AG9,"AG10":AG10,"AG11":AG11},
                        "WAN":{"AH1":AH1,"AH2":AH2,"AH3":AH3,"AH4":AH4,"AH5":AH5,"AH6":AH6,"AH7":AH7,"AH8":AH8,"AH9":AH9,"AH10":AH10,"AH11":AH11,"AH12":AH12,"AH13":AH13,"AH14":AH14,"AH15":AH15},
                        "WiFi_AP1":{"AI1":AI1,"AI2":AI2,"AI3":AI3,"AI4":AI4,"AI5":AI5,"AI6":AI6,"AI7":AI7,"AI8":AI8,"AI9":AI9,"AI10":AI10,"AI11":AI11,"AI12":AI12,"AI13":AI13,"AI14":AI14,"AI15":AI15},
                        "WiFi_AP2":{"AL1":AL1,"AL2":AL2,"AL3":AL3,"AL4":AL4,"AL5":AL5,"AL6":AL6,"AL7":AL7,"AL8":AL8,"AL9":AL9,"AL10":AL10,"AL11":AL11,"AL12":AL12,"AL13":AL13,"AL14":AL14,"AL15":AL15},
                        "WiFi_AP3":{"AM1":AM1,"AM2":AM2,"AM3":AM3,"AM4":AM4,"AM5":AM5,"AM6":AM6,"AM7":AM7,"AM8":AM8,"AM9":AM9,"AM10":AM10,"AM11":AM11,"AM12":AM12,"AM13":AM13,"AM14":AM14,"AM15":AM15},
                        "WiFi_AP4":{"AN1":AN1,"AN2":AN2,"AN3":AN3,"AN4":AN4,"AN5":AN5,"AN6":AN6,"AN7":AN7,"AN8":AN8,"AN9":AN9,"AN10":AN10,"AN11":AN11,"AN12":AN12,"AN13":AN13,"AN14":AN14,"AN15":AN15}
                        }}
    
    tracer.Info("datamodel : Before get_obj_device")

    # EXTRACTION OBJ DEVICE
    dict_device = get_obj_device(clash)

    tracer.Info("datamodel : before neighboring logic")
    
    # Neighboring are extracted every NEIGHBORING_SKIP_NUM times
    neighboring_skip_cnt = neighboring_skip_cnt - 1
    if neighboring_skip_cnt == 0:
        neighboring_skip_cnt = NEIGHBORING_SKIP_NUM

        tracer.Info("datamodel : extracting neighboring")
        
        # EXTRACTION OBJ NEIGHBORING WIFI
        ubus_neighboring_wifi = get_NeighboringWiFi()
        dict_neigh_2G = ubus_neighboring_wifi["radio_2G"]
        dict_neigh_5G = ubus_neighboring_wifi["radio_5G"]
        neigh_count_2G = len(dict_neigh_2G)
        neigh_count_5G = len(dict_neigh_5G)

        
        dict_neighboring_wifi = {"neighboring":
                                 {"AV1": neigh_count_2G + neigh_count_5G,
                                  "NeighboringWiFi_2G": dict_neigh_2G,
                                  "NeighboringWiFi_5G": dict_neigh_5G
                                 }}

        dict_telemetries = {**dict_performance, **dict_device, **dict_neighboring_wifi}
    else:
        tracer.Info("datamodel : skipping neighboring")

        dict_telemetries = {**dict_performance, **dict_device}

    return (json.dumps(dict_telemetries))

#
#
#   get_obj_device()
#
#
def get_obj_device(clash):
    #AO1 = "from UA_info.txt"
    #AO2 = "from UA_info.txt"
    #AO3 = "from UA_info.txt"
    #AO4 = "from UA_info.txt"
    #AO5 = "from UA_info.txt"


    dict_device = {"device":{}
                      #{"UA":{ "AO1":AO1,"AO2":AO2,"AO3":AO3,"AO4":AO4,"AO5":AO5},
                     }

    # EXTRACTION OBJ HOSTS
    dict_device["device"].update(get_Hosts())

    # EXTRACTION OBJ WIFI
    dict_device["device"].update(get_Wifi(clash))
                      
    # EXTRACTION WIFI ACCESS POINT ASSOCIATED DEVICES                    
    dict_device["device"].update(get_AssociatedDevice_AP1())
    dict_device["device"].update(get_AssociatedDevice_AP2())
    dict_device["device"].update(get_AssociatedDevice_AP3())
    dict_device["device"].update(get_AssociatedDevice_AP4())

    return dict_device


#
#
#   get_Hosts()
#
#
def get_Hosts():
    command_clash = 'Device.Hosts.Host.'
    clash = clash_get(command_clash)

    command_clash_ap1 = 'Device.Hosts.HostNumberOfEntries'
    clash_ap1 = clash_get(command_clash_ap1)
    AP1 = clash_ap1.get("Device.Hosts.HostNumberOfEntries [unsignedInt]", '').replace(" ","")
    AP2 = 0
    alljson = {}
    alllist = []
    for key,value in clash.items():
        try:
            pattern = "Device.Hosts.Host\.(.*?)\.AssociatedDevice"
            substring = re.search(pattern, key).group(1)
        except:
            continue
        AP3 = clash.get("Device.Hosts.Host." + substring + ".AssociatedDevice [string]", '').replace(" ","")
        AP4 = clash.get("Device.Hosts.Host." + substring + ".Layer3Interface [string]", '').replace(" ","")
        AP5 = clash.get("Device.Hosts.Host." + substring + ".Layer1Interface [string]", '').replace(" ","")
        AP6 = clash.get("Device.Hosts.Host." + substring + ".IPAddress [string]", '').replace(" ","")
        AP7 = clash.get("Device.Hosts.Host." + substring + ".DHCPClient [string]", '').replace(" ","")
        AP8 = clash.get("Device.Hosts.Host." + substring + ".PhysAddress [string]", '').replace(" ","")
        AP9 = clash.get("Device.Hosts.Host." + substring + ".HostName [string]", '').replace(" ","")
        AP10 = clash.get("Device.Hosts.Host." + substring + ".IPv4AddressNumberOfEntries [unsignedInt]'", '').replace(" ","")
        AP11 = clash.get("Device.Hosts.Host." + substring + ".IPv6AddressNumberOfEntries [unsignedInt]", '').replace(" ","")
        AP12 = clash.get("Device.Hosts.Host." + substring + ".LeaseTimeRemaining [int]", '').replace(" ","")
        AP13 = clash.get("Device.Hosts.Host." + substring + ".ActiveLastChange [dateTime]", '').replace(" ","")
        AP14 = clash.get("Device.Hosts.Host." + substring + ".Alias [string]", '').replace(" ","")
        AP15 = clash.get("Device.Hosts.Host." + substring + ".Active [boolean]", '').replace(" ","")
        AP16 = clash.get("Device.Hosts.Host." + substring + ".IPv4Address.2.IPAddress [string]", '').replace(" ","")
        if AP15 == '1':
            AP2 += 1

        host = {"AP3":AP3,"AP4":AP4,"AP5":AP5,"AP6":AP6,"AP7":AP7,"AP8":AP8,"AP9":AP9,"AP10":AP10,"AP11":AP11,"AP12":AP12,"AP13":AP13,"AP14":AP14,"AP15":AP15,"AP16":AP16}

        alllist.append(host)

    return {"HOST":{"AP1":AP1,"AP2":AP2,"devices":alllist}}


#
#
#   get_Wifi()
#
#
def get_Wifi(clash):
    radio_2g = get_radio_2g()
    radio_5g = get_radio_5g()

    radio_2g_stats = get_radio_stats_2g()
    radio_5g_stats = get_radio_stats_5g()

    AQ1 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDeviceNumberOfEntries [unsignedInt]").replace(" ","")
    AQ2 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDeviceNumberOfEntries [unsignedInt]").replace(" ","")
    AQ3 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDeviceNumberOfEntries [unsignedInt]").replace(" ","")
    AQ4 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDeviceNumberOfEntries [unsignedInt]").replace(" ","")
    AQ5 = clash.get("Device.WiFi.Radio.1.ChannelsInUse [string]").replace(" ","")
    AQ6 = clash.get("Device.WiFi.Radio.2.ChannelsInUse [string]").replace(" ","")
    AQ7 = clash.get("Device.WiFi.Radio.1.Channel [unsignedInt]").replace(" ","")
    AQ8 = clash.get("Device.WiFi.Radio.2.Channel [unsignedInt]").replace(" ","")
    AQ9 = radio_2g.get('max_phy_rate')
    AQ10 = radio_2g.get('phy_rate')
    AQ11 = radio_5g.get('max_phy_rate')
    AQ12 = radio_5g.get('phy_rate')
    AQ13 = radio_2g_stats.get('medium_available')
    AQ14 = radio_2g_stats.get('glitch')
    AQ15 = radio_2g_stats.get('txtime')
    AQ16 = radio_2g_stats.get('rx_inside_bss')
    AQ17 = radio_2g_stats.get('rx_outside_bss')
    AQ18 = radio_5g_stats.get('medium_available')
    AQ19 = radio_5g_stats.get('glitch')
    AQ20 = radio_5g_stats.get('txtime')
    AQ21 = radio_5g_stats.get('rx_inside_bss')
    AQ22 = radio_5g_stats.get('rx_outside_bss')
    AQ23 = clash.get("Device.WiFi.Radio.1.ChannelLastChange [unsignedInt]").replace(" ","")
    AQ24 = clash.get("Device.WiFi.Radio.1.CurrentOperatingChannelBandwidth [string]").replace(" ","")
    AQ25 = clash.get("Device.WiFi.Radio.1.MaxBitRate [unsignedInt]").replace(" ","")
    AQ26 = clash.get("Device.WiFi.Radio.1.Stats.ErrorsReceived [unsignedInt]").replace(" ","")
    AQ27 = clash.get("Device.WiFi.Radio.1.Stats.FCSErrorCount [unsignedInt]").replace(" ","")
    AQ28 = clash.get("Device.WiFi.Radio.1.Stats.ErrorsSent [unsignedInt]").replace(" ","")
    AQ29 = clash.get("Device.WiFi.Radio.1.Stats.PLCPErrorCount [unsignedInt]").replace(" ","")
    AQ30 = clash.get("Device.WiFi.Radio.1.Stats.BytesReceived [unsignedLong]").replace(" ","")
    AQ31 = clash.get("Device.WiFi.Radio.1.Stats.PacketsReceived [unsignedLong]").replace(" ","")
    AQ32 = clash.get("Device.WiFi.Radio.1.Stats.X_000E50_FailedRetransCount [unsignedInt]").replace(" ","")
    AQ33 = clash.get("Device.WiFi.Radio.1.Stats.Noise [int]").replace(" ","")
    AQ34 = clash.get("Device.WiFi.Radio.1.Stats.TotalChannelChangeCount [unsignedInt]").replace(" ","")
    AQ35 = clash.get("Device.WiFi.Radio.1.Stats.PacketsSent [unsignedLong]").replace(" ","")
    AQ36 = clash.get("Device.WiFi.Radio.1.Stats.DiscardPacketsSent [unsignedInt]").replace(" ","")
    AQ37 = clash.get("Device.WiFi.Radio.1.Stats.BytesSent [unsignedLong]").replace(" ","")
    AQ38 = clash.get("Device.WiFi.Radio.1.Stats.DiscardPacketsReceived [unsignedInt]").replace(" ","")
    AQ39 = clash.get("Device.WiFi.Radio.1.Stats.X_000E50_RetransCount [unsignedInt]").replace(" ","")
    AQ40 = clash.get("Device.WiFi.Radio.1.Stats.X_000E50_ChannelUtilization [unsignedInt]").replace(" ","")
    AQ41 = clash.get("Device.WiFi.Radio.2.ChannelLastChange [unsignedInt]").replace(" ","")
    AQ42 = clash.get("Device.WiFi.Radio.2.CurrentOperatingChannelBandwidth [string]").replace(" ","")
    AQ43 = clash.get("Device.WiFi.Radio.2.MaxBitRate [unsignedInt]").replace(" ","")
    AQ44 = clash.get("Device.WiFi.Radio.2.Stats.ErrorsReceived [unsignedInt]").replace(" ","")
    AQ45 = clash.get("Device.WiFi.Radio.2.Stats.FCSErrorCount [unsignedInt]").replace(" ","")
    AQ46 = clash.get("Device.WiFi.Radio.2.Stats.ErrorsSent [unsignedInt]").replace(" ","")
    AQ47 = clash.get("Device.WiFi.Radio.2.Stats.PLCPErrorCount [unsignedInt]").replace(" ","")
    AQ48 = clash.get("Device.WiFi.Radio.2.Stats.BytesReceived [unsignedLong]").replace(" ","")
    AQ49 = clash.get("Device.WiFi.Radio.2.Stats.PacketsReceived [unsignedLong]").replace(" ","")
    AQ50 = clash.get("Device.WiFi.Radio.2.Stats.X_000E50_FailedRetransCount [unsignedInt]").replace(" ","")
    AQ51 = clash.get("Device.WiFi.Radio.2.Stats.Noise [int]").replace(" ","")
    AQ52 = clash.get("Device.WiFi.Radio.2.Stats.TotalChannelChangeCount [unsignedInt]").replace(" ","")
    AQ53 = clash.get("Device.WiFi.Radio.2.Stats.PacketsSent [unsignedLong]").replace(" ","")
    AQ54 = clash.get("Device.WiFi.Radio.2.Stats.DiscardPacketsSent [unsignedInt]").replace(" ","")
    AQ55 = clash.get("Device.WiFi.Radio.2.Stats.BytesSent [unsignedLong]").replace(" ","")
    AQ56 = clash.get("Device.WiFi.Radio.2.Stats.DiscardPacketsReceived [unsignedInt]").replace(" ","")
    AQ57 = clash.get("Device.WiFi.Radio.2.Stats.X_000E50_RetransCount [unsignedInt]").replace(" ","")
    AQ58 = clash.get("Device.WiFi.Radio.2.Stats.X_000E50_ChannelUtilization [unsignedInt]").replace(" ","")
    
    return {"WiFi":{ "AQ1":AQ1,  "AQ2":AQ2,  "AQ3":AQ3,  "AQ4":AQ4,  "AQ5":AQ5,  "AQ6":AQ6,  "AQ7":AQ7,  "AQ8":AQ8,  "AQ9":AQ9, "AQ10":AQ10,
                             "AQ11":AQ11,"AQ12":AQ12,"AQ13":AQ13,"AQ14":AQ14,"AQ15":AQ15,"AQ16":AQ16,"AQ17":AQ17,"AQ18":AQ18,"AQ19":AQ19,"AQ20":AQ20,
                             "AQ21":AQ21,"AQ22":AQ22,"AQ23":AQ23,"AQ24":AQ24,"AQ25":AQ25,"AQ26":AQ26,"AQ27":AQ27,"AQ28":AQ28,"AQ29":AQ29,"AQ30":AQ30,
                             "AQ31":AQ31,"AQ32":AQ32,"AQ33":AQ33,"AQ34":AQ34,"AQ35":AQ35,"AQ36":AQ36,"AQ37":AQ37,"AQ38":AQ38,"AQ39":AQ39,"AQ40":AQ40,
                             "AQ41":AQ41,"AQ42":AQ42,"AQ43":AQ43,"AQ44":AQ44,"AQ45":AQ45,"AQ46":AQ46,"AQ47":AQ47,"AQ48":AQ48,"AQ49":AQ49,"AQ50":AQ50,
                             "AQ51":AQ51,"AQ52":AQ52,"AQ53":AQ53,"AQ54":AQ54,"AQ55":AQ55,"AQ56":AQ56,"AQ57":AQ57,"AQ58":AQ58}
                      }
    
#
#
#   get_AssociatedDevice_AP1()
#
#
def get_AssociatedDevice_AP1():
    command_clash = 'Device.WiFi.AccessPoint.1.AssociatedDevice.'
    clash = clash_get(command_clash)
    alllist = []
    for key,value in clash.items():
        try:
            pattern = "Device.WiFi.AccessPoint.1.AssociatedDevice\.(.*?)\.Active"
            substring = re.search(pattern, key).group(1)
        except:
            continue
        AR1 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        AR2 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".X_000E50_SNR [int]", '').replace(" ","")
        AR3 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".Noise [int]", '').replace(" ","")
        AR4 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".SignalStrength [int]", '').replace(" ","")
        AR5 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".MACAddress [string]", '').replace(" ","")
        AR6 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".X_000E50_ConnectionTime [unsignedInt]", '').replace(" ","")
        AR7 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".LastDataDownlinkRate [unsignedInt]", '').replace(" ","")
        AR8 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".LastDataUplinkRate [unsignedInt]", '').replace(" ","")
        AR9 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".X_000E50_Reassociation [unsignedInt]", '').replace(" ","")
        AR10 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".Stats.ErrorsSent [unsignedInt", '').replace(" ","")
        AR11 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".Stats.BytesReceived [unsignedLong]", '').replace(" ","")
        AR12 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".Stats.BytesSent [unsignedLong]", '').replace(" ","")
        AR13 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".Stats.PacketsSent [unsignedLong]", '').replace(" ","")
        AR14 = clash.get("Device.WiFi.AccessPoint.1.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        host = {"AR1":AR1,"AR2":AR2,"AR3":AR3,"AR4":AR4,"AR5":AR5,"AR6":AR6,"AR7":AR7,"AR8":AR8,"AR9":AR9,"AR10":AR10,"AR11":AR11,"AR12":AR12,"AR13":AR13,"AR14":AR14}
        alllist.append(host)

    return {"AssociatedDevice_AP1":alllist}
    
#
#
#   get_AssociatedDevice_AP2()
#
#
def get_AssociatedDevice_AP2():
    command_clash = 'Device.WiFi.AccessPoint.2.AssociatedDevice.'
    clash = clash_get(command_clash)
    alllist = []
    for key,value in clash.items():
        try:
            pattern = "Device.WiFi.AccessPoint.2.AssociatedDevice\.(.*?)\.Active"
            substring = re.seASch(pattern, key).group(1)
        except:
            continue
        AS1 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        AS2 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".X_000E50_SNR [int]", '').replace(" ","")
        AS3 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".Noise [int]", '').replace(" ","")
        AS4 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".SignalStrength [int]", '').replace(" ","")
        AS5 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".MACAddress [string]", '').replace(" ","")
        AS6 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".X_000E50_ConnectionTime [unsignedInt]", '').replace(" ","")
        AS7 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".LastDataDownlinkRate [unsignedInt]", '').replace(" ","")
        AS8 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".LastDataUplinkRate [unsignedInt]", '').replace(" ","")
        AS9 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".X_000E50_Reassociation [unsignedInt]", '').replace(" ","")
        AS10 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".Stats.ErrorsSent [unsignedInt", '').replace(" ","")
        AS11 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".Stats.BytesReceived [unsignedLong]", '').replace(" ","")
        AS12 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".Stats.BytesSent [unsignedLong]", '').replace(" ","")
        AS13 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".Stats.PacketsSent [unsignedLong]", '').replace(" ","")
        AS14 = clash.get("Device.WiFi.AccessPoint.2.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        host = {"AS1": AS1, "AS2": AS2, "AS3": AS3, "AS4": AS4, "AS5": AS5, "AS6": AS6, "AS7": AS7, "AS8": AS8,"AS9": AS9, "AS10": AS10, "AS11": AS11, "AS12": AS12,"AS13":AS13,"AS14":AS14}
        alllist.append(host)
        
    return {"AssociatedDevice_AP2":alllist}

#
#
#   get_AssociatedDevice_AP3()
#
#
def get_AssociatedDevice_AP3():
    command_clash = 'Device.WiFi.AccessPoint.3.AssociatedDevice.'
    clash = clash_get(command_clash)
    alllist = []
    for key,value in clash.items():
        try:
            pattern = "Device.WiFi.AccessPoint.3.AssociatedDevice\.(.*?)\.Active"
            substring = re.search(pattern, key).group(1)
        except:
            continue
        AT1 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        AT2 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".X_000E50_SNR [int]", '').replace(" ","")
        AT3 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".Noise [int]", '').replace(" ","")
        AT4 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".SignalStrength [int]", '').replace(" ","")
        AT5 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".MACAddress [string]", '').replace(" ","")
        AT6 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".X_000E50_ConnectionTime [unsignedInt]", '').replace(" ","")
        AT7 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".LastDataDownlinkRate [unsignedInt]", '').replace(" ","")
        AT8 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".LastDataUplinkRate [unsignedInt]", '').replace(" ","")
        AT9 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".X_000E50_Reassociation [unsignedInt]", '').replace(" ","")
        AT10 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".Stats.ErrorsSent [unsignedInt", '').replace(" ","")
        AT11 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".Stats.BytesReceived [unsignedLong]", '').replace(" ","")
        AT12 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".Stats.BytesSent [unsignedLong]", '').replace(" ","")
        AT13 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".Stats.PacketsSent [unsignedLong]", '').replace(" ","")
        AT14 = clash.get("Device.WiFi.AccessPoint.3.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        host = {"AT1": AT1, "AT2": AT2, "AT3": AT3, "AT4": AT4, "AT5": AT5, "AT6": AT6, "AT7": AT7, "AT8": AT8,"AT9": AT9, "AT10": AT10, "AT11": AT11, "AT12": AT12,"AT13":AT13,"AT14":AT14}
        alllist.append(host)

    return {"AssociatedDevice_AP3":alllist}

    
#
#
#   get_AssociatedDevice_AP4()
#
#
def get_AssociatedDevice_AP4():
    command_clash = 'Device.WiFi.AccessPoint.4.AssociatedDevice.'
    clash = clash_get(command_clash)
    alllist = []
    for key,value in clash.items():
        try:
            pattern = "Device.WiFi.AccessPoint.4.AssociatedDevice\.(.*?)\.Active"
            substring = re.search(pattern, key).group(1)
        except:
            continue
        AU1 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        AU2 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".X_000E50_SNR [int]", '').replace(" ","")
        AU3 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".Noise [int]", '').replace(" ","")
        AU4 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".SignalStrength [int]", '').replace(" ","")
        AU5 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".MACAddress [string]", '').replace(" ","")
        AU6 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".X_000E50_ConnectionTime [unsignedInt]", '').replace(" ","")
        AU7 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".LastDataDownlinkRate [unsignedInt]", '').replace(" ","")
        AU8 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".LastDataUplinkRate [unsignedInt]", '').replace(" ","")
        AU9 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".X_000E50_Reassociation [unsignedInt]", '').replace(" ","")
        AU10 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".Stats.ErrorsSent [unsignedInt", '').replace(" ","")
        AU11 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".Stats.BytesReceived [unsignedLong]", '').replace(" ","")
        AU12 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".Stats.BytesSent [unsignedLong]", '').replace(" ","")
        AU13 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".Stats.PacketsSent [unsignedLong]", '').replace(" ","")
        AU14 = clash.get("Device.WiFi.AccessPoint.4.AssociatedDevice." + substring + ".OperatingStandard [string]", '').replace(" ","")
        host = {"AU1": AU1, "AU2": AU2, "AU3": AU3, "AU4": AU4, "AU5": AU5, "AU6": AU6, "AU7": AU7, "AU8": AU8,"AU9": AU9, "AU10": AU10, "AU11": AU11, "AU12": AU12,"AU13":AU13,"AU14":AU14}

    return {"AssociatedDevice_AP4":alllist}


#
#
#   get_properties()
#
#
async def get_properties():
    # COMMANDS STRING
    command_clash = 'Device.'
    clash_rpc = 'rpc.'
    
    # CLASH FUNCTIONS
    clash = clash_get(command_clash)
    clash_rpc = clash_get(clash_rpc)
    
    # info
    info = get_info(clash, clash_rpc)
    # config
    config = get_config(clash, clash_rpc)
    #print(info)
    #print(config)
    #all_dict = info
    #merged = {**info, **config}
    jsonMerged = {**json.loads(info), **json.loads(config)}
    return json.dumps(jsonMerged)



#
#
#   get_info()
#
#
def get_info(clash, clash_rpc):
    # COMMANDS STRING
    uci_var = 'env.var'
    uci_rip = 'env.rip'
    
    # UCI FUNCTIONS
    uci_show_var = uci_show(uci_var)
    uci_show_rip = uci_show(uci_rip)

    A1 = uci_show_var.get("env.var.company_name")
    A2 = uci_show_var.get("env.var.hardware_version")
    A3 = uci_show_var.get("env.var.oui")
    A4 = uci_show_var.get("env.var.prod_friendly_name")
    A5 = uci_show_var.get("env.var.serial")
    A6 = clash.get("Device.Services.VoiceService.1.VoiceProfile.1.Line.1.SIP.URI [string]", '')
    A7 = uci_show_var.get("env.var.local_eth_mac")
    A8 = uci_show_var.get("env.var.local_wifi_mac")
    A9 = uci_show_var.get("env.var.qtn_eth_mac")
    A10 = uci_show_rip.get("env.rip.eth_mac")
    A11 = uci_show_rip.get("env.rip.wifi_mac")
    A12 = uci_show_rip.get("env.rip.usb_mac")
    A13 = subprocess.Popen("uci get cwmpd.cwmpd_config.firstusedate -q", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    A14 = uci_show_var.get("env.var.unlockedstatus")
    A15 = uci_show_rip.get("env.rip.factory_date")
    A16 = clash.get("Device.DeviceInfo.MemoryStatus.X_000E50_MemoryUtilization [string]", '').replace(" ","")
    A17 = clash.get("Device.DeviceInfo.X_000E50_TotalHWReboot [unsignedInt]", '').replace(" ","")
    A18 = clash.get("Device.DeviceInfo.X_000E50_ScheduledReboot [boolean]", '').replace(" ","")
    A19 = clash.get("Device.DeviceInfo.X_000E50_RebootCause [string]", '').replace(" ","")
    A20 = clash.get("Device.DeviceInfo.X_000E50_FactoryReset_Wireless [boolean]", '').replace(" ","")
    A21 = clash_rpc.get("rpc.system.reboottime [dateTime]", '').replace(" ","")
    A22 = clash_rpc.get("rpc.system.uptime [unsignedInt]", '').replace(" ","")
    B1 = uci_show_var.get("env.var.friendly_sw_version_activebank")
    B2 = uci_show_var.get("env.var.friendly_sw_version_passivebank")
    B3 = subprocess.Popen("uci get version.@version[0].marketing_version -q", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() #uci.get("version.cfg016c4b.marketing_version").replace("\n", "")
    B4 = 'from config script'
    B5 = 'from config script'
    B6 = 'from UA_info.txt'
    B7 = clash.get("Device.DeviceInfo.X_000E50_TotalSWReboot [unsignedInt]", '')
    dict_info = {"info": {
        "hw": {"A1": A1, "A2": A2, "A3": A3, "A4": A4, "A5": A5,
               "A6": A6, "A7": A7, "A8": A8, "A9": A9, "A10": A10,
               "A11": A11, "A12": A12, "A13": A13, "A14": A14, "A15": A15,
               #"A16": A16, "A17": int(A17), "A18": int(A18), "A19": A19,
               "A16": A16, "A17": A17, "A18": A18, "A19": A19,
               "A20": A20, "A21": A21, "A22": A22},
        "sw": {"B1": B1, "B2": B2, "B3": B3, "B4": B4, "B5": B5, "B6": B6,
               "B7": int(B7)}}}
    return (json.dumps(dict_info))

#
#
#   get_config()
#
#
def get_config(clash, clash_rpc):
    # COMMANDS STRING
    uci_samba = "samba"
    uci_printersharing = "printersharing"
    clash_firewall = 'Device.Firewall.'

    # UCI FUNCTIONS
    uci_show_samba = uci_show(uci_samba)
    uci_show_printersharing = uci_show(uci_printersharing)

    # CLASH FUNCTIONS 
    clash_firewall = clash_get(clash_firewall)

    C1 = clash.get("Device.IP.Interface.1.IPv4Address.1.AddressingType [string]", '').replace(" ","")
    C2 = clash.get("Device.IP.Interface.1.IPv4Address.1.IPAddress [string]", '').replace(" ","")
    C4 = clash.get("Device.IP.Interface.1.IPv4Address.1.Enable [boolean]", '').replace(" ","")
    C5 = clash.get("Device.IP.Interface.1.IPv4Address.1.SubnetMask [string]", '').replace(" ","")
    C6 = clash.get("Device.IP.Interface.1.IPv4Address.1.Alias [string]", '').replace(" ","")
    C7 = clash.get("Device.IP.Interface.1.IPv4Address.1.Status [string]", '').replace(" ","")
    D1 = subprocess.Popen("clash get Device.DeviceInfo.NetworkProperties.X_000E50_WanSyncStatus", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.DeviceInfo.NetworkProperties.X_000E50_WanSyncStatus [string] = ", '') #clash.get("DeviceInfo.ProcessStatus.Process.1756.Command [string]", '').replace("\n","")
    D2 = clash.get("Device.IP.Interface.2.IPv4Address.1.AddressingType [string]", '').replace(" ","")
    D3 = clash.get("Device.IP.Interface.2.IPv4Address.1.IPAddress [string]", '').replace(" ","")
    D4 = clash.get("Device.IP.Interface.2.IPv4Address.1.Enable [boolean]", '').replace(" ","")
    D5 = clash.get("Device.IP.Interface.2.IPv4Address.1.SubnetMask [string]", '').replace(" ","")
    D6 = clash.get("Device.IP.Interface.2.IPv4Address.1.Alias [string]", '').replace(" ","")
    D7 = clash.get("Device.IP.Interface.2.IPv4Address.1.Status [string]", '').replace(" ","")
    E1 = subprocess.Popen("clash get Device.IP.Interface.3.IPv4Address.1.AddressingType", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.3.IPv4Address.1.AddressingType [string] =", '') #clash.get("Device.IP.Interface.3.IPv4Address.1.AddressingType [string]", '')
    E2 = subprocess.Popen("clash get Device.IP.Interface.2.IPv4Address.1.AddressingType", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.2.IPv4Address.1.AddressingType [string] =", '') #clash.get("Device.IP.Interface.3.IPv4Address.1.IPAddress [string]", '')
    E3 = clash.get("Device.IP.Interface.3.IPv4Address.1.Enable [boolean]", '').replace(" ","")
    E4 = subprocess.Popen("clash get Device.IP.Interface.3.IPv4Address.1.SubnetMask", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.3.IPv4Address.1.SubnetMask [string] =", '') #clash.get("Device.IP.Interface.3.IPv4Address.1.SubnetMask [string]", '')
    E5 = clash.get("Device.IP.Interface.3.IPv4Address.1.Alias [string]", '').replace(" ","")
    E6 = clash.get("Device.IP.Interface.3.IPv4Address.1.Status [string]", '').replace(" ","")
    F1 = clash.get("Device.IP.Interface.4.IPv4Address.1.AddressingType [string]", '').replace(" ","")
    F2 = clash.get("Device.IP.Interface.4.IPv4Address.1.IPAddress [string]", '').replace(" ","")
    F3 = clash.get("Device.IP.Interface.4.IPv4Address.1.Enable [boolean]", '').replace(" ","")
    F4 = clash.get("Device.IP.Interface.4.IPv4Address.1.SubnetMask [string]", '').replace(" ","")
    F5 = clash.get("Device.IP.Interface.4.IPv4Address.1.Alias [string]", '').replace(" ","")
    F6 = clash.get("Device.IP.Interface.4.IPv4Address.1.Status [string]", '').replace(" ","")
    G1 = clash.get("Device.IP.Interface.5.IPv4Address.1.AddressingType [string]", '').replace(" ","")
    G2 = clash.get("Device.IP.Interface.5.IPv4Address.1.IPAddress [string]", '').replace(" ","")
    G3 = clash.get("Device.IP.Interface.5.IPv4Address.1.Enable [boolean]", '').replace(" ","")
    G4 = clash.get("Device.IP.Interface.5.IPv4Address.1.SubnetMask [string]", '').replace(" ","")
    G5 = clash.get("Device.IP.Interface.5.IPv4Address.1.Alias [string]", '').replace(" ","")
    G6 = clash.get("Device.IP.Interface.5.IPv4Address.1.Status [string]", '').replace(" ","")
    #LOOPBACK
    H1 = clash.get("Device.IP.Interface.6.IPv4Address.1.AddressingType [string]", '').replace(" ","")
    H2 = clash.get("Device.IP.Interface.6.IPv4AddressNumberOfEntries [unsignedInt]", '').replace(" ","")
    H3 = clash.get("Device.IP.Interface.6.Enable [boolean]", '').replace(" ","")
    H4 = clash.get("Device.IP.Interface.6.Status [string]", '').replace(" ","")
    H5 = clash.get("Device.IP.Interface.6.IPv4Address.1.Alias [string]", '').replace(" ","")
    H6 = clash.get("Device.IP.Interface.6.IPv4Address.1.Status [string]", '').replace(" ","")
    #WAN 6
    I1 = subprocess.Popen("clash get Device.IP.Interface.7.LowerLayers", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.7.LowerLayers [string] =", '') #clash.get("Device.IP.Interface.7.LowerLayers [string] =").replace("\n","")
    I2 = clash.get("Device.IP.Interface.7.IPv4AddressNumberOfEntries [unsignedInt]").replace(" ","")
    I3 = clash.get("Device.IP.Interface.7.Enable [boolean]", '').replace(" ","")
    I4 = clash.get("Device.IP.Interface.7.Status [string]", '').replace(" ","")
    #SFS
    L1 = clash.get("Device.IP.Interface.8.IPv4Address.1.AddressingType [string]", '').replace(" ","")
    L2 = clash.get("Device.IP.Interface.8.IPv4AddressNumberOfEntries [unsignedInt]", '').replace(" ","")
    L3 = clash.get("Device.IP.Interface.8.Enable [boolean]", '').replace(" ","")
    L4 = clash.get("Device.IP.Interface.8.Status [string]", '').replace(" ","")
    L5 = clash.get("Device.IP.Interface.8.IPv4Address.1.Alias [string]", '').replace(" ","")
    L6 = clash.get("Device.IP.Interface.8.IPv4Address.1.Status [string]", '').replace(" ","")
    #PUBLIC LAN
    M1 = clash.get("Device.IP.Interface.9.IPv4Address.1.AddressingType [string]", '').replace(" ","")
    M2 = clash.get("Device.IP.Interface.9.IPv4AddressNumberOfEntries [unsignedInt]", '').replace(" ","")
    M3 = clash.get("Device.IP.Interface.9.Enable [boolean]", '').replace(" ","")
    M4 = clash.get("Device.IP.Interface.9.Status [string]", '').replace(" ","")
    M5 = clash.get("Device.IP.Interface.9.IPv4Address.1.Alias [string]", '').replace(" ","")
    M6 = clash.get("Device.IP.Interface.9.IPv4Address.1.Status [string]", '').replace(" ","")
    #FIREWALL
    N1 = clash_firewall.get("Device.Firewall.Enable [boolean]", '').replace(" ","")
    N2 = clash_firewall.get("Device.Firewall.Config [string]", '').replace(" ","")
    N3 = clash_firewall.get("Device.Firewall.AdvancedLevel [string]", '').replace(" ","")
    N4 = clash_firewall.get("Device.Firewall.X_000E50_EnableIPv6 [boolean]", '').replace(" ","")
    N5 = clash_firewall.get("Device.Firewall.LevelNumberOfEntries [unsignedInt]", '').replace(" ","")
    #IP
    O1 = clash.get("Device.IP.ActivePortNumberOfEntries [unsignedInt]", '').replace(" ","")
    O2 = clash.get("Device.IP.IPv6Capable [boolean]", '').replace(" ","")
    O3 = clash.get("Device.IP.IPv4Status [string]", '').replace(" ","")
    O4 = clash.get("Device.IP.IPv6Status [string]", '').replace(" ","")
    O5 = clash.get("Device.IP.IPv6Enable [boolean]", '').replace(" ","")
    O6 = clash.get("Device.IP.InterfaceNumberOfEntries [unsignedInt]", '').replace(" ","")
    O7 = clash.get("Device.IP.IPv4Capable [boolean]", '').replace(" ","")
    O8 = clash.get("Device.IP.X_000E50_ReleaseRenewWAN [boolean]", '').replace(" ","")
    O9 = clash.get("Device.IP.ULAPrefix [string]", '').replace(" ","")
    O10 = clash.get("Device.IP.IPv4Enable [boolean]", '').replace(" ","")
    #HOST
    P1 = clash.get("Device.Hosts.HostNumberOfEntries [unsignedInt]", '').replace(" ","")
    #NAT
    Q1 = clash.get("Device.NAT.InterfaceSettingNumberOfEntries [unsignedInt]", '').replace(" ","")
    Q2 = clash.get("Device.NAT.PortMappingNumberOfEntries [unsignedInt]", '').replace(" ","")
    #DHCPv4
    R1 = clash.get("Device.DHCPv4.Server.Enable [boolean]", '').replace(" ","")
    R2 = clash.get("Device.DHCPv4.Server.PoolNumberOfEntries [unsignedInt]", '').replace(" ","")
    R3 = clash.get("Device.DHCPv4.Server.Pool.1.StaticAddressNumberOfEntries [unsignedInt]", '').replace(" ","")
    R4 = clash.get("Device.DHCPv4.Server.Pool.1.Enable [boolean]", '').replace(" ","")
    R5 = clash.get("Device.DHCPv4.Server.Pool.1.ClientNumberOfEntries [unsignedInt]", '').replace(" ","")
    R6 = clash.get("Device.DHCPv4.Server.Pool.1.LeaseTime [int]", '').replace(" ","")
    R7 = clash.get("Device.DHCPv4.Server.Pool.1.Status [string]", '').replace(" ","")
    R8 = clash.get("Device.DHCPv4.Server.Pool.1.UserClassIDExclude [boolean]", '').replace(" ","")
    R9 = clash.get("Device.DHCPv4.Server.Pool.1.MaxAddress [string]", '').replace(" ","")
    R10 = clash.get("Device.DHCPv4.Server.Pool.1.VendorClassIDExclude [boolean]", '').replace(" ","")
    R11 = clash.get("Device.DHCPv4.Server.Pool.1.SubnetMask [string]", '').replace(" ","")
    R12 = clash.get("Device.DHCPv4.Server.Pool.1.IPRouters [string]", '').replace(" ","")
    R13 = clash.get("Device.DHCPv4.Server.Pool.1.MinAddress [string]", '').replace(" ","")
    R14 = clash.get("Device.DHCPv4.Server.Pool.1.ChaddrExclude [boolean]", '').replace(" ","")
    R15 = clash.get("Device.DHCPv4.Server.Pool.1.DNSServers [string]", '').replace(" ","")
    R16 = clash.get("Device.DHCPv4.Server.Pool.1.DomainName [string]", '').replace(" ","")
    R17 = clash.get("Device.DHCPv4.Server.Pool.2.StaticAddressNumberOfEntries [unsignedInt]", '').replace(" ","")
    R18 = clash.get("Device.DHCPv4.Server.Pool.2.Enable [boolean]", '').replace(" ","")
    R19 = clash.get("Device.DHCPv4.Server.Pool.2.ClientNumberOfEntries [unsignedInt]", '').replace(" ","")
    R20 = clash.get("Device.DHCPv4.Server.Pool.2.LeaseTime [int]", '').replace(" ","")
    R21 = clash.get("Device.DHCPv4.Server.Pool.2.Status [string]", '').replace(" ","")
    R22 = clash.get("Device.DHCPv4.Server.Pool.2.UserClassIDExclude [boolean]", '').replace(" ","")
    R23 = clash.get("Device.DHCPv4.Server.Pool.2.MaxAddress [string]", '').replace(" ","")
    R24 = clash.get("Device.DHCPv4.Server.Pool.2.VendorClassIDExclude [boolean]", '').replace(" ","")
    R25 = clash.get("Device.DHCPv4.Server.Pool.2.SubnetMask [string]", '').replace(" ","")
    R26 = clash.get("Device.DHCPv4.Server.Pool.2.IPRouters [string]", '').replace(" ","")
    R27 = clash.get("Device.DHCPv4.Server.Pool.2.MinAddress [string]", '').replace(" ","")
    R28 = clash.get("Device.DHCPv4.Server.Pool.2.ChaddrExclude [boolean]", '').replace(" ","")
    R29 = clash.get("Device.DHCPv4.Server.Pool.2.DNSServers [string]", '').replace(" ","")
    R30 = clash.get("Device.DHCPv4.Server.Pool.2.DomainName [string]", '').replace(" ","")
    R31 = clash.get("Device.DHCPv4.Server.Pool.2.StaticAddressNumberOfEntries [unsignedInt]", '').replace(" ","")
    R32 = clash.get("Device.DHCPv4.Server.Pool.3.Enable [boolean]", '').replace(" ","")
    R33 = clash.get("Device.DHCPv4.Server.Pool.3.ClientNumberOfEntries [unsignedInt]", '').replace(" ","")
    R34 = clash.get("Device.DHCPv4.Server.Pool.3.LeaseTime [int]", '').replace(" ","")
    R35 = clash.get("Device.DHCPv4.Server.Pool.3.Status [string]", '').replace(" ","")
    R36 = clash.get("Device.DHCPv4.Server.Pool.3.UserClassIDExclude [boolean]", '').replace(" ","")
    R37 = clash.get("Device.DHCPv4.Server.Pool.3.MaxAddress [string]", '').replace(" ","")
    R38 = clash.get("Device.DHCPv4.Server.Pool.3.VendorClassIDExclude [boolean]", '').replace(" ","")
    R39 = clash.get("Device.DHCPv4.Server.Pool.3.SubnetMask [string]", '').replace(" ","")
    R40 = clash.get("Device.DHCPv4.Server.Pool.3.IPRouters [string]", '').replace(" ","")
    R41 = clash.get("Device.DHCPv4.Server.Pool.3.MinAddress [string]", '').replace(" ","")
    R42 = clash.get("Device.DHCPv4.Server.Pool.3.ChaddrExclude [boolean]", '').replace(" ","")
    R43 = clash.get("Device.DHCPv4.Server.Pool.3.DNSServers [string]", '').replace(" ","")
    R44 = clash.get("Device.DHCPv4.Server.Pool.3.DomainName [string]", '').replace(" ","")
    # DHCP v6
    S1 = clash.get("Device.DHCPv6.Server.Enable [boolean]", '').replace(" ","")
    S2 = clash.get("Device.DHCPv6.Server.PoolNumberOfEntries [unsignedInt]", '').replace(" ","")
    S3 = clash.get("Device.DHCPv6.Server.Pool.1.StaticAddressNumberOfEntries [unsignedInt]", '').replace(" ","")
    S4 = clash.get("Device.DHCPv6.Server.Pool.1.Status [string]", '').replace(" ","")
    S5 = clash.get("Device.DHCPv6.Server.Pool.1.Enable [boolean]", '').replace(" ","")
    S6 = clash.get("Device.DHCPv6.Server.Pool.2.PoolNumberOfEntries [unsignedInt]", '').replace(" ","")
    S7 = clash.get("Device.DHCPv6.Server.Pool.2.Status [string]", '').replace(" ","")
    S8 = clash.get("Device.DHCPv6.Server.Pool.2.Enable [boolean]", '').replace(" ","")
    S9 = clash.get("Device.DHCPv6.Server.Pool.3.PoolNumberOfEntries [unsignedInt]", '').replace(" ","")
    S10 = clash.get("Device.DHCPv6.Server.Pool.3.Status [string]", '').replace(" ","")
    S11 = clash.get("Device.DHCPv6.Server.Pool.3.Enable [boolean]", '').replace(" ","")
    #SAMBA
    T1 = uci_show_samba.get("samba.samba.workgroup", '').replace(" ","")
    T2 = uci_show_samba.get("samba.samba.configsdir", '').replace(" ","")
    T3 = uci_show_samba.get("samba.samba.homes", '').replace(" ","")
    T4 = uci_show_samba.get("samba.samba.enabled", '').replace(" ","")
    T5 = uci_show_samba.get("samba.samba.filesharing", '').replace(" ","")
    T6 = uci_show_samba.get("samba.samba.charset", '').replace(" ","")
    T7 = uci_show_samba.get("samba.samba.printcap_cache_time", '').replace(" ","")
    T8 = uci_show_samba.get("samba.samba.name", '').replace(" ","")
    T9 = uci_show_samba.get("samba.samba.description", '').replace(" ","")
    #USB
    U1 = clash.get("Device.USB.PortNumberOfEntries [unsignedInt]", '').replace(" ","")
    U2 = clash.get("Device.USB.USBHosts.HostNumberOfEntries [unsignedInt]", '').replace(" ","")
    U3 = clash.get("Device.USB.Port.1.Standard [string]", '').replace(" ","")
    U4 = clash.get("Device.USB.Port.1.Name [string]", '').replace(" ","")
    U5 = clash.get("Device.USB.Port.1.Rate [string]", '').replace(" ","")
    U6 = clash.get("Device.USB.Port.2.Standard [string]", '').replace(" ","")
    U7 = clash.get("Device.USB.Port.2.Name [string]", '').replace(" ","")
    U8 = clash.get("Device.USB.Port.2.Rate [string]", '').replace(" ","")
    #PRINTING SHARING
    V1 = uci_show_printersharing.get("printersharing.config.enabled", '')
    V2 = uci_show_printersharing.get("printersharing.00CNC2739952.name", '')    ########### DA RIVEDERE
    V3 = uci_show_printersharing.get("printersharing.00CNC2739952.uri", '')    ########### DA RIVEDERE
    V4 = uci_show_printersharing.get("printersharing.00CNC2739952.offline", '')    ########### DA RIVEDERE
    #V1 = subprocess.Popen("uci get env.var.company_name -q", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    #V2 = subprocess.Popen("uci get env.var.company_name -q", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    #V3 = subprocess.Popen("uci get env.var.company_name -q", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    #V4 = ubprocess.Popen("uci get env.var.company_name -q", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    #STORAGE
    W1 = clash.get("Device.StorageService.1.Enable [boolean]", '').replace(" ","")
    W2 = clash.get("Device.StorageServiceNumberOfEntries [unsignedInt]", '').replace(" ","")
    #WIFI_2G
    X1 = clash.get("Device.WiFi.SSID.1.Enable [boolean]", '').replace(" ","")
    X2 = clash.get("Device.WiFi.SSID.1.MACAddress [string]", '').replace(" ","")
    X3 = clash.get("Device.WiFi.SSID.1.SSID [string]", '').replace(" ","")
    X4 = clash.get("Device.WiFi.SSID.1.Status [string]", '').replace(" ","")
    X5 = clash.get("Device.WiFi.AccessPoint.1.WPS.Enable [boolean]", '').replace(" ","")
    X6 = clash.get("Device.WiFi.SSID.3.Enable [boolean]", '').replace(" ","")
    X7 = clash.get("Device.WiFi.SSID.3.MACAddress [string]", '').replace(" ","")
    X8 = clash.get("Device.WiFi.SSID.3.SSID [string]", '').replace(" ","")
    X9 = clash.get("Device.WiFi.SSID.3.Status [string]", '').replace(" ","")
    X10 = clash.get("Device.WiFi.AccessPoint.3.WPS.Enable [boolean]", '').replace(" ","")
    #WIFI_5G
    Y1 = clash.get("Device.WiFi.SSID.2.Enable [boolean]", '').replace(" ","")
    Y2 = clash.get("Device.WiFi.SSID.2.MACAddress [string]", '').replace(" ","")
    Y3 = clash.get("Device.WiFi.SSID.2.SSID [string]", '').replace(" ","")
    Y4 = clash.get("Device.WiFi.SSID.2.Status [string]", '').replace(" ","")
    Y5 = clash.get("Device.WiFi.AccessPoint.2.WPS.Enable [boolean]", '').replace(" ","")
    Y6 = clash.get("Device.WiFi.SSID.4.Enable [boolean]", '').replace(" ","")
    Y7 = clash.get("Device.WiFi.SSID.4.MACAddress [string]", '').replace(" ","")
    Y8 = clash.get("Device.WiFi.SSID.4.SSID [string]", '').replace(" ","")
    Y9 = clash.get("Device.WiFi.SSID.4.Status [string]", '').replace(" ","")
    Y10 = clash.get("Device.WiFi.AccessPoint.4.WPS.Enable [boolean]", '').replace(" ","")
    #MOBILE
    Z1 = clash_rpc.get("rpc.mobiled.DeviceNumberOfEntries [unsignedInt]", '').replace(" ","")
    Z2 = clash_rpc.get("rpc.mobiled.device.@1.status [string]", '').replace(" ","")
    Z3 = clash_rpc.get("rpc.mobiled.device.@1.info.manufacturer [string]", '').replace(" ","")
    Z4 = clash_rpc.get("rpc.mobiled.device.@1.info.model [string]", '').replace(" ","")
    Z5 = clash_rpc.get("rpc.mobiled.device.@1.info.imei [string]", '').replace(" ","")
    Z6 = clash_rpc.get("rpc.mobiled.device.@1.sim.imsi [string]", '').replace(" ","")
    Z7 = clash_rpc.get("rpc.mobiled.device.@1.sim.iccid [string]", '').replace(" ","")
    Z8 = clash_rpc.get("rpc.mobiled.device.@1.network.serving_system.nas_state [string]", '').replace(" ","")
    Z9 = clash_rpc.get("rpc.mobiled.device.@1.ProfileNumberOfEntries [unsignedInt]", '').replace(" ","")
    Z10 = clash_rpc.get("rpc.mobiled.device.@1.profile.@1.apn [string]", '').replace(" ","")

    ## CONFIG OPTICAL
    AA1 = clash.get("Device.Optical.Interface.1.Status [string]", '').replace(" ","")
    AA2 = clash.get("Device.Optical.Interface.1.VendorName [string]", '').replace(" ","")
    AA3 = clash.get("Device.Optical.Interface.1.Enable [boolean]", '').replace(" ","")

    ## CONFIG BandSteer
    result = get_band_steer()
    AA4 = 'bs0'
    AA5 = result.get('admin_state')
    AA6 = result.get('oper_state')
    AA7 = result.get('linked_aps')
    AA8 = result.get('policy_mode')
    AA9 = result.get('monitor_window')
    AA10 = result.get('rssi_threshold')
    AA11 = result.get('rssi_5g_threshold')
    AA12 = result.get('sta_comeback_to')
    AA13 = result.get('history_window')
    AA14 = result.get('debug_flags')
    AA15 = result.get('max_graceful_roam_time')
    AA16 = result.get('macacl_deauth_enabled')
    AA17 = result.get('no_powersave_steer')
    AA18 = result.get('sta_acl_to')

    ## CONFIG ACS_2G
    result = get_band_acs_2g()
    #print(result)
    AA19 = result.get('state')
    AA20 = result.get('policy')
    AA21 = result.get('rescan_period')
    AA22 = result.get('rescan_delay')
    AA23 = result.get('rescan_delay_policy')
    AA24 = result.get('rescan_delay_max_events')
    AA25 = result.get('channel_monitor_period')
    AA26 = result.get('channel_monitor_action')
    AA27 = result.get('channel_fail_trigger_valid')
    AA28 = result.get('channel_fail_max_events')
    AA29 = result.get('channel_lockout_period')
    AA30 = result.get('tx_traffic_threshold')
    AA31 = result.get('rx_traffic_threshold')
    AA32 = result.get('traffic_sense_period')
    AA33 = result.get('interference_span')
    AA34 = result.get('no_restrict_align')
    AA35 = result.get('channel_noise_threshold ')   # TRAILING SPACE NEEDED !
    AA36 = result.get('channel_score_threshold')
    AA37 = result.get('quick_scan')
    AA38 = result.get('non_dfs_fallback')
    AA39 = result.get('ctrl_chan_adjust')
    AA40 = result.get('trace_level')
    AA41 = result.get('chanim_tracing')
    AA42 = result.get('traffic_tracing')
    AA43 = result.get('allowed_channels')
    AA44 = result.get('max_records')
    AA45 = result.get('record_changes_only')
    AA46 = result.get('dfs_reentry')
    AA47 = result.get('bgdfs_preclearing')
    AA48 = result.get('bgdfs_avoid_on_far_sta')
    AA49 = result.get('bgdfs_far_sta_rssi')
    AA50 = result.get('bgdfs_tx_time_threshold')
    AA51 = result.get('bgdfs_rx_time_threshold')
    AA52 = result.get('bgdfs_traffic_sense_period')

    ## CONFIG ACS_5G
    result = get_band_acs_5g()
    #print(result)
    AA53 = result.get('state')
    AA54 = result.get('policy')
    AA55 = result.get('rescan_period')
    AA56 = result.get('rescan_delay')
    AA57 = result.get('rescan_delay_policy')
    AA58 = result.get('rescan_delay_max_events')
    AA59 = result.get('channel_monitor_period')
    AA60 = result.get('channel_monitor_action')
    AA61 = result.get('channel_fail_trigger_valid')
    AA62 = result.get('channel_fail_max_events')
    AA63 = result.get('channel_lockout_period')
    AA64 = result.get('tx_traffic_threshold')
    AA65 = result.get('rx_traffic_threshold')
    AA66 = result.get('traffic_sense_period')
    AA67 = result.get('interference_span')
    AA68 = result.get('no_restrict_align')
    AA69 = result.get('channel_noise_threshold ') # TRAILING SPACE NEEDED !
    AA70 = result.get('channel_score_threshold')
    AA71 = result.get('quick_scan')
    AA72 = result.get('non_dfs_fallback')
    AA73 = result.get('ctrl_chan_adjust')
    AA74 = result.get('trace_level')
    AA75 = result.get('chanim_tracing')
    AA76 = result.get('traffic_tracing')
    AA77 = result.get('allowed_channels')
    AA78 = result.get('max_records')
    AA79 = result.get('record_changes_only')
    AA80 = result.get('dfs_reentry')
    AA81 = result.get('bgdfs_preclearing')
    AA82 = result.get('bgdfs_avoid_on_far_sta')
    AA83 = result.get('bgdfs_far_sta_rssi')
    AA84 = result.get('bgdfs_tx_time_threshold')
    AA85 = result.get('bgdfs_rx_time_threshold')
    AA86 = result.get('bgdfs_traffic_sense_period')
   
    

    dict_config = {"config":
                    {"lan": {"C1": C1, "C2": C2, "C4": int(C4), "C5": C5,"C6": C6, "C7": C7},
                     "wan": {"D1": D1, "D2": D2, "D3": D3,"D4": int(D4), "D5": D5, "D6": D6, "D7": D7},
                     "wwan": {"E1": E1, "E2": E2, "E3": int(E3),"E4": E4, "E5": E5, "E6": E6},
                     "wlnet_b_24": {"F1": F1, "F2": F2, "F3": int(F3),"F4": F4, "F5": F5, "F6": F6},
                     "wlnet_b_5": {"G1": G1, "G2": G2, "G3": int(G3),"G4": G4, "G5": G5, "G6": G6},
                     "loopback": {"H1": H1, "H2": H2, "H3": int(H3),"H4": H4, "H5": H5, "H6": H6},
                     "wan6": {"I1": I1, "I2": I2, "I3": int(I3),"I4": I4},
                     "sfs": {"L1": L1, "L2": L2, "L3": int(L3),"L4": L4, "L5": L5, "L6": L6},
                     "public_lan": {"M1": M1, "M2": M2, "M3": int(M3), "M4": M4, "M5": M5,"M6": M6},
                     "firewall": {"N1":int(N1),"N2":N2,"N3":N3,"N4":int(N4),"N5":int(N5)},
                     "ip":{"O1":int(O1),"O2":int(O2),"O3":O3,"O4":O4,"O5":int(O5),"O6":int(O6),"O7":int(O7),"O8":int(O8),"O9":O9,"10":int(O10)},
                     "host":{"P1":P1},
                     "dhcpv4":{"R1":R1,"R2":R2,"R3":R3,"R4":R4,"R5":R5,"R6":R6,"R7":R7,"R8":R8,"R9":R9,"R10":R10,"R11":R11,"R12":R12,"R13":R13,"R14":R14,"R15":R15,"R16":R16,"R17":R17,"R18":R18,"R19":R19,"R20":R20,"R21":R22,"R23":R23,"R24":R24,"R25":R25,"R26":R26,"R27":R27,"R28":R28,"R29":R29,"R30":R30,"R31":R31,"R32":R32,"R33":R33,"R34":R34,"R35":R35,"R36":R36,"R37":R37,"R38":R38,"R39":R39,"R40":R40,"R41":R41,"R42":R42,"R43":R43,"R44":R44},
                     "dhcpv6":{"S1":S1,"S2":S2,"S3":S3,"S4":S4,"S5":S5,"S6":S6,"S7":S7,"S8":S8,"S9":S9,"S10":S10,"S11":S11},
                     "samba":{"T1":T1,"T2":T2,"T3":T3,"T4":T4,"T5":T5,"T6":T6,"T7":T7,"T8":T8,"T9":T9},
                     "usb":{"U1":U1,"U2":U2,"U3":U3,"U4":U4,"U5":U5,"U6":U6,"U7":U7,"U8":U8},
                     "printingsharing":{"V1":V1,"V2":V2,"V3":V3,"V4":V4},
                     "storage":{"W1":W1,"W2":W2},
                     "wifi_2g":{"X1":X1,"X2":X2,"X3":X3,"X4":X4,"X5":X5,"X6":X6,"X7":X7,"X8":X8,"X9":X9,"X10":X10},
                     "wifi_5g":{"Y1":Y1,"Y2":Y2,"Y3":Y3,"Y4":Y4,"Y5":Y5,"Y6":Y6,"Y7":Y7,"Y8":Y8,"Y9":Y9,"Y10":Y10},
                     "mobile":{"Z1":Z1,"Z2":Z2,"Z3":Z3,"Z4":Z4,"Z5":Z5,"Z6":Z6,"Z7":Z7,"Z8":Z8,"Z9":Z9,"Z10":Z10},
                     "optical":{"AA1":AA1,"AA2":AA2,"AA3":AA3},
                     "bandsteer":{"AA5":AA5,"AA6":AA6,"AA7":AA7,"AA8":AA8,"AA9":AA9,"AA10":AA10,"AA11":AA11,"AA12":AA12,"AA13":AA13,"AA14":AA14,"AA15":AA15,"AA16":AA16,"AA17":AA17,"AA18":AA18},
                     "acs_2g":{"AA19":AA19,"AA20":AA20,"AA21":AA21,"AA22":AA22,"AA23":AA23,"AA24":AA24,"AA25":AA25,"AA26":AA26,"AA27":AA27,"AA28":AA28,"AA29":AA29,"AA30":AA30,"AA31":AA31,"AA32":AA32,"AA33":AA34,"AA35":AA35,"AA36":AA36,"AA37":AA37,"AA38":AA38,"AA39":AA39,"AA40":AA40,"AA41":AA41,"AA42":AA42,"AA43":AA43,"AA44":AA44,"AA45":AA45,"AA46":AA46,"AA47":AA47,"AA48":AA48,"AA49":AA49,"AA50":AA50,"AA51":AA51,"AA52":AA52},
                     "acs_5g":{"AA53":AA53,"AA54":AA54,"AA55":AA55,"AA56":AA56,"AA57":AA57,"AA58":AA58,"AA59":AA59,"AA60":AA60,"AA61":AA61,"AA62":AA62,"AA63":AA63,"AA64":AA64,"AA65":AA65,"AA66":AA66,"AA67":AA67,"AA68":AA68,"AA69":AA69,"AA70":AA70,"AA71":AA71,"AA72":AA72,"AA73":AA73,"AA74":AA74,"AA75":AA75,"AA76":AA76,"AA77":AA77,"AA78":AA78,"AA79":AA79,"AA80":AA80,"AA81":AA81,"AA82":AA82,"AA83":AA83,"AA84":AA84,"AA85":AA85,"AA86":AA86}
            }}
    return (json.dumps(dict_config))

def uci_show(command):
    tracer.Info("datamodel.uci_show - Before subprocess.Popen")
    show_cwmpd = subprocess.Popen("uci show "+str(command), shell=True,stdout=subprocess.PIPE,universal_newlines=True).stdout.readlines()
    tracer.Info("datamodel.uci_show - After subprocess.Popen")
    show_cwmpd = [x.strip() for x in show_cwmpd if x.strip()]
    show_cwmpd = str(show_cwmpd).replace("', '","','") #.replace("[","").replace("]","")
    uci_show = {}
    testarray = ast.literal_eval(show_cwmpd)
    for x in testarray:
        key = x.split('=', 1)
        key_clean = key[0]
        value = x.split('=', 1)
        value_clean = value[-1]
        uci_show.update({key_clean: value_clean})
    
    return uci_show


def clash_get(command):
    tracer.Info("datamodel.transformer-cli_get - Before subprocess.Popen")
    clash_device = subprocess.Popen("transformer-cli get "+str(command), shell=True,stdout=subprocess.PIPE,universal_newlines=True).stdout.readlines()
    tracer.Info("datamodel.transformer-cli_get - After subprocess.Popen")
    clash_device = [x.strip() for x in clash_device if x.strip()]
    clash_device = str(clash_device).replace("', '","','") #.replace("[","").replace("]","")
    json_clash_rpc_system = {}
    testarray = ast.literal_eval(clash_device)
    for x in testarray:
        key = x.split(' =', 1)
        key_clean = key[0]
        value = x.split('=', 1)
        value_clean = value[-1]
        json_clash_rpc_system.update({key_clean: value_clean})
    return json_clash_rpc_system



def get_band_steer():
    tracer.Info("datamodel.get_band_steer - Before subprocess.Popen")
    band_steer =subprocess.Popen("ubus call wireless.bandsteer get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_band_steer - After subprocess.Popen")
    #print(type(band_steer))
    obj = json.loads(band_steer)
    bs0 = obj.get('bs0')
    #print(bs0)
    return bs0


def get_band_acs_2g():
    tracer.Info("datamodel.get_band_acs_2g - Before subprocess.Popen")
    band_steer =subprocess.Popen("ubus call wireless.radio.acs get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_band_acs_2g - After subprocess.Popen")
    #print(type(band_steer))
    obj = json.loads(band_steer)
    radio_2G = obj.get('radio_2G')
    #print(radio_2G)
    return radio_2G

def get_band_acs_5g():
    tracer.Info("datamodel.get_band_acs_5g - Before subprocess.Popen")
    band_steer =subprocess.Popen("ubus call wireless.radio.acs get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_band_acs_5g - After subprocess.Popen")
    #print(type(band_steer))
    obj = json.loads(band_steer)
    radio_5G = obj.get('radio_5G')
    #print(radio_5G)
    return radio_5G

def get_NeighboringWiFi():
    #tracer.Info("datamodel.get_ubus_NeighboringWiFi - rescan - Before subprocess.Popen")
    #result =subprocess.Popen('ubus call wireless.radio.acs rescan \'{"name":"radio_2G","act":0}\'', shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    #result =subprocess.Popen('ubus call wireless.radio.acs rescan \'{"name":"radio_5G","act":0}\'', shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    #tracer.Info("datamodel.get_ubus_NeighboringWiFi - rescan - After subprocess.Popen")
    
    tracer.Info("datamodel.get_ubus_NeighboringWiFi - get bsslist- Before subprocess.Popen")
    json_NeighboringWiFi =subprocess.Popen("ubus call wireless.radio.bsslist get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_ubus_NeighboringWiFi - get bsslist- After subprocess.Popen")
    #print(type(ubus_data))
    dict_NeighboringWiFi = json.loads(json_NeighboringWiFi)
    #bs0 = obj.get('bs0')
    #print(bs0)
    return dict_NeighboringWiFi

def get_radio_2g():
    tracer.Info("datamodel.get_ubus_radio_2g - Before subprocess.Popen")
    result =subprocess.Popen("ubus call wireless.radio get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_ubus_radio_2g - After subprocess.Popen")
    #print(type(result))
    obj = json.loads(result)
    radio_2G = obj.get('radio_2G')
    #print(radio_2G)
    return radio_2G

def get_radio_5g():
    tracer.Info("datamodel.get_ubus_radio_5g - Before subprocess.Popen")
    result =subprocess.Popen("ubus call wireless.radio get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_ubus_radio_5g - After subprocess.Popen")
    #print(type(result))
    obj = json.loads(result)
    radio_5G = obj.get('radio_5G')
    #print(radio_2G)
    return radio_5G

def get_radio_stats_2g():
    tracer.Info("datamodel.get_ubus_radio_stats_2g - Before subprocess.Popen")
    result =subprocess.Popen("ubus call wireless.radio.acs.channel_stats get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_ubus_radio_stats_2g - After subprocess.Popen")
    #print(type(result))
    obj = json.loads(result)
    radio_2G = obj.get('radio_2G')
    #print(radio_2G)
    return radio_2G

def get_radio_stats_5g():
    tracer.Info("datamodel.get_ubus_radio_stats_5g - Before subprocess.Popen")
    result =subprocess.Popen("ubus call wireless.radio.acs.channel_stats get", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip() 
    tracer.Info("datamodel.get_ubus_radio_stats_5g - After subprocess.Popen")
    #print(type(result))
    obj = json.loads(result)
    radio_5G = obj.get('radio_5G')
    #print(radio_2G)
    return radio_5G
