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
integer configCount;
float HTTPdbProcessStart;
list storedConfigs;
list databaseInput;
key resolveTestKey;
key requestDataURL;

// FIXME: Interim code to handle depreciation of old vars
// See bellow line 255 and onwards.
integer canDressSelf = -1;

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
            string conf = llList2String(split, 0);
            string value = llDumpList2String(llDeleteSubList(split,0,0), "|");
            
            integer i = llListFindList(storedConfigs, [conf]);
            
            if (value == RECORD_DELETE) {
                if (i != -1) storedConfigs = llDeleteSubList(storedConfigs, i, i + 1);
            }
            else {
                if ((conf == "controllers") || (conf == "blacklist")) {
                    string prefix = "controller"; split = llParseString2List(value, ["|"], []);
                    if (conf == "blacklist") prefix = conf;
                    
                    // Store configuration information
                    if (i == -1) storedConfigs += [ conf, value ];
                    else storedConfigs = llListReplaceList(storedConfigs, [ conf, value ], i, i + 1);
                    
                    integer j = -1; integer c;
                    string uuid;
                    string name;
                    string value;

                    while (j++ < 9) {
                        uuid = llList2String(split,0);
                        name = llList2String(split,1);
                        
                        value = uuid + "|" + name;
                        
                        if ((uuid != (string)NULL_KEY) && (uuid != "") && (name != "") && (value != "|")) {
                            c++;
                            lmSendConfig(prefix + (string)j, value);
                        }
                        else lmSendConfig(prefix + (string)j, RECORD_DELETE);
    
                        split = llDeleteSubList(split,0,1);
    
                        i = llListFindList(storedConfigs, [prefix + (string)j]);
                        if (i == -1) storedConfigs += [ prefix + (string)j, uuid + "|" + name ];
                        else storedConfigs = llListReplaceList(storedConfigs, [ prefix + (string)j, uuid + "|" + name ], i, i + 1);
                    }
                    
                    lmSendConfig(prefix + "sCount", (string)c);
                    
                    return;
                }
                
                // Store configuration information
                if (i == -1) storedConfigs += [ conf, value ];
                else storedConfigs = llListReplaceList(storedConfigs, [ conf, value ], i, i + 1);
                
                if (llGetListLength(storedConfigs) / 2 > storedCount) {
                    storedCount = llGetListLength(storedConfigs) / 2;
                    debugSay(3, "DEBUG-LOCALDB", "Local DB now contains " + (string)storedCount + " key=>value pairs and " + cdMyScriptName() + " is using " + formatFloat((float)llGetUsedMemory() / 1024.0, 2) + "kB of memory.");
                }
            }

#ifdef DEVELOPER_MODE
            if (conf == "debugLevel")                   debugLevel = (integer)value;
            else if (script == cdMyScriptName()) return;
#else
            if (script == cdMyScriptName()) return;
#endif
            else if (conf == "offlineMode") offlineMode = (integer)value;
        }
        else if ((code == 301) || (code == 302)) {
            integer type = code - 300;
            integer i; integer n = llGetListLength(storedConfigs) / 2;
            storedConfigs = llListSort(storedConfigs, 2, 1);
            while (i < n) {
                string conf = llList2String(storedConfigs, i * 2);
                string value = llList2String(storedConfigs, i * 2 + 1);
                if (type == 1) lmSendConfig(conf, value);
                else {
                    if ((conf != "controllers") && (conf != "blacklist")) llOwnerSay("\n" + conf + "=" + value);
                    llSleep(0.1);
                }
                i++;
            }
            i = llListFindList(storedConfigs, ["dollyName"]);
            if (i != -1) lmSendConfig("dollyName", llList2String(storedConfigs, i + 1));
        }
        else if (code == 303) {
            storedConfigs = llListSort(storedConfigs, 2, 1);
            while(split != []) {
                string conf = llList2String(split,0);
                integer i = llListFindList(storedConfigs, [conf]);
                if (i != -1) lmSendConfig(conf, llList2String(storedConfigs, i + 1));
                
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
                else if (requestType == "MistressKey")      requestMistressKey = id;
                else if (requestType == "Update")           requestUpdate = id;
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
                lmSendConfig("nextRetry", (string)nextRetry);
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
                lmSendConfig("nextRetry", (string)nextRetry);
            }
        }
        else if (location == "/httpdb/retrieve") {
            llSetMemoryLimit(65536);
            string error = "HTTPdb - Database access ";

            if (status == 200) {
                lmSendConfig("databaseOnline", (string)(databaseOnline = 1));

                HTTPdbProcessStart = llGetTime();

                llOwnerSay("Processing database reply..."); // FIXME: sometimes, this is not followed by any report - and is printed for all keys
                
                databaseInput = llParseStringKeepNulls(body,["\n"],[]); body = "";
                
                configCount = 0;
            }
            else {
                databaseReload = llGetUnixTime() + 60 + llRound(llFrand(90));
                if (databaseOnline) {
                    error += "failed: Continuing init in offline mode and will contintiue trying.";
                    lmSendConfig("databaseOnline", (string)(databaseOnline = 0));
                    llOwnerSay(error);
                }
            }
            
            llSetTimerEvent(0.5);
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
    
    timer() {
        integer k = 16;
        
        list splitLine;
        string line;
        string name;
        string value;

        while (k-- && llGetListLength(databaseInput)) {
            line = llList2String(databaseInput, 0);
            splitLine = llParseStringKeepNulls(line,["="],[]);
            
            name = llList2String(splitLine, 0);
            splitLine = llDeleteSubList(splitLine,0,0);
            value = llDumpList2String(splitLine,"=");
            
            databaseInput = llDeleteSubList(databaseInput,0,0);
            
            if ((name == "SAFEWORD") && (value == RECORD_DELETE)) {                 // These magic values only have meaning when sent key->DB they should not ever exist in a response
                llOwnerSay("ERROR: Special value found in database response '" + name + "'='" + value + "' this should never happen, please report this.");
            }
            else {
                // FIXME: Interim code to handle depreciation of old vars these should
                // be eliminated when the depreciated forms move to obsolecence
                
                if (llGetSubString(name,0,9) == "controller") {
                    if ((llGetSubString(name,-2,-1) == "ID") || (llGetSubString(name,-4,-1) == "Name")) {
                        lmSendConfig(name, value = RECORD_DELETE);                  // Depreciated form, delete it
                    }
                    else if ((value == "") || (value == "|")) {
                        lmSendConfig(name, value = RECORD_DELETE);                  // New form but no content deleted
                    }
                    else {
                        lmInternalCommand("addMistress", value, DATABASE_ID);       // New form with content accepted
                    }
                }
                else if (llGetSubString(name,0,8) == "blacklist") {
                    if ((llGetSubString(name,-2,-1) == "ID") || (llGetSubString(name,-4,-1) == "Name")) {
                        lmSendConfig(name, value = RECORD_DELETE);                  // Depreciated form, delete it
                    }
                    else if ((value == "") || (value == "|")) {
                        lmSendConfig(name, value = RECORD_DELETE);                  // New form but no content deleted
                    }
                    else {
                        lmSendConfig("blacklistMode", (string)1);
                        lmInternalCommand("addRemBlacklist", value, DATABASE_ID);   // New form with content accepted
                    }
                }
                else if ((name == "controllers") || (name == "MistressList")) {
                    if (llListFindList(storedConfigs,["controllersCount"]) == -1) {
                        lmSendConfig(name, value);                                  // This list variable has had occasional issues with durability and is rather tricky to validate the new type
                                                                                    // controller records are available in the database for this user so we will use those to rebuild the internal
                                                                                    // controllers from a clean slate instead.
                    }
                }
                else if (name == "blacklist") lmSendConfig(name, value);
                else {
                    if (name == "helpless") {
                        lmDBdata("tpLureOnly", value);                              // T is after H so this one convert to new form and let new override if needed
                        value = RECORD_DELETE;                                      // Mark old record for delete
                    }
                    else if (name == "canDressSelf") canDressSelf = (integer)value; // Set the temp variable so that we do not use canWear to set this later
                    else if (name == "canWear") {                                   // W however is after D making this one trickier thus the temp canDressSelf = -1 var
                        if (canDressSelf == -1) {
                            lmDBdata("canDressSelf", value);                        // we do not want to use the old one to set it unless it is still unset.
                            value = RECORD_DELETE;                                  // Mark old record for delete
                        }
                        else return;                                                // Otherwise we just ignore the depreciated one.
                    }
                    
                    lmDBdata(name, value);
                    integer i = llListFindList(storedConfigs, [name]);
                    if (i == -1) storedConfigs += [ name, value ];
                
                    configCount++;
                }
            }
        }
        
        if (!llGetListLength(databaseInput)) {
            if (llGetListLength(storedConfigs) / 2 > storedCount) {
                debugSay(3, "DEBUG-LOCALDB", "Local DB now contains " + (string)(storedCount = llGetListLength(storedConfigs) / 2) + " key=>value pairs and " + cdMyScriptName() + " is using " + formatFloat((float)llGetUsedMemory() / 1024.0, 2) + "kB of memory.");
            }
        
#ifdef DEVELOPER_MODE
            string eventTime = formatFloat((HTTPdbProcessStart - HTTPdbStart) * 1000, 2);
            
            debugSay(5, "DEBUG-SERVICES", "Service post interval setting " + formatFloat(HTTPinterval, 2) + "s throttle setting " + formatFloat(HTTPthrottle, 2) + "s");
        
            string msg = "HTTPdb - Processed " + (string)configCount + " records ";
            if (lastPostTimestamp) msg += "with updates since our last post " + (string)((llGetUnixTime() - lastPostTimestamp) / 60) + " minutes ago ";
            msg += "event time " + eventTime + ", processing time " + formatFloat(((llGetTime() - HTTPdbProcessStart) * 1000), 2);
            msg += "ms, total time for DB transaction " + formatFloat((llGetTime() - HTTPdbStart) * 1000, 2) + "ms";
            debugSay(1, "DEBUG-SERVICES", msg);
            if (!debugLevel) llOwnerSay("Successfully processed database reply in " + formatFloat(llGetTime() - HTTPdbStart, 2) + "s");
#else
            llOwnerSay("Successfully processed database reply in " + formatFloat(llGetTime() - HTTPdbStart, 2) + "s");
#endif
        
            databaseReload = 600;
            
            llSetTimerEvent(0.0);
            lmConfigComplete(configCount); 
        }
    }
}
