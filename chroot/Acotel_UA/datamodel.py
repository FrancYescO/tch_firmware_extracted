#
# Acotel_UA
#
# datamodel.py  
#
# Last update : 2020-10-30
#

import json
import subprocess
import asyncio
import ast

import TRACER as tracer

#
#
#   get_telemetries()
#
#
async def get_telemetries():
    # COMMANDI STRING
    command_clash = 'Device.'

    # FUNZIONI CLASH
    clash = clash_get(command_clash)
    
    # PERFORMANCE
    AB1 = clash.get("Device.DeviceInfo.MemoryStatus.X_000E50_MemoryUtilization [string]", '')
    AB2 = clash.get("Device.DeviceInfo.MemoryStatus.Free [unsignedInt]", '')
    AB3 = clash.get("Device.DeviceInfo.ProcessStatus.ProcessNumberOfEntries [unsignedInt]", '')
    AB4 = clash.get("Device.DeviceInfo.ProcessStatus.CPUUsage [unsignedInt]", '')
    AB5 = subprocess.Popen("mpstat | awk 'NR == 4 {print $3}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB6 = subprocess.Popen("mpstat | awk 'NR == 4 {print $4}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB7 = subprocess.Popen("mpstat | awk 'NR == 4 {print $5}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB8 = subprocess.Popen("mpstat | awk 'NR == 4 {print $6}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB9 = subprocess.Popen("mpstat | awk 'NR == 4 {print $7}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB10 = subprocess.Popen("mpstat | awk 'NR == 4 {print $8}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB11 = subprocess.Popen("mpstat | awk 'NR == 4 {print $9}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB12 = subprocess.Popen("mpstat | awk 'NR == 4 {print $10}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AB13 = subprocess.Popen("mpstat | awk 'NR == 4 {print $11}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()


    AC1 = subprocess.Popen("ping  -c 5 8.8.8.8 |grep 'round-trip min/avg/max' | awk 'NR == 1 {print $4}' | awk -F'/' '{print $1}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AC2 = subprocess.Popen("ping  -c 5 8.8.8.8 |grep 'round-trip min/avg/max' | awk 'NR == 1 {print $4}' | awk -F'/' '{print $2}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    AC3 = subprocess.Popen("ping  -c 5 8.8.8.8 |grep 'round-trip min/avg/max' | awk 'NR == 1 {print $4}' | awk -F'/' '{print $3}'", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip()
    
    AF1 = clash.get("Device.DSL.Line.1.DownstreamMaxBitRate [unsignedInt]", '')
    AF2 = clash.get("Device.DSL.Line.1.UpstreamMaxBitRate [unsignedInt]", '')
    AF3 = clash.get("Device.DSL.Line.1.SNRMpbus [string]", '')
    AF4 = clash.get("Device.DSL.Line.1.SNRMpbds [string]", '')
    AF5 = clash.get("Device.DSL.Line.1.X_000E50_UpstreamAttenuation [string]", '')
    AF6 = clash.get("Device.DSL.Line.1.X_000E50_DownstreamAttenuation [string]", '')
    AF7 = clash.get("Device.DSL.Line.1.UpstreamPower [int]", '')
    AF8 = clash.get("Device.DSL.Line.1.DownstreamPower [int", '')

    AG1 = clash.get("Device.Optical.Interface.1.UpperOpticalThreshold [int]", '')
    AG2 = clash.get("Device.Optical.Interface.1.LastChange [unsignedInt]", '')
    AG3 = clash.get("Device.Optical.Interface.1.Stats.ErrorsReceived [unsignedInt]", '')
    AG4 = clash.get("Device.Optical.Interface.1.Stats.ErrorsSent [unsignedInt]", '')
    AG5 = clash.get("Device.Optical.Interface.1.Stats.BytesReceived [unsignedLong]", '')
    AG6 = clash.get("Device.Optical.Interface.1.Stats.DiscardPacketsSent [unsignedInt]", '')
    AG7 = clash.get("Device.Optical.Interface.1.Stats.PacketsSent [unsignedLong]", '')
    AG8 = clash.get("Device.Optical.Interface.1.Stats.BytesSent [unsignedLong]", '')
    AG9 = clash.get("Device.Optical.Interface.1.Stats.PacketsReceived [unsignedLong]", '')
    AG10 = clash.get("Device.Optical.Interface.1.Stats.DiscardPacketsReceived [unsignedInt]", '')
    AG11 = clash.get("Device.Optical.Interface.1.Stats.reset [boolean]", '')
    
    AH1 = clash.get("Device.Ethernet.Interface.5.Stats.UnknownProtoPacketsReceived [unsignedInt]", '')
    AH2 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsReceived [unsignedInt]", '')
    AH3 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsReceived [unsignedInt]", '')
    AH4 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsSent [unsignedLong]", '')
    AH5 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsReceived [unsignedLong]", '')
    AH6 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsSent [unsignedLong]", '')
    AH7 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsSent [unsignedInt]", '')
    AH8 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsReceived [unsignedLong]", '')
    AH9 = clash.get("Device.Ethernet.Interface.5.Stats.BytesReceived [unsignedLong]", '')
    AH10 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsSent [unsignedInt]", '')
    AH11 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsSent [unsignedLong]", '')
    AH12 = clash.get("Device.Ethernet.Interface.5.Stats.BytesSent [unsignedLong]", '')
    AH13 = clash.get("Device.Ethernet.Interface.5.Stats.PacketsReceived [unsignedLong]", '')
    AH14 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsReceived [unsignedLong]", '')
    AH15 = clash.get("Device.Ethernet.Interface.5.Stats.PacketsSent [unsignedLong]", '')

    AI1 = clash.get("Device.Ethernet.Interface.5.Stats.UnknownProtoPacketsReceived [unsignedInt]", '')
    AI2 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsReceived [unsignedInt]", '')
    AI3 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsReceived [unsignedInt]", '')
    AI4 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsSent [unsignedLong]", '')
    AI5 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsReceived [unsignedLong]", '')
    AI6 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsSent [unsignedLong]", '')
    AI7 = clash.get("Device.Ethernet.Interface.5.Stats.ErrorsSent [unsignedInt]", '')
    AI8 = clash.get("Device.Ethernet.Interface.5.Stats.UnicastPacketsReceived [unsignedLong]", '')
    AI9 = clash.get("Device.Ethernet.Interface.5.Stats.BytesReceived [unsignedLong]", '')
    AI10 = clash.get("Device.Ethernet.Interface.5.Stats.DiscardPacketsSent [unsignedInt]", '')
    AI11 = clash.get("Device.Ethernet.Interface.5.Stats.MulticastPacketsSent [unsignedLong]", '')
    AI12 = clash.get("Device.Ethernet.Interface.5.Stats.BytesSent [unsignedLong]", '')
    AI13 = clash.get("Device.Ethernet.Interface.5.Stats.PacketsReceived [unsignedLong]", '')
    AH14 = clash.get("Device.Ethernet.Interface.5.Stats.BroadcastPacketsReceived [unsignedLong]", '')

    AI1 = clash.get("Device.WiFi.SSID.1.Stats.ErrorsReceived [unsignedInt]", '')
    AI2 = clash.get("Device.WiFi.SSID.1.Stats.AggregatedPacketCount [unsignedInt]", '')
    AI3 = clash.get("Device.WiFi.SSID.1.Stats.BroadcastPacketsSent [unsignedLong]", '')
    AI4 = clash.get("Device.WiFi.SSID.1.Stats.MulticastPacketsReceived [unsignedLong]", '')
    AI5 = clash.get("Device.WiFi.SSID.1.Stats.UnicastPacketsReceived [unsignedLong]", '')
    AI6 = clash.get("Device.WiFi.SSID.1.Stats.DiscardPacketsReceived [unsignedInt]", '')
    AI7 = clash.get("Device.WiFi.SSID.1.Stats.ErrorsSent [unsignedInt]", '')
    AI8 = clash.get("Device.WiFi.SSID.1.Stats.DiscardPacketsSent [unsignedInt]", '')
    AI9 = clash.get("Device.WiFi.SSID.1.Stats.BytesReceived [unsignedLong]", '')
    AI10 = clash.get("Device.WiFi.SSID.1.Stats.UnicastPacketsSent [unsignedLong]", '')
    AI11 = clash.get("Device.WiFi.SSID.1.Stats.MulticastPacketsSent [unsignedLong]", '')
    AI12 = clash.get("Device.WiFi.SSID.1.Stats.BytesSent [unsignedLong]", '')
    AI13 = clash.get("Device.WiFi.SSID.1.Stats.PacketsReceived [unsignedLong]", '')
    AI14 = clash.get("Device.WiFi.SSID.1.Stats.BroadcastPacketsReceived [unsignedLong]", '')
    AI15 = clash.get("Device.WiFi.SSID.1.Stats.PacketsSent [unsignedLong]", '')


    AL1 = clash.get("Device.WiFi.SSID.2.Stats.ErrorsReceived [unsignedInt]", '')
    AL2 = clash.get("Device.WiFi.SSID.2.Stats.AggregatedPacketCount [unsignedInt]", '')
    AL3 = clash.get("Device.WiFi.SSID.2.Stats.BroadcastPacketsSent [unsignedLong]", '')
    AL4 = clash.get("Device.WiFi.SSID.2.Stats.MulticastPacketsReceived [unsignedLong]", '')
    AL5 = clash.get("Device.WiFi.SSID.2.Stats.UnicastPacketsReceived [unsignedLong]", '')
    AL6 = clash.get("Device.WiFi.SSID.2.Stats.DiscardPacketsReceived [unsignedInt]", '')
    AL7 = clash.get("Device.WiFi.SSID.2.Stats.ErrorsSent [unsignedInt]", '')
    AL8 = clash.get("Device.WiFi.SSID.2.Stats.DiscardPacketsSent [unsignedInt]", '')
    AL9 = clash.get("Device.WiFi.SSID.2.Stats.BytesReceived [unsignedLong]", '')
    AL10 = clash.get("Device.WiFi.SSID.2.Stats.UnicastPacketsSent [unsignedLong]", '')
    AL11 = clash.get("Device.WiFi.SSID.2.Stats.MulticastPacketsSent [unsignedLong]", '')
    AL12 = clash.get("Device.WiFi.SSID.2.Stats.BytesSent [unsignedLong]", '')
    AL13 = clash.get("Device.WiFi.SSID.2.Stats.PacketsReceived [unsignedLong]", '')
    AL14 = clash.get("Device.WiFi.SSID.2.Stats.BroadcastPacketsReceived [unsignedLong]", '')
    AL15 = clash.get("Device.WiFi.SSID.2.Stats.PacketsSent [unsignedLong]", '')

    AM1 = clash.get("Device.WiFi.SSID.3.Stats.ErrorsReceived [unsignedInt]", '')
    AM2 = clash.get("Device.WiFi.SSID.3.Stats.AggregatedPacketCount [unsignedInt]", '')
    AM3 = clash.get("Device.WiFi.SSID.3.Stats.BroadcastPacketsSent [unsignedLong]", '')
    AM4 = clash.get("Device.WiFi.SSID.3.Stats.MulticastPacketsReceived [unsignedLong]", '')
    AM5 = clash.get("Device.WiFi.SSID.3.Stats.UnicastPacketsReceived [unsignedLong]", '')
    AM6 = clash.get("Device.WiFi.SSID.3.Stats.DiscardPacketsReceived [unsignedInt]", '')
    AM7 = clash.get("Device.WiFi.SSID.3.Stats.ErrorsSent [unsignedInt]", '')
    AM8 = clash.get("Device.WiFi.SSID.3.Stats.DiscardPacketsSent [unsignedInt]", '')
    AM9 = clash.get("Device.WiFi.SSID.3.Stats.BytesReceived [unsignedLong]", '')
    AM10 = clash.get("Device.WiFi.SSID.3.Stats.UnicastPacketsSent [unsignedLong]", '')
    AM11 = clash.get("Device.WiFi.SSID.3.Stats.MulticastPacketsSent [unsignedLong]", '')
    AM12 = clash.get("Device.WiFi.SSID.3.Stats.BytesSent [unsignedLong]", '')
    AM13 = clash.get("Device.WiFi.SSID.3.Stats.PacketsReceived [unsignedLong]", '')
    AM14 = clash.get("Device.WiFi.SSID.3.Stats.BroadcastPacketsReceived [unsignedLong]", '')
    AM15 = clash.get("Device.WiFi.SSID.3.Stats.PacketsSent [unsignedLong]", '')

    AN1 = clash.get("Device.WiFi.SSID.4.Stats.ErrorsReceived [unsignedInt]", '')
    AN2 = clash.get("Device.WiFi.SSID.4.Stats.AggregatedPacketCount [unsignedInt]", '')
    AN3 = clash.get("Device.WiFi.SSID.4.Stats.BroadcastPacketsSent [unsignedLong]", '')
    AN4 = clash.get("Device.WiFi.SSID.4.Stats.MulticastPacketsReceived [unsignedLong]", '')
    AN5 = clash.get("Device.WiFi.SSID.4.Stats.UnicastPacketsReceived [unsignedLong]", '')
    AN6 = clash.get("Device.WiFi.SSID.4.Stats.DiscardPacketsReceived [unsignedInt]", '')
    AN7 = clash.get("Device.WiFi.SSID.4.Stats.ErrorsSent [unsignedInt]", '')
    AN8 = clash.get("Device.WiFi.SSID.4.Stats.DiscardPacketsSent [unsignedInt]", '')
    AN9 = clash.get("Device.WiFi.SSID.4.Stats.BytesReceived [unsignedLong]", '')
    AN10 = clash.get("Device.WiFi.SSID.4.Stats.UnicastPacketsSent [unsignedLong]", '')
    AN11 = clash.get("Device.WiFi.SSID.4.Stats.MulticastPacketsSent [unsignedLong]", '')
    AN12 = clash.get("Device.WiFi.SSID.4.Stats.BytesSent [unsignedLong]", '')
    AN13 = clash.get("Device.WiFi.SSID.4.Stats.PacketsReceived [unsignedLong]", '')
    AN14 = clash.get("Device.WiFi.SSID.4.Stats.BroadcastPacketsReceived [unsignedLong]", '')
    AN15 = clash.get("Device.WiFi.SSID.4.Stats.PacketsSent [unsignedLong]", '')
    
    dict_performance = {"performance":
                        {"p_sys":{"AB1":AB1,"AB2":AB2,"AB3":AB3,"AB4":AB4,"AB5":AB5,"AB6":AB6,"AB7":AB7,"AB8":AB8,"AB9":AB9,"AB10":AB10,"AB11":AB11,"AB12":AB12,"AB13":AB13},
                        "p_net":{"AC1":AC1,"AC2":AC2,"AC3":AC3},
                        "p_xdsl":{"AF1":AF1,"AF2":AF2,"AF3":AF3,"AF4":AF4,"AF5":AF5,"AF6":AF6,"AF7":AF7,"AF8":AF8},
                        "p_sfp":{"AG1":AG1,"AG2":AG2,"AG3":AG3,"AG4":AG4,"AG5":AG5,"AG6":AG6,"AG7":AG7,"AG8":AG8,"AG9":AG9,"AG10":AG10,"AG11":AG11},
                        "p_wan":{"AH1":AH1,"AH2":AH2,"AH3":AH3,"AH4":AH4,"AH5":AH5,"AH6":AH6,"AH7":AH7,"AH8":AH8,"AH9":AH9,"AH10":AH10,"AH11":AH11,"AH12":AH12,"AH13":AH13,"AH14":AH14,"AH15":AH15},
                        "wifi_ap1":{"AI1":AI1,"AI2":AI2,"AI3":AI3,"AI4":AI4,"AI5":AI5,"AI6":AI6,"AI7":AI7,"AI8":AI8,"AI9":AI9,"AI10":AI10,"AI11":AI11,"AI12":AI12,"AI13":AI13,"AI14":AI14,"AI15":AI15},
                        "wifi_ap2":{"AL1":AL1,"AL2":AL2,"AL3":AL3,"AL4":AL4,"AL5":AL5,"AL6":AL6,"AL7":AL7,"AL8":AL8,"AL9":AL9,"AL10":AL10,"AL11":AL11,"AL12":AL12,"AL13":AL13,"AL14":AL14,"AL15":AL15},
                        "wifi_ap3":{"AM1":AM1,"AM2":AM2,"AM3":AM3,"AM4":AM4,"AM5":AM5,"AM6":AM6,"AM7":AM7,"AM8":AM8,"AM9":AM9,"AM10":AM10,"AM11":AM11,"AM12":AM12,"AM13":AM13,"AM14":AM14,"AM15":AM15},
                        "wifi_ap4":{"AN1":AN1,"AN2":AN2,"AN3":AN3,"AN4":AN4,"AN5":AN5,"AN6":AN6,"AN7":AN7,"AN8":AN8,"AN9":AN9,"AN10":AN10,"AN11":AN11,"AN12":AN12,"AN13":AN13,"AN14":AN14,"AN15":AN15}
                        }}
    return (json.dumps(dict_performance))


#
#
#   get_properties()
#
#
async def get_properties():
    # COMMANDI STRING
    command_clash = 'Device.'
    clash_rpc = 'rpc.'
    
    # FUNZIONI CLASH
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
    # COMMANDI STRING
    uci_var = 'env.var'
    uci_rip = 'env.rip'
    
    # FUNZIONI UCI
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
    A16 = clash.get("Device.DeviceInfo.MemoryStatus.X_000E50_MemoryUtilization [string]", '')
    A17 = clash.get("Device.DeviceInfo.X_000E50_TotalHWReboot [unsignedInt]", '')
    A18 = clash.get("Device.DeviceInfo.X_000E50_ScheduledReboot [boolean]", '')
    A19 = clash.get("Device.DeviceInfo.X_000E50_RebootCause [string]", '')
    A20 = clash.get("Device.DeviceInfo.X_000E50_FactoryReset_Wireless [boolean]", '')
    A21 = clash_rpc.get("rpc.system.reboottime [dateTime]", '')
    A22 = clash_rpc.get("rpc.system.uptime [unsignedInt]", '')
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
               "A16": A16, "A17": int(A17), "A18": int(A18), "A19": A19,
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
    # COMMANDI STRING
    uci_samba = "samba"
    uci_printersharing = "printersharing"
    clash_firewall = 'Device.Firewall.'

    # FUNZIONI UCI
    uci_show_samba = uci_show(uci_samba)
    uci_show_printersharing = uci_show(uci_printersharing)

    # FUNZIONI CLASH
    clash_firewall = clash_get(clash_firewall)

    C1 = clash.get("Device.IP.Interface.1.IPv4Address.1.AddressingType [string]", '')
    C2 = clash.get("Device.IP.Interface.1.IPv4Address.1.IPAddress [string]", '')
    C4 = clash.get("Device.IP.Interface.1.IPv4Address.1.Enable [boolean]", '')
    C5 = clash.get("Device.IP.Interface.1.IPv4Address.1.SubnetMask [string]", '')
    C6 = clash.get("Device.IP.Interface.1.IPv4Address.1.Alias [string]", '')
    C7 = clash.get("Device.IP.Interface.1.IPv4Address.1.Status [string]", '')
    D1 = subprocess.Popen("clash get Device.DeviceInfo.NetworkProperties.X_000E50_WanSyncStatus", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.DeviceInfo.NetworkProperties.X_000E50_WanSyncStatus [string] = ", '') #clash.get("DeviceInfo.ProcessStatus.Process.1756.Command [string]", '').replace("\n","")
    D2 = clash.get("Device.IP.Interface.2.IPv4Address.1.AddressingType [string]", '')
    D3 = clash.get("Device.IP.Interface.2.IPv4Address.1.IPAddress [string]", '')
    D4 = clash.get("Device.IP.Interface.2.IPv4Address.1.Enable [boolean]", '')
    D5 = clash.get("Device.IP.Interface.2.IPv4Address.1.SubnetMask [string]", '')
    D6 = clash.get("Device.IP.Interface.2.IPv4Address.1.Alias [string]", '')
    D7 = clash.get("Device.IP.Interface.2.IPv4Address.1.Status [string]", '')
    E1 = subprocess.Popen("clash get Device.IP.Interface.3.IPv4Address.1.AddressingType", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.3.IPv4Address.1.AddressingType [string] =", '') #clash.get("Device.IP.Interface.3.IPv4Address.1.AddressingType [string]", '')
    E2 = subprocess.Popen("clash get Device.IP.Interface.2.IPv4Address.1.AddressingType", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.2.IPv4Address.1.AddressingType [string] =", '') #clash.get("Device.IP.Interface.3.IPv4Address.1.IPAddress [string]", '')
    E3 = clash.get("Device.IP.Interface.3.IPv4Address.1.Enable [boolean]", '')
    E4 = subprocess.Popen("clash get Device.IP.Interface.3.IPv4Address.1.SubnetMask", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.3.IPv4Address.1.SubnetMask [string] =", '') #clash.get("Device.IP.Interface.3.IPv4Address.1.SubnetMask [string]", '')
    E5 = clash.get("Device.IP.Interface.3.IPv4Address.1.Alias [string]", '')
    E6 = clash.get("Device.IP.Interface.3.IPv4Address.1.Status [string]", '')
    F1 = clash.get("Device.IP.Interface.4.IPv4Address.1.AddressingType [string]", '')
    F2 = clash.get("Device.IP.Interface.4.IPv4Address.1.IPAddress [string]", '')
    F3 = clash.get("Device.IP.Interface.4.IPv4Address.1.Enable [boolean]", '')
    F4 = clash.get("Device.IP.Interface.4.IPv4Address.1.SubnetMask [string]", '')
    F5 = clash.get("Device.IP.Interface.4.IPv4Address.1.Alias [string]", '')
    F6 = clash.get("Device.IP.Interface.4.IPv4Address.1.Status [string]", '')
    G1 = clash.get("Device.IP.Interface.5.IPv4Address.1.AddressingType [string]", '')
    G2 = clash.get("Device.IP.Interface.5.IPv4Address.1.IPAddress [string]", '')
    G3 = clash.get("Device.IP.Interface.5.IPv4Address.1.Enable [boolean]", '')
    G4 = clash.get("Device.IP.Interface.5.IPv4Address.1.SubnetMask [string]", '')
    G5 = clash.get("Device.IP.Interface.5.IPv4Address.1.Alias [string]", '')
    G6 = clash.get("Device.IP.Interface.5.IPv4Address.1.Status [string]", '')
    #LOOPBACK
    H1 = clash.get("Device.IP.Interface.6.IPv4Address.1.AddressingType [string]", '')
    H2 = clash.get("Device.IP.Interface.6.IPv4AddressNumberOfEntries [unsignedInt]", '')
    H3 = clash.get("Device.IP.Interface.6.Enable [boolean]", '')
    H4 = clash.get("Device.IP.Interface.6.Status [string]", '')
    H5 = clash.get("Device.IP.Interface.6.IPv4Address.1.Alias [string]", '')
    H6 = clash.get("Device.IP.Interface.6.IPv4Address.1.Status [string]", '')
    #WAN 6
    I1 = subprocess.Popen("clash get Device.IP.Interface.7.LowerLayers", shell=True, stdout=subprocess.PIPE,universal_newlines=True).communicate()[0].strip().replace("Device.IP.Interface.7.LowerLayers [string] =", '') #clash.get("Device.IP.Interface.7.LowerLayers [string] =").replace("\n","")
    I2 = clash.get("Device.IP.Interface.7.IPv4AddressNumberOfEntries [unsignedInt] =")
    I3 = clash.get("Device.IP.Interface.7.Enable [boolean]", '')
    I4 = clash.get("Device.IP.Interface.7.Status [string]", '')
    #SFS
    L1 = clash.get("Device.IP.Interface.8.IPv4Address.1.AddressingType [string]", '')
    L2 = clash.get("Device.IP.Interface.8.IPv4AddressNumberOfEntries [unsignedInt]", '')
    L3 = clash.get("Device.IP.Interface.8.Enable [boolean]", '')
    L4 = clash.get("Device.IP.Interface.8.Status [string]", '')
    L5 = clash.get("Device.IP.Interface.8.IPv4Address.1.Alias [string]", '')
    L6 = clash.get("Device.IP.Interface.8.IPv4Address.1.Status [string]", '')
    #PUBLIC LAN
    M1 = clash.get("Device.IP.Interface.9.IPv4Address.1.AddressingType [string]", '')
    M2 = clash.get("Device.IP.Interface.9.IPv4AddressNumberOfEntries [unsignedInt]", '')
    M3 = clash.get("Device.IP.Interface.9.Enable [boolean]", '')
    M4 = clash.get("Device.IP.Interface.9.Status [string]", '')
    M5 = clash.get("Device.IP.Interface.9.IPv4Address.1.Alias [string]", '')
    M6 = clash.get("Device.IP.Interface.9.IPv4Address.1.Status [string]", '')
    #FIREWALL
    N1 = clash_firewall.get("Device.Firewall.Enable [boolean]", '')
    N2 = clash_firewall.get("Device.Firewall.Config [string]", '')
    N3 = clash_firewall.get("Device.Firewall.AdvancedLevel [string]", '')
    N4 = clash_firewall.get("Device.Firewall.X_000E50_EnableIPv6 [boolean]", '')
    N5 = clash_firewall.get("Device.Firewall.LevelNumberOfEntries [unsignedInt]", '')
    #IP
    O1 = clash.get("Device.IP.ActivePortNumberOfEntries [unsignedInt]", '')
    O2 = clash.get("Device.IP.IPv6Capable [boolean]", '')
    O3 = clash.get("Device.IP.IPv4Status [string]", '')
    O4 = clash.get("Device.IP.IPv6Status [string]", '')
    O5 = clash.get("Device.IP.IPv6Enable [boolean]", '')
    O6 = clash.get("Device.IP.InterfaceNumberOfEntries [unsignedInt]", '')
    O7 = clash.get("Device.IP.IPv4Capable [boolean]", '')
    O8 = clash.get("Device.IP.X_000E50_ReleaseRenewWAN [boolean]", '')
    O9 = clash.get("Device.IP.ULAPrefix [string]", '')
    O10 = clash.get("Device.IP.IPv4Enable [boolean]", '')
    #HOST
    P1 = clash.get("Device.Hosts.HostNumberOfEntries [unsignedInt]", '')
    #NAT
    Q1 = clash.get("Device.NAT.InterfaceSettingNumberOfEntries [unsignedInt]", '')
    Q2 = clash.get("Device.NAT.PortMappingNumberOfEntries [unsignedInt]", '')
    #DHCPv4
    R1 = clash.get("Device.DHCPv4.Server.Enable [boolean]", '')
    R2 = clash.get("Device.DHCPv4.Server.PoolNumberOfEntries [unsignedInt]", '')
    R3 = clash.get("Device.DHCPv4.Server.Pool.1.StaticAddressNumberOfEntries [unsignedInt]", '')
    R4 = clash.get("Device.DHCPv4.Server.Pool.1.Enable [boolean]", '')
    R5 = clash.get("Device.DHCPv4.Server.Pool.1.ClientNumberOfEntries [unsignedInt]", '')
    R6 = clash.get("Device.DHCPv4.Server.Pool.1.LeaseTime [int]", '')
    R7 = clash.get("Device.DHCPv4.Server.Pool.1.Status [string]", '')
    R8 = clash.get("Device.DHCPv4.Server.Pool.1.UserClassIDExclude [boolean]", '')
    R9 = clash.get("Device.DHCPv4.Server.Pool.1.MaxAddress [string]", '')
    R10 = clash.get("Device.DHCPv4.Server.Pool.1.VendorClassIDExclude [boolean]", '')
    R11 = clash.get("Device.DHCPv4.Server.Pool.1.SubnetMask [string]", '')
    R12 = clash.get("Device.DHCPv4.Server.Pool.1.IPRouters [string]", '')
    R13 = clash.get("Device.DHCPv4.Server.Pool.1.MinAddress [string]", '')
    R14 = clash.get("Device.DHCPv4.Server.Pool.1.ChaddrExclude [boolean]", '')
    R15 = clash.get("Device.DHCPv4.Server.Pool.1.DNSServers [string]", '')
    R16 = clash.get("Device.DHCPv4.Server.Pool.1.DomainName [string]", '')
    R17 = clash.get("Device.DHCPv4.Server.Pool.2.StaticAddressNumberOfEntries [unsignedInt]", '')
    R18 = clash.get("Device.DHCPv4.Server.Pool.2.Enable [boolean]", '')
    R19 = clash.get("Device.DHCPv4.Server.Pool.2.ClientNumberOfEntries [unsignedInt]", '')
    R20 = clash.get("Device.DHCPv4.Server.Pool.2.LeaseTime [int]", '')
    R21 = clash.get("Device.DHCPv4.Server.Pool.2.Status [string]", '')
    R22 = clash.get("Device.DHCPv4.Server.Pool.2.UserClassIDExclude [boolean]", '')
    R23 = clash.get("Device.DHCPv4.Server.Pool.2.MaxAddress [string]", '')
    R24 = clash.get("Device.DHCPv4.Server.Pool.2.VendorClassIDExclude [boolean]", '')
    R25 = clash.get("Device.DHCPv4.Server.Pool.2.SubnetMask [string]", '')
    R26 = clash.get("Device.DHCPv4.Server.Pool.2.IPRouters [string]", '')
    R27 = clash.get("Device.DHCPv4.Server.Pool.2.MinAddress [string]", '')
    R28 = clash.get("Device.DHCPv4.Server.Pool.2.ChaddrExclude [boolean]", '')
    R29 = clash.get("Device.DHCPv4.Server.Pool.2.DNSServers [string]", '')
    R30 = clash.get("Device.DHCPv4.Server.Pool.2.DomainName [string]", '')
    R31 = clash.get("Device.DHCPv4.Server.Pool.2.StaticAddressNumberOfEntries [unsignedInt]", '')
    R32 = clash.get("Device.DHCPv4.Server.Pool.3.Enable [boolean]", '')
    R33 = clash.get("Device.DHCPv4.Server.Pool.3.ClientNumberOfEntries [unsignedInt]", '')
    R34 = clash.get("Device.DHCPv4.Server.Pool.3.LeaseTime [int]", '')
    R35 = clash.get("Device.DHCPv4.Server.Pool.3.Status [string]", '')
    R36 = clash.get("Device.DHCPv4.Server.Pool.3.UserClassIDExclude [boolean]", '')
    R37 = clash.get("Device.DHCPv4.Server.Pool.3.MaxAddress [string]", '')
    R38 = clash.get("Device.DHCPv4.Server.Pool.3.VendorClassIDExclude [boolean]", '')
    R39 = clash.get("Device.DHCPv4.Server.Pool.3.SubnetMask [string]", '')
    R40 = clash.get("Device.DHCPv4.Server.Pool.3.IPRouters [string]", '')
    R41 = clash.get("Device.DHCPv4.Server.Pool.3.MinAddress [string]", '')
    R42 = clash.get("Device.DHCPv4.Server.Pool.3.ChaddrExclude [boolean]", '')
    R43 = clash.get("Device.DHCPv4.Server.Pool.3.DNSServers [string]", '')
    R44 = clash.get("Device.DHCPv4.Server.Pool.3.DomainName [string]", '')
    # DHCP v6
    S1 = clash.get("Device.DHCPv6.Server.Enable [boolean]", '')
    S2 = clash.get("Device.DHCPv6.Server.PoolNumberOfEntries [unsignedInt]", '')
    S3 = clash.get("Device.DHCPv6.Server.Pool.1.StaticAddressNumberOfEntries [unsignedInt]", '')
    S4 = clash.get("Device.DHCPv6.Server.Pool.1.Status [string]", '')
    S5 = clash.get("Device.DHCPv6.Server.Pool.1.Enable [boolean]", '')
    S6 = clash.get("Device.DHCPv6.Server.Pool.2.PoolNumberOfEntries [unsignedInt]", '')
    S7 = clash.get("Device.DHCPv6.Server.Pool.2.Status [string]", '')
    S8 = clash.get("Device.DHCPv6.Server.Pool.2.Enable [boolean]", '')
    S9 = clash.get("Device.DHCPv6.Server.Pool.3.PoolNumberOfEntries [unsignedInt]", '')
    S10 = clash.get("Device.DHCPv6.Server.Pool.3.Status [string]", '')
    S11 = clash.get("Device.DHCPv6.Server.Pool.3.Enable [boolean]", '')
    #SAMBA
    T1 = uci_show_samba.get("samba.samba.workgroup", '')
    T2 = uci_show_samba.get("samba.samba.configsdir", '')
    T3 = uci_show_samba.get("samba.samba.homes", '')
    T4 = uci_show_samba.get("samba.samba.enabled", '')
    T5 = uci_show_samba.get("samba.samba.filesharing", '')
    T6 = uci_show_samba.get("samba.samba.charset", '')
    T7 = uci_show_samba.get("samba.samba.printcap_cache_time", '')
    T8 = uci_show_samba.get("samba.samba.name", '')
    T9 = uci_show_samba.get("samba.samba.description", '')
    #USB
    U1 = clash.get("Device.USB.PortNumberOfEntries [unsignedInt]", '')
    U2 = clash.get("Device.USB.USBHosts.HostNumberOfEntries [unsignedInt]", '')
    U3 = clash.get("Device.USB.Port.1.Standard [string]", '')
    U4 = clash.get("Device.USB.Port.1.Name [string]", '')
    U5 = clash.get("Device.USB.Port.1.Rate [string]", '')
    U6 = clash.get("Device.USB.Port.2.Standard [string]", '')
    U7 = clash.get("Device.USB.Port.2.Name [string]", '')
    U8 = clash.get("Device.USB.Port.2.Rate [string]", '')
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
    W1 = clash.get("Device.StorageService.1.Enable [boolean]", '')
    W2 = clash.get("Device.StorageServiceNumberOfEntries [unsignedInt]", '')
    #WIFI_2G
    X1 = clash.get("Device.WiFi.SSID.1.Enable [boolean]", '')
    X2 = clash.get("Device.WiFi.SSID.1.MACAddress [string]", '')
    X3 = clash.get("Device.WiFi.SSID.1.SSID [string]", '')
    X4 = clash.get("Device.WiFi.SSID.1.Status [string]", '')
    X5 = clash.get("Device.WiFi.AccessPoint.1.WPS.Enable [boolean]", '')
    X6 = clash.get("Device.WiFi.SSID.3.Enable [boolean]", '')
    X7 = clash.get("Device.WiFi.SSID.3.MACAddress [string]", '')
    X8 = clash.get("Device.WiFi.SSID.3.SSID [string]", '')
    X9 = clash.get("Device.WiFi.SSID.3.Status [string]", '')
    X10 = clash.get("Device.WiFi.AccessPoint.3.WPS.Enable [boolean]", '')
    #WIFI_5G
    Y1 = clash.get("Device.WiFi.SSID.2.Enable [boolean]", '')
    Y2 = clash.get("Device.WiFi.SSID.2.MACAddress [string]", '')
    Y3 = clash.get("Device.WiFi.SSID.2.SSID [string]", '')
    Y4 = clash.get("Device.WiFi.SSID.2.Status [string]", '')
    Y5 = clash.get("Device.WiFi.AccessPoint.2.WPS.Enable [boolean]", '')
    Y6 = clash.get("Device.WiFi.SSID.4.Enable [boolean]", '')
    Y7 = clash.get("Device.WiFi.SSID.4.MACAddress [string]", '')
    Y8 = clash.get("Device.WiFi.SSID.4.SSID [string]", '')
    Y9 = clash.get("Device.WiFi.SSID.4.Status [string]", '')
    Y10 = clash.get("Device.WiFi.AccessPoint.4.WPS.Enable [boolean]", '')
    #MOBILE
    Z1 = clash_rpc.get("rpc.mobiled.DeviceNumberOfEntries [unsignedInt]", '')
    Z2 = clash_rpc.get("rpc.mobiled.device.@1.status [string]", '')
    Z3 = clash_rpc.get("rpc.mobiled.device.@1.info.manufacturer [string]", '')
    Z4 = clash_rpc.get("rpc.mobiled.device.@1.info.model [string]", '')
    Z5 = clash_rpc.get("rpc.mobiled.device.@1.info.imei [string]", '')
    Z6 = "DA RIVEDERE " #clash.get("Device.DHCPv6.Server.Pool.2.PoolNumberOfEntries [unsignedInt]", '')
    Z7 = clash_rpc.get("rpc.mobiled.device.@1.sim.iccid [string]", '')
    Z8 = clash_rpc.get("rpc.mobiled.device.@1.network.serving_system.nas_state [string]", '')
    Z9 = clash_rpc.get("rpc.mobiled.device.@1.ProfileNumberOfEntries [unsignedInt]", '')
    Z10 = clash_rpc.get("rpc.mobiled.device.@1.profile.@1.apn [string]", '')

    ## CONFIG OPTICAL
    AA1 = clash.get("Device.Optical.Interface.1.Status [string]", '')
    AA2 = clash.get("Device.Optical.Interface.1.VendorName [string]", '')
    AA3 = clash.get("Device.Optical.Interface.1.Enable [boolean]", '')

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
    AA35 = result.get('channel_noise_threshold')
    AA36 = result.get('channel_score_threshold')
    AA37 = result.get('quick_scan')
    AA38 = result.get('non_dfs_fallback')
    AA39 = result.get('ctrl_chan_adjust')
    AA40 = result.get('trace_leve')
    AA41 = result.get('chanim_tracing')
    AA42 = result.get('traffic_tracing')
    AA43 = result.get('allowed_channels')
    AA44 = result.get('max_records')
    AA45 = result.get('record_changes_only')
    AA46 = result.get('dfs_reentry')
    AA47 = result.get('bgdfs_preclearing')
    AA48 = result.get('bgdfs_avoid_on_far_sta')
    AA49 = result.get('bgdfs_far_sta_rss')
    AA50 = result.get('bgdfs_tx_time_threshold')
    AA51 = result.get('bgdfs_rx_time_threshold')
    AA52 = result.get('bgdfs_traffic_sense_period')

    ## CONFIG ACS_2G
    result = get_band_acs_2g()
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
    AA69 = result.get('channel_noise_threshold')
    AA70 = result.get('channel_score_threshold')
    AA71 = result.get('quick_scan')
    AA72 = result.get('non_dfs_fallback')
    AA73 = result.get('ctrl_chan_adjust')
    AA74 = result.get('trace_leve')
    AA75 = result.get('chanim_tracing')
    AA76 = result.get('traffic_tracing')
    AA77 = result.get('allowed_channels')
    AA78 = result.get('max_records')
    AA79 = result.get('record_changes_only')
    AA80 = result.get('dfs_reentry')
    AA81 = result.get('bgdfs_preclearing')
    AA82 = result.get('bgdfs_avoid_on_far_sta')
    AA83 = result.get('bgdfs_far_sta_rss')
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
    print(type(band_steer))
    obj = json.loads(band_steer)
    radio_2G = obj.get('radio_2G')
    #print(radio_2G)
    return radio_2G
