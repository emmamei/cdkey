//========================================
// ServiceReceiver.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/GlobalDefines.lsl"
#include "include/ServiceIncludes.lsl"

string resolveName;
string DataURL;
integer useHTTPS = 1;
integer resolveType;
integer storedCount;
//list storedConfigs;
string storedConfigs;
key resolveTestKey;
key requestDataURL;

key requestDataName;

default {
    state_entry() {
        cdInitializeSeq();
        requestDataURL = llGetNotecardLine("DataServices",0);
    }

    on_rez(integer start) {
        rezzed = 1;
    }

    link_message(integer sender, integer i, string data, key id) {
        
        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == 102) {
            scaleMem();
        }
        else if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        }
        
        cdConfigReport();
        
        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            
            // Store configuration information
            storedConfigs = cdSetValue(storedConfigs,[name],llDumpList2String(llDeleteSubList(split,0,0),"|"));
            
            if (llGetListLength(llJson2List(storedConfigs)) / 2 > storedCount) {
                debugSay(3, "DEBUG-LOCALDB", "Local DB now contains " + (string)(storedCount = llGetListLength(llJson2List(storedConfigs)) / 2) + " key=>value pairs and " + cdMyScriptName() + " is using " + formatFloat((float)llGetUsedMemory() / 1024.0, 2) + "kB of memory.");
                storedCount = llGetListLength(llJson2List(storedConfigs));
            }

#ifdef DEVELOPER_MODE
            if (name == "debugLevel")                   debugLevel = (integer)value;
            else if (script == cdMyScriptName()) return;
#else
            if (script == cdMyScriptName()) return;
#endif
            else if (name == "offlineMode") {
                offlineMode = (integer)value;
                dbPostParams = [];
            }
        }
        else if ((code == 301) || (code == 302)) {
            integer type = code - 300;
            integer i; integer n;
            n = llGetListLength(llJson2List(storedConfigs)) / 2;
            integer j; string start = "\n<KeyState:"; string end = "</KeyState:";
            while (i < n) {
                if (type == 1) {
                    string conf = llList2String(llJson2List(storedConfigs), i*2);
                    string value = cdGetValue(storedConfigs,[conf]);
                    if (value == JSON_FALSE) value = "0";
                    else if (value == JSON_TRUE) value = "1";
                    else if (value == JSON_NULL) value = "";
                    lmSendConfig(conf, value);
                }
                else {
                    string conf = llList2Json(JSON_OBJECT, llList2List(llJson2List(storedConfigs), i*2, i*2+1) );
                    integer len = llStringLength(conf);
                    conf = start + (string)i + ":" + (string)len + ">" + conf + end + (string)i++ + ">";
                    llOwnerSay(conf);
                    llSleep(0.1);
                }
            }
            lmSendConfig("dollyName", cdGetValue(storedConfigs,["dollyName"]));
        }
        else if (code == 303) {
            while(split != []) {
                string conf = llList2String(split,0);
                string value = cdGetValue(storedConfigs,[conf]);
                if (value == JSON_FALSE) value = "0";
                else if (value == JSON_TRUE) value = "1";
                else if (value == JSON_NULL) value = "";
                lmSendConfig(conf, cdGetValue(storedConfigs,[conf]));
                split = llDeleteSubList(split,0,0);
            }
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);   // Always stick with llDeleteSubList it handles missing/null parameters eg:
                                                    // illDeleteSubList([ "Script", "cmd" ],0,1) == []
                                                    // llList2List([ "Script", "cmd" ],2,-1) == [ "Script" , "cmd" ]
                                                    // This has been the cause of bugs.

            if (cmd == "getMistressKey") {
                string name = llList2String(split, 0);
                resolveName = name;
                resolveType = 1;
            }
            else if (cmd == "getBlacklistKey") {
                string name = llList2String(split, 0);
                resolveName = name;
                resolveType = 2;
            }
        }
        else if (code == 350) {
            lmSendConfig("RLVok", llList2String(split, 0));
        }
        else if (code == 850) {
            string messageType = llList2String(split, 1);

            if (messageType == "requestID") {
                string requestType = llList2String(split, 2);

                     if (requestType == "BlacklistKey")     requestBlacklistKey = id;
                else if (requestType == "AddKey")           requestAddKey = id;
                else if (requestType == "MistressKey")      requestMistressKey = id;
                else if (requestType == "SendDB")           requestSendDB = id;
                else if (requestType == "LoadDB")           requestLoadDB = id;
                else if (requestType == "Update")           requestUpdate = id;
                else if (requestType == "Name")             requestName = id;
            }
        }
    }

    http_response(key request, integer status, list meta, string body) {
        integer locationIndex = llSubStringIndex(body,"\n");
        integer queryIndex = llSubStringIndex(body,"?");
        string location = llGetSubString(body, 10, queryIndex - 1);
        body = llStringTrim(llDeleteSubString(body, 0, locationIndex), STRING_TRIM);
#ifdef UPDATE_METHOD_CDKEY
        if (request == requestUpdate) {
            if (llGetSubString(body, 0, 21) == "checkversion versionok") {
                if (llStringLength(body) > 22) updateCheck = (integer)llGetSubString(body, 23, -1);
                lastUpdateCheck = llGetUnixTime();
                debugSay(5, "DEBUG-SERVICES", "Next check in " + (string)updateCheck + " seconds");
                llOwnerSay("Version check completed you have the latest version.");
            }
            else if (body == "checkversion updatesent") {
                lastUpdateCheck = llGetUnixTime();
                llOwnerSay("Version check completed your updated key is on it's way to you now.");
            }
            else if (status != 200) {
                llOwnerSay("Error, failure to contact the update server you key will continue to try or see the help notecard.  " +
                           "For alternative update options.");
                gotURL = 0;
                if (++requestIndex < llGetListLength(serverNames)) {
                    nextRetry = llGetUnixTime() + llRound(30.0 + llFrand(30.0));
                }
                else {
                    requestIndex = 0;
                    nextRetry = llGetUnixTime() + llRound(900.0 + llFrand(900.0));
                }
                queForSave("nextRetry", (string)nextRetry);
            }
        }
        else if (location == "/objdns/lookup") {
#else
        if (location == "/objdns/lookup") {
#endif
            if (status == 200) {
                serverURL = body;
                gotURL = 1;
                requestIndex = 0;
            }
            else {
                if (++requestIndex < llGetListLength(serverNames)) {
                    nextRetry = llGetUnixTime() + llRound(30.0 + llFrand(30.0));
                }
                else {
                    requestIndex = 0;
                    nextRetry = llGetUnixTime() + llRound(900.0 + llFrand(900.0));
                }
                queForSave("nextRetry", (string)nextRetry);
            }
        }
        else if (location == "/httpdb/retrieve") {
            llSetMemoryLimit(65536);
            string error = "HTTPdb - Database access ";

            integer configCount;

            if (status == 200) {
                lmSendConfig("databaseOnline", (string)(databaseOnline = 1));

                float HTTPdbProcessStart;
                string eventTime = formatFloat(((HTTPdbProcessStart = llGetTime()) - HTTPdbStart) * 1000, 2);

                llOwnerSay("Processing reply: ");
                
                list input = llParseStringKeepNulls(body,["\n"],[]); body = "";
                configCount = llGetListLength(input);

                while(llGetListLength(input)) {
                    list splitLine = llParseStringKeepNulls(llList2String(input, 1),["="],[]);
                    
                    string name = llList2String(splitLine, 0);
                    splitLine = llDeleteSubList(splitLine,0,0);
                    string value = llDumpList2String(splitLine,"=");
                    
                    input = llDeleteSubList(input,0,0);
                    
                    lmSendConfig(name, value);
                    if (value == "0") value == JSON_FALSE;
                    if (value == "1") value == JSON_TRUE;
                    if (splitLine == []) value == JSON_NULL;
                    storedConfigs = cdSetValue(storedConfigs, [name], value);
                }
                
                if (llGetListLength(llJson2List(storedConfigs)) / 2 > storedCount) {
                    debugSay(3, "DEBUG-LOCALDB", "Local DB now contains " + (string)(storedCount = llGetListLength(llJson2List(storedConfigs)) / 2) + " key=>value pairs and " + cdMyScriptName() + " is using " + formatFloat((float)llGetUsedMemory() / 1024.0, 2) + "kB of memory.");
                    storedCount = llGetListLength(llJson2List(storedConfigs));
                }

#ifdef DEVELOPER_MODE
                debugSay(5, "DEBUG-SERVICES", "Service post interval setting " + formatFloat(HTTPinterval, 2) + "s throttle setting " + formatFloat(HTTPthrottle, 2) + "s");

                string msg = "HTTPdb - Processed " + (string)configCount + " records ";
                if (lastPostTimestamp) msg += "with updates since our last post " + (string)((llGetUnixTime() - lastPostTimestamp) / 60) + " minutes ago ";
                msg += "event time " + eventTime + ", processing time " + formatFloat(((llGetTime() - HTTPdbProcessStart) * 1000), 2);
                msg += "ms, total time for DB transaction " + formatFloat((llGetTime() - HTTPdbStart) * 1000, 2) + "ms";
                debugSay(2, "DEBUG-SERVICES", msg);
#endif

                databaseReload = 600;
            }
            else {
                databaseReload = llGetUnixTime() + 60 + llRound(llFrand(90));
                if (databaseOnline) {
                    error += "failed: Continuing init in offline mode and will contintiue trying.";
                    lmSendConfig("databaseOnline", (string)(databaseOnline = 0));
                    llOwnerSay(error);
                }
            }
            
            lmConfigComplete(configCount);
        }
        else if (location == "/name2key/lookup") {
            list split = llParseStringKeepNulls(body, ["=","\n"], []);
            string name = llList2String(split, 0);
            string uuid = llList2String(split, 1);
            if (uuid == "NOT FOUND") {
                llOwnerSay("Despite much searching and checking none of our sources can identify the mysterious '" + name + "' " +
                           "not even after consulting the SL search oracle.  Are you sure that you typed the name correctly and are " +
                           "not trying to seek an alias?");
                llSleep(0.5);
                llOwnerSay("Tip: If you are sure you are typing the correct username and are not trying to enter a display name you should have them " +
                           "touch the key then try again.");
            }
            else if (resolveType == 1) {
                lmInternalCommand("addMistress", uuid + "|" + name, NULL_KEY);
            }
            else if (resolveType == 2) {
                lmInternalCommand("addRemBlacklist", uuid + "|" + name, NULL_KEY);
            }
        }
        else if (location == "/httpdb/store") {
            if (status == 200) {
                dbPostParams = [];
                list split = llParseStringKeepNulls(body, [ "|" ], []);
                lastPostTimestamp = llList2Integer(split, 1);
                lmServiceMessage("lastPostTimestamp", (string)(lastPostTimestamp), NULL_KEY);
                debugSay(5, "DEBUG-SERVICES", "HTTPdb update success " + llList2String(split, 2) + " updated records: " + llList2CSV(updateList));
                if (!databaseOnline) {
                    llOwnerSay("HTTPdb - Database service has recovered.");
                    curInterval = stdInterval;
                    databaseOnline = 1;
                }
                lastPost = llGetTime();
            }
            else {
                if (databaseOnline) {
                    llOwnerSay("HTTPdb - Unable to update the database, falling back to offline mode until service recovers.");
                    databaseOnline = 0;
                    curInterval += curInterval;
                    myMod = llFloor(llFrand((float)curInterval - 0.000001));
                }
            }
        }
        else if (location == "/name2key/add") {
            list split = llParseStringKeepNulls(body, [ "|" ], []);
            integer new = llList2Integer(split, 1);
            integer old = llList2Integer(split, 2);

            debugSay(5, "DEBUG-SERVICES", "Posted " + (string)(old + new) + " keys: " + (string)new + " new, " + (string)old + " old");
        }

        if (location != "/httpdb/retreive") {
            integer debug;
            if (status == 200) debug = 7;
            else debug = 1;

            debugSay(debug, "DEBUG-SERVICES-RAW", "HTTP " + (string)status + "|" + body);

            string lastPart;
            do {
                string bodyCut = llGetSubString(body, 0, 755);
                integer vIdxFnd =
                    llStringLength(bodyCut) -
                    llStringLength("\n") -
                    llStringLength(llList2String(llParseStringKeepNulls(bodyCut, ["\n"], []), -1));
                integer endIndex = (vIdxFnd | (vIdxFnd >> 31));
                bodyCut = llGetSubString(body, 0, endIndex);
                body = llDeleteSubString(body, 0, endIndex);

                debugSay(debug, "DEBUG-SERVICES-RAW", bodyCut);
            } while (llStringLength(body));
        }
        scaleMem();
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) {
            cdPermSanityCheck();
        }
    }
}
