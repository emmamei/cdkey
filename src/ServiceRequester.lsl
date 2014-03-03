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
        myMod = llFloor(llFrand(5.999999));
        serverNames = llListRandomize(serverNames, 1);
        cdPermSanityCheck();
    }

    on_rez(integer start) {
        serverNames = llListRandomize(serverNames, 1);
        myMod = llFloor(llFrand(5.999999));
        cdPermSanityCheck();
        
        llSleep(1.0);
        
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
        if (change & (CHANGED_OWNER)) {
            cdPermSanityCheck();
        }
    }

    touch_start(integer num) {
        // The old code stored names potentially indefinately not a good idea, better way
        lastKeyPost = llGetTime() - 30.0 * HTTPinterval; // Set the last post time to twice the max age limit

        integer i;
        for (i = 0; i < num; i++) { // Handle all touch_starts (can be up to 16 per event
                                    // and make sure the avatars are in the list
            string name = llDetectedName(i);
            string uuid = llDetectedKey(i);

            string adding = "names[" + (string)namepostcount + "]" + "=" + llEscapeURL(name) + "&" +
                            "uuids[" + (string)namepostcount++ + "]" + "=" + llEscapeURL(uuid);

            if (namepost != "") namepost += "&";
            namepost += adding;
        }

        checkAvatarList(); // Run the check immidiately and do the post

        // For users document as a tip if they want to add a user by chat command to simply retry after
        // having the avatar touch the key (or any cdkey for that matter).
    }

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);

        if (code == 102) {
            scaleMem();
        }
        else if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;

            if (code == 104) {
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
                    if ((keyHandlerTime + HTTPinterval) < llGetTime()) {
                        lmSendConfig("keyHandler", (string)(keyHandler = llGetKey()));
                        keyHandlerTime = llGetTime();
                    }
                    checkAvatarList();
                }
                scaleMem();
            }

            if (name == "lastUpdateCheck") lastUpdateCheck = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel") debugLevel = (integer)value;
#endif
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
                while((requestID = llHTTPRequest("http://api.silkytech.com/name2key/lookup?q=" + llEscapeURL(name), HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                    llSleep(1.0);
                }
            }
            else if (cmd == "getBlacklistKey") {
                string name = llList2String(split, 0);
#ifdef DEVELOPER_MODE
                debugSay(5, "DEBUG-SERVICES", "Looking up name " + name);
#endif
                while((requestID = llHTTPRequest("http://api.silkytech.com/name2key/lookup?q=" + llEscapeURL(name), HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                    llSleep(1.0);
                }
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
        else if (code == 850) {
            string type = llList2String(split, 1);
            string value = llList2String(split, 2);

            if (type == "lastPostTimestamp") {
                lastPostTimestamp = (integer)value;
                dbPostParams = [];
            }
            else if (type == "lastGetTimestamp") lastGetTimestamp = (integer)value;
            else if (type == "lastPost") lastPost = (float)value;
            else if (type == "nextRetry") nextRetry = (integer)value;
            else if (type == "serverURL") serverURL = value;
            else if (type == "HTTPthrottle") HTTPthrottle = (float)value;
            else if (type == "HTTPinterval") HTTPinterval = (float)value;
            else if (type == "updateCheck") updateCheck = (integer)value;
            else if (type == "lastUpdateCheck") lastUpdateCheck = (integer)value;
            else if (type == "useHTTPS") {
                if (value) protocol = "https://";
                else protocol = "http://";
            }
        }
    }

    timer() {
        doHTTPpost();
        llSetTimerEvent(0.0);
    }
}
