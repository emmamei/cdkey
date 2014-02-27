//========================================
// ServiceReceiver.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/GlobalDefines.lsl"
#include "include/ServiceIncludes.lsl"

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
            list split = llParseStringKeepNulls(body, [ "=" ], []);
            string name = llList2String(split, 0);
            string uuid = llList2String(split, 1);
            integer index;
            if (uuid == "NOT FOUND") {
                llOwnerSay("Failed to find " + name + " in the name2key database, please check the name is correct and in legacy name format.  If the name is correct it is probably safe to ignore this message and the database will be updated when " + name + " touches your key next.");
            }
            else if (name == "") {
                checkNames += [ llRequestAgentData(uuid, DATA_NAME), uuid ];
            }
            else if (request == requestMistressKey) {
                index = llListFindList(unresolvedMistressNames, [ llToLower(name) ]);
                unresolvedMistressNames = llDeleteSubList(unresolvedMistressNames, index, index);
                lmInternalCommand("addMistress", uuid + "|" + name, NULL_KEY);
            }
            else if (request == requestBlacklistKey) {
                index = llListFindList(unresolvedBlacklistNames, [ llToLower(name) ]);
                unresolvedBlacklistNames = llDeleteSubList(unresolvedBlacklistNames, index, index);
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
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            cdPermSanityCheck();
        }
    }
}
