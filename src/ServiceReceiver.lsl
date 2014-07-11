//========================================
// ServiceReceiver.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/GlobalDefines.lsl"
#include "include/ServiceIncludes.lsl"

//#define UPDATE_METHOD_CDKEY
string resolveName;
//string DataURL;
integer useHTTPS = 1;

integer resolveType;
#define MISTRESS_KEY 1
#define BLACKLIST_KEY 2

integer storedCount;
integer configCount;
float HTTPdbProcessStart;

#ifdef STORED_CONFIG
list storedConfigs;
#endif

list databaseInput;
key resolveTestKey;
//key requestDataURL;

// FIXME: Interim code to handle depreciation of old vars
// See bellow line 255 and onwards.
integer canDressSelf = -1;

key requestDataName;

default {
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        cdInitializeSeq();
        //requestDataURL = llGetNotecardLine("DataServices",0);
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        rezzed = 1;
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();
#ifdef DEVELOPER_MODE
#ifdef STORED_CONFIG
        integer siz = llGetListLength(storedConfigs);
        debugSay(5,"DEBUG-SERVICES","storedConfigs size is " + (string)siz + " (or " + (siz / 2) " elements)");
#endif
#endif

        if (code == 102) {
            ;
        }
        else if (code == 135) {
            memReport(cdMyScriptName(),llList2Float(split, 0));
        } else

        cdConfigReport();

        else if (code == 300) {
            string conf = llList2String(split, 0);
            string value = llDumpList2String(llDeleteSubList(split,0,0), "|");

#ifdef STORED_CONFIG
            integer i = llListFindList(storedConfigs, [conf]);
#endif

            if (value == RECORD_DELETE) {
#ifdef STORED_CONFIG
                if (i != NOT_FOUND) storedConfigs = llDeleteSubList(storedConfigs, i, i + 1);
#endif
            }
            else {
                if ((conf == "controllers") || (conf == "blacklist")) {
                    string prefix = "controller"; split = llParseString2List(value, ["|"], []);
                    if (conf == "blacklist") prefix = conf;

#ifdef STORED_CONFIG
                    // Store configuration information
                    if (i == NOT_FOUND) storedConfigs += [ conf, value ];
                    else storedConfigs = llListReplaceList(storedConfigs, [ conf, value ], i, i + 1);
#endif

                    integer j = -1; integer c;
                    string uuid;
                    string name;
                    string value;
                    string confx;

                    while (j++ < 9) {
                        uuid = llList2String(split,0);
                        name = llList2String(split,1);

                        value = uuid + "|" + name;
                        confx = prefix + (string)j;

                        if ((uuid != (string)NULL_KEY) && (uuid != "") && (name != "") && (value != "|")) {
                            c++;
                            lmSendConfig(confx, value);
                        }
                        else lmSendConfig(confx, RECORD_DELETE);

                        split = llDeleteSubList(split,0,1);

#ifdef STORED_CONFIG
                        i = llListFindList(storedConfigs, [confx]);
                        if (i == NOT_FOUND) storedConfigs += [ confx, value ];
                        else storedConfigs = llListReplaceList(storedConfigs, [ confx, value ], i, i + 1);
#endif
                    }

                    lmSendConfig(prefix + "sCount", (string)c);

                    return;
                }

#ifdef STORED_CONFIG
                // Store configuration information
                if (i == NOT_FOUND) storedConfigs += [ conf, value ];
                else storedConfigs = llListReplaceList(storedConfigs, [ conf, value ], i, i + 1);

#ifdef DEVELOPER_MODE
                integer x = llGetListLength(storedConfigs) / 2;
                if (x > storedCount) {
                    storedCount = x;
                    debugSay(3, "DEBUG-LOCALDB", "Local DB now contains " + (string)storedCount + " key=>value pairs and " + cdMyScriptName() + " is using " + formatFloat((float)llGetUsedMemory() / 1024.0, 2) + "kB of memory.");
                }
#endif
#endif
            }

#ifdef DEVELOPER_MODE
            if (conf == "debugLevel")                   debugLevel = (integer)value;
            else
#endif
            if (script == cdMyScriptName()) return;
            else if (conf == "offlineMode") offlineMode = (integer)value;
        }
#ifdef STORED_CONFIG
        else if ((code == 301) || (code == 302)) {
            integer type = code - 300;
            integer i;
            integer n = llGetListLength(storedConfigs) / 2;

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
            if (i != NOT_FOUND)
                lmSendConfig("dollyName", llList2String(storedConfigs, i + 1));
        }
        else if (code == 303) {
            storedConfigs = llListSort(storedConfigs, 2, 1);

            string conf;
            integer i;

            while(split != []) {
                conf = llList2String(split,0);
                i = llListFindList(storedConfigs, [conf]);

                if (i != NOT_FOUND) lmSendConfig(conf, llList2String(storedConfigs, i + 1));

                split = llDeleteSubList(split,0,0);
                llSleep((1/llGetRegionFPS())*3); // avoid Link Message overload - sleep arbitrary num of frames
            }
        }
#endif
        else if (code == 305) {
            string cmd = llList2String(split, 0);

            split = llDeleteSubList(split, 0, 0);   // Always stick with llDeleteSubList it handles missing/null parameters eg:
                                                    // illDeleteSubList([ "Script", "cmd" ],0,1) == []
                                                    // llList2List([ "Script", "cmd" ],2,-1) == [ "Script" , "cmd" ]
                                                    // This has been the cause of bugs.

            string name = llList2String(split, 0);
            resolveName = name;

                 if (cmd == "getMistressKey")  { resolveType = MISTRESS_KEY; }
            else if (cmd == "getBlacklistKey") { resolveType = BLACKLIST_KEY; }
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

    //----------------------------------------
    // HTTP RESPONSE
    //----------------------------------------
    http_response(key request, integer status, list meta, string body) {
        integer locationIndex = llSubStringIndex(body,"\n");
        integer queryIndex = llSubStringIndex(body,"?");
        string location = llGetSubString(body, 10, queryIndex - 1);
        integer t;

        body = llStringTrim(llDeleteSubString(body, 0, locationIndex), STRING_TRIM);
        t = llGetUnixTime();

#ifdef UPDATE_METHOD_CDKEY
        if (request == requestUpdate) {
            if (llGetSubString(body, 0, 21) == "checkversion versionok") {
                if (llStringLength(body) > 22) updateCheck = (integer)llGetSubString(body, 23, STRING_END);
                lastUpdateCheck = t;
                debugSay(5, "DEBUG-SERVICES", "Next check in " + (string)updateCheck + " seconds");
                llOwnerSay("Version check completed you have the latest version.");
            }
            else if (body == "checkversion updatesent") {
                lastUpdateCheck = t;
                llOwnerSay("Version check completed your updated key is on it's way to you now.");
            }
            else if (status != 200) {
                llOwnerSay("Error, failure to contact the update server you key will continue to try or see the help notecard.  " +
                           "For alternative update options.");
                gotURL = 0;
                if (++requestIndex < llGetListLength(serverNames)) {
                    nextRetry = t + llRound(30.0 + llFrand(30.0));
                }
                else {
                    requestIndex = 0;
                    nextRetry = t + llRound(900.0 + llFrand(900.0));
                }
                lmSendConfig("nextRetry", (string)nextRetry);
            }
        }
        else
#endif
        //----------------------------------------
        // URL: /objdns/lookup

        if (location == "/objdns/lookup") {

            if (status == 200) {
                serverURL = body;
                gotURL = 1;
                requestIndex = 0;
            }
            else {
                if (++requestIndex < llGetListLength(serverNames)) {
                    nextRetry = t + llRound(30.0 + llFrand(30.0));
                }
                else {
                    requestIndex = 0;
                    nextRetry = t + llRound(900.0 + llFrand(900.0));
                }
                lmSendConfig("nextRetry", (string)nextRetry);
            }
        }

        //----------------------------------------
        // URL: /httpdb/retrieve

        else if (location == "/httpdb/retrieve") {
            llSetMemoryLimit(65536);
            string error = "HTTPdb - Database access ";

            if (status == 200) {
                lmSendConfig("databaseOnline", (string)(databaseOnline = 1));

                HTTPdbProcessStart = t;

                //llOwnerSay("Processing database reply..."); // FIXME: sometimes, this is not followed by any report - and is printed for all keys

                databaseInput = llParseStringKeepNulls(body,["\n"],[]); body = "";

                configCount = 0;
            }
            else {
                databaseReload = t + 60 + llRound(llFrand(90));

                if (databaseOnline) {
                    error += "failed: Continuing init in offline mode and will contintiue trying.";
                    lmSendConfig("databaseOnline", (string)(databaseOnline = 0));
                    llOwnerSay(error);
                }
            }

            llSetTimerEvent(0.5);
        }

        //----------------------------------------
        // URL: /name2key/lookup

        else if (location == "/name2key/lookup") {
            list split = llParseStringKeepNulls(body, ["=","\n"], []);
            string name = llList2String(split, 0);
            string uuid = llList2String(split, 1);
            string data = uuid + "|" + name;

            if (uuid == "NOT FOUND") {
                llOwnerSay("Despite much searching and checking none of our sources can identify the mysterious '" + name + "' " +
                           "not even after consulting the SL search oracle.  Are you sure that you typed the name correctly and are " +
                           "not trying to seek an alias?");
                llSleep(0.5);
                llOwnerSay("Tip: If you are sure you are typing the correct username and are not trying to enter a display name you should have them " +
                           "touch the key then try again.");
            }
            else if (resolveType == MISTRESS_KEY) {
                lmInternalCommand("addMistress", data, NULL_KEY);
            }
            else if (resolveType == BLACKLIST_KEY) {
                lmInternalCommand("addRemBlacklist", data, NULL_KEY);
            }
        }

        //----------------------------------------
        // URL: /httpdb/store

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
                    databaseOnline = YES;
                }
                lastPost = llGetTime();
            }
            else {
                if (databaseOnline) {
                    llOwnerSay("HTTPdb - Unable to update the database, falling back to offline mode until service recovers.");
                    databaseOnline = NO;
                    curInterval += curInterval;
                    myMod = llFloor(llFrand((float)curInterval - 0.000001));
                }
            }
        }

        //----------------------------------------
        // URL: /name2key/add

        else if (location == "/name2key/add") {
            list split = llParseStringKeepNulls(body, [ "|" ], []);
            integer new = llList2Integer(split, 1);
            integer old = llList2Integer(split, 2);

            debugSay(5, "DEBUG-SERVICES", "Posted " + (string)(old + new) + " keys: " + (string)new + " new, " + (string)old + " old");
        }

        //----------------------------------------
        // URL: /httpdb/retreive

        else if (location != "/httpdb/retreive") {
#ifdef DEVELOPER_MODE
            integer debug;
            if (status == 200) debug = 7;
            else debug = 1;

            debugSay(debug, "DEBUG-SERVICES-RAW", "HTTP " + (string)status + "|" + body);
#endif

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

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            cdPermSanityCheck();
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        integer k = 16;

        list splitLine;
        string line;
        string name;
        string value;
        integer i;

        // Maximum length of databaseInput processed: 16
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
                // FIXME: Handle old variables: should be removed as soon as is practical

                if ((name == "controllers") || (name == "MistressList")) {
                    if (llListFindList(storedConfigs,["controllersCount"]) == NOT_FOUND) {
                        lmSendConfig(name, value);                                  // This list variable has had occasional issues with durability and is rather tricky to validate the new type
                                                                                    // controller records are available in the database for this user so we will use those to rebuild the internal
                                                                                    // controllers from a clean slate instead.
                    }
                }
                else if (llGetSubString(name,0,9) == "controller") {
                    if ((llGetSubString(name,-2,STRING_END) == "ID") || (llGetSubString(name,-4,STRING_END) == "Name")) {
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
                    if ((llGetSubString(name,-2,STRING_END) == "ID") || (llGetSubString(name,-4,STRING_END) == "Name")) {
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
                    if (llListFindList(storedConfigs,[name]) == NOT_FOUND) storedConfigs += [ name, value ];

                    configCount++;
                }
            }
        }

        if (!llGetListLength(databaseInput)) {
            float t = llGetTime();
#ifdef STORED_CONFIG
#ifdef DEVELOPER_MODE
            i = (llGetListLength(storedConfigs) / 2);

            if (i > storedCount) {
                storedCount = i;
                debugSay(3, "DEBUG-LOCALDB", "Local DB now contains " + (string)storedCount + " key=>value pairs and " + cdMyScriptName() + " is using " + formatFloat((float)llGetUsedMemory() / 1024.0, 2) + "kB of memory.");
            }
#endif
#endif

#ifdef DEVELOPER_MODE
            string eventTime = formatFloat((HTTPdbProcessStart - HTTPdbStart) * 1000, 2);

            debugSay(5, "DEBUG-SERVICES", "Service post interval setting " + formatFloat(HTTPinterval, 2) + "s throttle setting " + formatFloat(HTTPthrottle, 2) + "s");

            string msg = "HTTPdb - Processed " + (string)configCount + " records ";

            if (lastPostTimestamp) msg += "with updates since our last post " + (string)((llGetUnixTime() - lastPostTimestamp) / 60) + " minutes ago ";

            msg += "event time " + eventTime + ", processing time " + formatFloat(((t - HTTPdbProcessStart) * 1000), 2) +
                   "ms, total time for DB transaction " + formatFloat((t - HTTPdbStart) * 1000, 2) + "ms";

            debugSay(1, "DEBUG-SERVICES", msg);

            // If debugLevel is 0, then return to normal minimalist message
            if (!debugLevel) {
                debugSay(3,"DEBUG-SERVICES","Successfully processed database reply in " + formatFloat(t - HTTPdbStart * 1000, 2) + "ms");
            }
#endif
            databaseReload = 600;

            llSetTimerEvent(0.0);
            lmConfigComplete(configCount);
        }
    }
}
