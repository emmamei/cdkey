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
integer resolveType;
key resolveTestKey;

key requestDataName;

default {
    state_entry() {
        cdPermSanityCheck();
    }

    on_rez(integer start) {
        cdPermSanityCheck();
        rezzed = 1;
    }

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        string script = llList2String(split, 0);

        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;

            if (!rezzed && (code == 105)) lmInitState(initState++);
        }
        else if (code == 110) {
            initState = 105;
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);

#ifdef DEVELOPER_MODE
            if (name == "debugLevel")                   debugLevel = (integer)value;
            else if (script == SCRIPT_NAME) return;
#else
            if (script == SCRIPT_NAME) return;
#endif
            else if (name == "offlineMode") {
                offlineMode = (integer)value;
                dbPostParams = [];
            }
        }
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 1);   // Always stick with llDeleteSubList it handles missing/null parameters eg:
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
        else if (location == "https://api.silkytech.com/objdns/lookup") {
#else
        if (location == "https://api.silkytech.com/objdns/lookup") {
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
        else if (location == "https://api.silkytech.com/httpdb/retrieve") {
            llSetMemoryLimit(65536);
            string error = "HTTPdb - Database access ";

            integer configCount;

            if (status == 200) {
                lmSendConfig("databaseOnline", (string)(databaseOnline = 1));

                float HTTPdbProcessStart;
                string eventTime = formatFloat(((HTTPdbProcessStart = llGetTime()) - HTTPdbStart) * 1000, 2);


                do {
                    integer nextNewLine = llSubStringIndex(body, "\n");
                    if (nextNewLine == -1) nextNewLine = llStringLength(body);

                    string line = llDeleteSubString(body, nextNewLine, llStringLength(body));
                    body = llDeleteSubString(body, 0, nextNewLine);

                    integer splitIndex = llSubStringIndex(line, "=");
                    string Key = llDeleteSubString(line, splitIndex, llStringLength(line));
                    string Value = llDeleteSubString(line, 0, splitIndex);

                    if (Value == "") Value = "";

                    if (Key == "useHTTPS") useHTTPS = (integer)Value;
                    else if (Key == "HTTPinterval") HTTPinterval = (float)Value;
                    else if (Key == "HTTPthrottle") HTTPthrottle = (float)Value;
                    else if (Key == "updateCheck") updateCheck = (integer)Value;
                    else if (Key == "lastGetTimestamp") {
                        lastGetTimestamp = (integer)Value;
                        lmServiceMessage("lastGetTimestamp", (string)(Value), NULL_KEY);
                    }
                    //else if (Key == "MistressListNew") handleAvList(Value, 1, 0);
                    //else if (Key == "MistressList") handleAvList(Value, 1, 1);
                    //else if (Key == "blacklistNew") handleAvList(Value, 2, 0);
                    //else if (Key == "blacklist") handleAvList(Value, 2, 1);
                    else if (Key == "windTimes") lmInternalCommand("setWindTimes", Value, NULL_KEY);
                    else {
                        lmSendConfig(Key, Value);
                        configCount++;
                    }

                    if (useHTTPS) protocol = "https://";
                    else protocol = "http://";
                } while (llStringLength(body));

#ifdef DEVELOPER_MODE
                debugSay(5, "DEBUG-SERVICES", "Service post interval setting " + formatFloat(HTTPinterval, 2) + "s throttle setting " + formatFloat(HTTPthrottle, 2) + "s");

                string msg = "HTTPdb - Processed " + (string)configCount + " records ";
                if (lastPostTimestamp) msg += "with updates since our last post " + (string)((llGetUnixTime() - lastPostTimestamp) / 60) + " minutes ago ";
                msg += "event time " + eventTime + ", processing time " + formatFloat(((llGetTime() - HTTPdbProcessStart) * 1000), 2);
                msg += "ms, total time for DB transaction " + formatFloat((llGetTime() - HTTPdbStart) * 1000, 2) + "ms";
                debugSay(2, "DEBUG-SERVICES", msg);
#endif

                databaseReload = 0;
            }
            else {
                databaseReload = llGetUnixTime() + llRound(llFrand(90));
                if (databaseOnline) {
                    error += "failed: Continuing init in offline mode and will contintiue trying.";
                    lmSendConfig("databaseOnline", (string)(databaseOnline = 0));
                    llOwnerSay(error);
                }
            }

            lmConfigComplete(configCount);

            lmInitState(initState++);
        }
        else if (location == "https://api.silkytech.com/name2key/lookup") {
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
            else if (llGetSubString((resolveName = name),0,0) == "*") { // Backup result via SL search, this cannot be fully reliable always verify! Reasons inc:
                                                        // 1. If the query is an exact match to a name SL search returns one result, it will otherwise fall back
                                                        //    itself to a related search mode which includes searching on display names that may trigger false +ve
                                                        // 2. Even when the result is valid SL search does not give a properly cannoicized name they are always in
                                                        //    lcase however llRequestAgentData will return correctly and will meet the data quality standards of db
                                                        // 3. Verified data can be posted back to the DB for faster lookups in future, SL search is not an
                                                        //    acceptable data source to do this.
                requestDataName = llRequestAgentData((resolveTestKey = uuid), DATA_NAME);
            }
            else if (llGetSubString((resolveName = name),0,0) == "+") { // Multiple matches
                integer index = llListFindList(split, [resolveName]);
                if (index == NOT_FOUND) { // Multiple matches and no exact matches
                    string listOfNames = "Potential matches found if you see the one you want to add just run the command again with the full name.\n" +                                                    llDeleteSubString(name,0,0); integer i;
                    for (i = 2; i < llGetListLength(split); i += 2) {
                        listOfNames += "\n" + llDeleteSubString(llList2String(split, i),0,0);
                    }
                    llOwnerSay(listOfNames);
                }
            }
            else if (resolveType == 1) {
                lmInternalCommand("addMistress", uuid + "|" + name, NULL_KEY);
            }
            else if (resolveType == 2) {
                lmInternalCommand("addRemBlacklist", uuid + "|" + name, NULL_KEY);
            }
        }
        else if (location == "https://api.silkytech.com/httpdb/store") {
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
        else if (location == "https://api.silkytech.com/name2key/add") {
            list split = llParseStringKeepNulls(body, [ "|" ], []);
            integer new = llList2Integer(split, 1);
            integer old = llList2Integer(split, 2);

            debugSay(5, "DEBUG-SERVICES", "Posted " + (string)(old + new) + " keys: " + (string)new + " new, " + (string)old + " old");
        }

        if (location != "https://api.silkytech.com/httpdb/retreive") {
#ifdef DEVELOPER_MODE
            integer debug;
            if (status == 200) debug = 7;
            else debug = 1;

            debugSay(debug, "DEBUG-SERVICES-RAW", "HTTP " + (string)status);
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

    changed(integer change) {
        if (change & CHANGED_OWNER) {
            cdPermSanityCheck();
        }
    }

    dataserver(key request, string data) {
        if (request = requestDataName) {
            string uuid = (string)resolveTestKey;
            string name = llToLower(resolveName);
            if (llToLower(data) == name) {
                string name = data; // Name matches at least case insensitively

                if (resolveType == 1) lmInternalCommand("addMistress", uuid + "|" + data, NULL_KEY);
                else if (resolveType == 2) lmInternalCommand("addRemBlacklist", uuid + "|" + data, NULL_KEY);

                string namepost = "names[0]" + "=" + llEscapeURL(name) + "&" +
                                  "uuids[0]" + "=" + llEscapeURL(uuid);
                while ((requestID = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE,
                    "application/x-www-form-urlencoded" ], namepost))) == NULL_KEY) {
                        llSleep(1.0);
                }
            }
            else {
                llOwnerSay("Despite much searching and checking none of our sources can identify the mysterious '" + data + "' " +
                           "not even after consulting the SL search oracle.  Are you sure that you typed the name correctly and are " +
                           "not trying to seek an alias?");
                llSleep(0.5);
                llOwnerSay("Tip: If you are sure you are typing the correct username and are not trying to enter a display name you should have them " +
                           "touch the key then try again.");
            }
        }
    }
}
