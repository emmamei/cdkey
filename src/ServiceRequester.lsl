//========================================
// ServiceRequester.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/GlobalDefines.lsl"
#include "include/ServiceIncludes.lsl"

default
{
    state_entry() {
        llSetMemoryLimit(65536);
        myMod = llFloor(llFrand(5.999999));
        serverNames = llListRandomize(serverNames, 1);
    }

    on_rez(integer start) {
        serverNames = llListRandomize(serverNames, 1);
        myMod = llFloor(llFrand(5.999999));

        rezzed = 1;
    }

    attach(key id) {
        if (keyHandler == llGetKey() && id == NULL_KEY) {
            llRegionSay(broadcastOn, "keys released");
#ifdef DEVELOPER_MODE
            debugSay(5, "BROADCAST-DEBUG", "Broadcast sent: keys released");
#endif
            lmSendConfig("keyHandler", (string)(keyHandler = NULL_KEY));
        }
    }

    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryType(".offline") != INVENTORY_NONE) {
                lmSendConfig("offlineMode", (string)(offlineMode = 1));
                invMarker = 1;
            }
            else if (invMarker) {
                lmSendConfig("offlineMode", (string)(offlineMode = 0));
                invMarker = 0;
            }
        }
        if (change & (CHANGED_REGION | CHANGED_TELEPORT)) {
            oldAvatars = [];
        }
    }

    touch_start(integer num) {
        integer index = llListFindList(unresolvedBlacklistNames, [ llToLower(llDetectedName(0)) ]);
        if (index != NOT_FOUND) {
            llOwnerSay("Identified Blacklist user " + llDetectedName(0) + " on key touch");
            unresolvedBlacklistNames = llDeleteSubList(unresolvedBlacklistNames, index, index);
            lmInternalCommand("addRemBlacklist", (string)llDetectedKey(0) + "|" + llDetectedName(0), NULL_KEY);
        }
        else {
            index = llListFindList(unresolvedMistressNames, [ llToLower(llDetectedName(0)) ]);
            if (index != NOT_FOUND) {
                llOwnerSay("Identified Controller " + llDetectedName(0) + " on key touch");
                unresolvedMistressNames = llDeleteSubList(unresolvedMistressNames, index, index);
                lmInternalCommand("addMistress", (string)llDetectedKey(0) + "|" + llDetectedName(0), NULL_KEY);
            }
        }
        if (index != NOT_FOUND) {
            while((requestAddKey = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE,
                "application/x-www-form-urlencoded" ], "name=" + llEscapeURL(llDetectedName(0)) + "&uuid=" + llEscapeURL((string)llDetectedKey(0))))) == NULL_KEY) {
                    llSleep(1.0);
            }
            lmSendRequestID("AddKey", requestID);
        }
    }

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);

        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;

            if (rezzed || (code == 104)) {
                string time = (string)llGetUnixTime();
                HTTPdbStart = llGetTime();
#ifdef DEVELOPER_MODE
                debugSay(6, "DEBUG-SERVICES", "Requesting data from HTTPdb");
#endif
                string hashStr = (string)llGetOwner() + time + SALT;
                string requestURI = "https://api.silkytech.com/httpdb/retrieve?q=" + llSHA1String(hashStr) + "&t=" + time + "&s=" + (string)lastGetTimestamp;
                if  (!offlineMode) {
                    while((requestID = llHTTPRequest(requestURI, HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                        llSleep(1.0);
                    }
                    lmSendRequestID("LoadDB", requestID);
                }
            }

            lmInitState(code);
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

            if (script == "Main" && name == "timeLeftOnKey") {
                if (databaseReload && (databaseReload < llGetUnixTime())) {
                    databaseReload = llGetUnixTime() + 120;
                    string time = (string)llGetUnixTime();
                    HTTPdbStart = llGetTime();
#ifdef DEVELOPER_MODE
                    debugSay(6, "DEBUG-SERVICES", "Requesting data from HTTPdb");
#endif
                    string hashStr = (string)llGetOwner() + time + SALT;
                    string requestURI = "https://api.silkytech.com/httpdb/retrieve?q=" + llSHA1String(hashStr) + "&t=" + time + "&s=" + (string)lastGetTimestamp;
                    while((requestID = llHTTPRequest(requestURI, HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                        llSleep(1.0);
                    }
                    lmSendRequestID("LoadDB", requestID);
                }
                if (!gotURL && nextRetry < llGetUnixTime())
                while ((requestName = llHTTPRequest(protocol + "api.silkytech.com/objdns/lookup?q=" + llEscapeURL(llList2String(serverNames, requestIndex)),
                        HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) llSleep(1.0);
                if (gotURL && (lastUpdateCheck < (llGetUnixTime() - updateCheck))) {
                    lastUpdateCheck = llGetUnixTime();
                    queForSave("lastUpdateCheck", (string)lastUpdateCheck);
                    while ((requestID = llHTTPRequest(serverURL, HTTP_OPTIONS + [ "POST" ], "checkversion " + (string)PACKAGE_VERNUM)) == NULL_KEY) llSleep(1.0);
                    lmSendRequestID("Update", requestID);

                }
                if ((keyHandler == NULL_KEY) || (keyHandlerTime < (llGetTime() - 60))) {
                    keyHandler = llGetKey();
                }
                if (keyHandler == llGetKey()) {
                    llRegionSay(broadcastOn, "keys claimed");
#ifdef DEVELOPER_MODE
                    debugSay(5, "BROADCAST-DEBUG", "Broadcast Sent: keys claimed");
#endif
                    lmSendConfig("keyHandler", (string)(keyHandler = llGetKey()));
                    keyHandlerTime = llGetTime();
                    checkAvatarList();
                }
            }

            if (name == "debugLevel") debugLevel = (integer)value;
            else if (name == "lastUpdateCheck") lastUpdateCheck = (integer)value;
            else if (name == "nextRetry") nextRetry = (integer)value;
            else if (name == "keyHandler") {
                keyHandler = (key)value;
                keyHandlerTime = llGetTime();
            }
            else if (name == "keyHandlerTime") {
                keyHandlerTime = llGetTime() - (float)(llGetUnixTime() - (integer)value);
            }

            if ((script == "ServiceReceiver") || (script == SCRIPT_NAME)) return;

            else if (name == "offlineMode") {
                offlineMode = (integer)value;
                dbPostParams = [];
            }
            if (!offlineMode) {
                value = llDumpList2String(llList2List(split, 2, -1), "|");
                queForSave(name, value);
            }
        }
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);

            if (cmd == "getMistressKey") {
                string name = llList2String(split, 0);
#ifdef DEVELOPER_MODE
                debugSay(5, "DEBUG-SERVICES", "Looking up name " + name);
#endif
                unresolvedMistressNames += llToLower(name);
                while((requestID = llHTTPRequest("http://api.silkytech.com/name2key/lookup?q=" + llEscapeURL(name), HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                    llSleep(1.0);
                }
                lmSendRequestID("MistressKey", requestID);
            }
            else if (cmd == "getBlacklistKey") {
                string name = llList2String(split, 0);
#ifdef DEVELOPER_MODE
                debugSay(5, "DEBUG-SERVICES", "Looking up name " + name);
#endif
                unresolvedBlacklistNames += llToLower(name);
                while((requestID = llHTTPRequest("http://api.silkytech.com/name2key/lookup?q=" + llEscapeURL(name), HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                    llSleep(1.0);
                }
                lmSendRequestID("BlacklistKey", requestID);
            }
        }
        else if (code == 500) {
            string selection = llList2String(split, 0);

            if (selection == "Check Update") {
                lastUpdateCheck = 0;
                llOwnerSay("Error, failure to contact the update server you key will continue to try or see the help notecard.  " +
                           "For alternative update options.");
            }
        }
    }

    dataserver(key request, string data) {
        integer index = llListFindList(checkNames, [ request ]);
        if (index != NOT_FOUND) {
            string uuid = llList2Key(checkNames, index + 1);
            string name = data;

            checkNames = llDeleteSubList(checkNames, index, index + 1);
            index = llListFindList(unresolvedMistressNames, [ llToLower(data) ]);
            if (index != NOT_FOUND) {
                unresolvedMistressNames = llDeleteSubList(unresolvedMistressNames, index, index);
                lmInternalCommand("addMistress", uuid + "|" + name, NULL_KEY);
            }
            else {
                index = llListFindList(unresolvedBlacklistNames, [ llToLower(data) ]);
                unresolvedBlacklistNames = llDeleteSubList(unresolvedBlacklistNames, index, index);
                lmInternalCommand("addRemBlacklist", uuid + "|" + name, NULL_KEY);
            }
            string namepost = "names[0]" + "=" + name + "&" +
                              "uuids[0]" + "=" + llEscapeURL(uuid);
            while ((requestID = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE,
                "application/x-www-form-urlencoded" ], namepost))) == NULL_KEY) {
                    llSleep(1.0);
            }
            lmSendRequestID("AddKey", requestID);
        }
    }

    timer() {
        doHTTPpost();
        llSetTimerEvent(0.0);
    }
}
