local sqlite = require("lsqlite3")
local args = {...}
local legacy_sql_db = args[1]
local homeware_sql_db = args[2]

-- Function to Convert Legacy Calllog to Homeware DB

local function migrate_calllog( db_legacy, db_homeware)
   db_homeware:exec('CREATE TABLE IF NOT EXISTS calllog(EntryIdentifier INTEGER PRIMARY KEY AUTOINCREMENT, ReadStatus INTEGER, LineId INTEGER, Direction INTEGER, Local TEXT, LocalName TEXT,Remote TEXT,RemoteName TEXT, ProfileName TEXT, network TEXT, startTime DATE, connectedTime DATE, endTime DATE, deviceName TEXT, callkey  INTEGER,terminationReason TEXT,NumberOfCalls INTEGER, NumberAtt_Internal INTEGER, NumberAtt_Own INTEGER, LineName TEXT, CallType INTEGER,  LineIdSub INTEGER,         TxPackets INTEGER,         RxPackets INTEGER,         TxBytes INTEGER,         RxBytes INTEGER,         PacketsLost INTEGER,         ReceivePacketLossRate INTEGER,         PacketsDiscarded INTEGER,         PacketsDiscardedRate INTEGER,         SignalLevel INTEGER,         NoiseLevel INTEGER,         RERL INTEGER,         RFactor INTEGER,         ExternalRFactor INTEGER,         MosLQ INTEGER,         MosCQ INTEGER,         AverageRoundTripDelay INTEGER,         WorstRoundTripDelay INTEGER,         RoundTripDelay INTEGER,         ReceiveInterarrivalJitter INTEGER,         ReceiveMinInterarrivalJitter INTEGER,         ReceiveMaxInterarrivalJitter INTEGER,         ReceiveDevInterarrivalJitter INTEGER,         AverageReceiveInterarrivalJitter INTEGER,         WorstReceiveInterarrivalJitter INTEGER,         Overruns INTEGER,         Underruns INTEGER,         FarEndTxPackets INTEGER,         FarEndTxBytes INTEGER,         FarEndPacketsLost INTEGER,         FarEndPacketLossRate INTEGER,         FarEndPacketsDiscardedRate INTEGER,         FarEndSignalLevel INTEGER,         FarEndNoiseLevel INTEGER,         FarEndRERL INTEGER,         FarEndRFactor INTEGER,         FarEndExternalRFactor INTEGER,         FarEndMosLQ INTEGER,         FarEndMosCQ INTEGER,         AverageFarEndRoundTripDelay INTEGER,         FarEndWorstRoundTripDelay INTEGER,         FarEndRoundTripDelay INTEGER,         FarEndInterarrivalJitter INTEGER,         FarEndReceiveMinInterarrivalJitter INTEGER,         FarEndReceiveMaxInterarrivalJitter INTEGER,         FarEndReceiveDevInterarrivalJitter INTEGER,         AverageFarEndInterarrivalJitter INTEGER,         FarEndWorstReceiveInterarrivalJitter INTEGER,         InboundTotalRTCPPackets INTEGER,         OutboundTotalRTCPPackets INTEGER,         InboundSumFractionLoss INTEGER,         InboundSumSqrFractionLoss INTEGER,         OutboundSumFractionLoss INTEGER,         OutboundSumSqrFractionLoss INTEGER,         InboundSumInterarrivalJitter INTEGER,         InboundSumSqrInterarrivalJitter INTEGER,         OutboundSumInterarrivalJitter INTEGER,         OutboundSumSqrInterarrivalJitter INTEGER,         SumRTCPRoundTripDelay INTEGER,         SumSqrRTCPRoundTripDelay INTEGER,         SumRTCPOneWayDelay INTEGER,         SumSqrRTCPOneWayDelay INTEGER,         MaxRTCPOneWayDelay INTEGER, Codec TEXT, FarEndIPAddress TEXT, FarEndUDPPort INTEGER, LocalIPAddress TEXT, LocalUDPPort INTEGER);')
   db_homeware:exec('PRAGMA user_version=1;')
   db_legacy:exec('select Direction,CallingNumber,CallingName,CalledNumber,CalledName,datetime(TimeStart,"unixepoch"),case TimeConnect when 0 then 0 else datetime(TimeConnect,"unixepoch") end,datetime(TimeEnd,"unixepoch"),OrigPort,TermPort from Entry', function (ud, ncols, values, names)  --Read Only Required Fields

                  -- Logic to derive Calling/Called name and Number, devicename, callType, Connect/start/end time
    -- LOGIC for DeviceName
                 local devName, hw_dev_name
                 local hw_dev_table = {
                       DECT = "NA",
                       FXS = "NA",
                       FXS1 = "fxs_dev_0",
                       FXS2 = "fxs_dev_1",
                       DECT1 = "dect_dev_0",
                       DECT2 = "dect_dev_1",
                       DECT3 = "dect_dev_2",
                       DECT4 = "dect_dev_3",
                       DECT5 = "dect_dev_4",
                       DECT6 = "dect_dev_5",
                      }
                 if (values[1] == "1") then
                     devName = values[10] -- TermPort
                 else
                     devName = values[9]  -- OrigPort
                 end

                 hw_dev_name = (devName ~= "") and hw_dev_table[devName] or ""

    -- LOGIC for CallType
		 local ctype
		 if (values[1] == "1") then
		     ctype = (values[7] == "0") and "1" or "2"
		 else
		     ctype = "3"
		 end
    -- LOGIC for local/ remote number name
		 local num, name, remote_num, remote_name
		 if (values[1] == "1") then
		     num = values[4]
		     name = values[5]
		     remote_num = values[2]
		     if values[3] =="" then
		     remote_name = ""
		     else
		     remote_name = values[3]:gsub('\"',"")
		     end
	         else
		      num = values[2]
		      if values[3] =="" then
		      name = ""
		      else
		      name = values[3]:gsub('\"', "")
		      end
		      remote_num = values[4]
		      remote_name = values[5]
		 end
                  -- INSERT values into homeware call-log table
                db_homeware:exec('INSERT INTO calllog(Direction,Local,LocalName,Remote,RemoteName,startTime,connectedTime,endTime,deviceName,callType) VALUES("' .. values[1] .. '","' .. num .. '", "' .. name .. '", "' .. remote_num ..'", "' .. remote_name .. '", "'..  values[6] ..'", "'.. values[7] ..'", "'.. values[8] ..'","'.. hw_dev_name ..'", "' .. ctype ..'");')
                  -- Update fields with default value
                db_homeware:exec('UPDATE calllog set ReadStatus=127,LineId=0 ,network="MMNETWORK_TYPE_SIP" ,callkey=NULL, terminationReason="MMPBX_CALLSTATE_DISCONNECTED_REASON_UNKNOWN", NumberOfCalls=1,LineIdSub =0, NumberAtt_Internal=0, NumberAtt_Own=0, LineName=NULL,  LineIdSub=0,         TxPackets=0,         RxPackets=0,         TxBytes=0,         RxBytes=0,         PacketsLost=0,         ReceivePacketLossRate=0,         PacketsDiscarded=0,         PacketsDiscardedRate=0,         SignalLevel=0,         NoiseLevel=0,         RERL=0,         RFactor=0,         ExternalRFactor=0,         MosLQ=0,         MosCQ=0,         AverageRoundTripDelay=0,         WorstRoundTripDelay=0,         RoundTripDelay=0,         ReceiveInterarrivalJitter=0,         ReceiveMinInterarrivalJitter=0,         ReceiveMaxInterarrivalJitter=0,         ReceiveDevInterarrivalJitter=0,         AverageReceiveInterarrivalJitter=0,         WorstReceiveInterarrivalJitter=0,         Overruns=0,         Underruns=0,         FarEndTxPackets=0,         FarEndTxBytes=0,         FarEndPacketsLost=0,         FarEndPacketLossRate=0,         FarEndPacketsDiscardedRate=0,         FarEndSignalLevel=0,         FarEndNoiseLevel=0,         FarEndRERL=0,         FarEndRFactor=0,         FarEndExternalRFactor=0,         FarEndMosLQ=0,         FarEndMosCQ=0,         AverageFarEndRoundTripDelay=0,         FarEndWorstRoundTripDelay=0,         FarEndRoundTripDelay=0,         FarEndInterarrivalJitter=0,         FarEndReceiveMinInterarrivalJitter=0,         FarEndReceiveMaxInterarrivalJitter=0,         FarEndReceiveDevInterarrivalJitter=0,         AverageFarEndInterarrivalJitter=0,         FarEndWorstReceiveInterarrivalJitter=0,         InboundTotalRTCPPackets=0,         OutboundTotalRTCPPackets=0,         InboundSumFractionLoss=0,         InboundSumSqrFractionLoss=0,         OutboundSumFractionLoss=0,         OutboundSumSqrFractionLoss=0,         InboundSumInterarrivalJitter=0,         InboundSumSqrInterarrivalJitter=0,         OutboundSumInterarrivalJitter=0,         OutboundSumSqrInterarrivalJitter=0,         SumRTCPRoundTripDelay=0,         SumSqrRTCPRoundTripDelay=0,         SumRTCPOneWayDelay=0,         SumSqrRTCPOneWayDelay=0,         MaxRTCPOneWayDelay=0, Codec=NULL, FarEndIPAddress=NULL, FarEndUDPPort=0, LocalIPAddress=NULL, LocalUDPPort=0;')
                  return sqlite.OK
                  end
   )
end

-- ********************************************************************
-- Main Conversion Logic From Legacy (R10.5.1 Telia) to Homeware r15.3
-- ********************************************************************

-- Open Legacy Database
local ck_file=io.open("/proc/banktable/legacy_upgrade/key", "r")
if ck_file ~= nil then
    db_legacy = sqlite.open(legacy_sql_db)
    db_homeware = sqlite.open(homeware_sql_db)

-- convert calllog table

    migrate_calllog(db_legacy, db_homeware) -- Converts legacty call-log to Homeware

-- convert DECT details
-- TODO

-- Close Db handles
    db_legacy:close()
    db_homeware:close()
end
