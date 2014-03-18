//========================================
// ServiceRequester.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/GlobalDefines.lsl"

#include "include/Secure.lsl"
#include "include/ServiceIncludes.lsl"

integer useHTTPS = 1;
string DataURL;
key requestDataURL;

string correctName(string name) {
    // Many new SL users fail to undersand the meaning of "Legacy Name" the name format of the DB
    // and many older SL residents confuse usernames and legasy names.  This function checks for
    // the presence of features inidcating we have been supplied with an invalid name which seems tp
    // be encoded in username format and makes the converstion to the valid legacy name.
    integer index;

    list split = llParseStringKeepNulls(name, [ "."," " ], []);
    integer n = llGetListLength(split);
    if (n == 0) {
        llOwnerSay("You must enter a username or legacy name.");
        return "INVALID";
    }
    else if (n == 1)    name = llList2String(split, 0) + " Resident";
    else if (n == 2)    name = llList2String(split, 0) + " " + llList2String(split, 1);
    else {
        llOwnerSay("The name " + name + " does not appear to be  valid username or legacy name, there should only be one period (.) or space ( )");
        return "INVALID";
    }

    return llToLower(name);
}

default
{
    state_entry() {
        if (llGetInventoryType(".offline") != INVENTORY_NONE) {
            lmSendConfig("offlineMode", (string)(offlineMode = 1));
            invMarker = 1;
        }
        else lmSendConfig("offlineMode", (string)(offlineMode = 0));
        myMod = llFloor(llFrand(5.999999));
        serverNames = llListRandomize(serverNames, 1);
        cdPermSanityCheck();
        
        llSleep(1.0);
        requestDataURL = llGetNotecardLine("DataServices",0);
        
        cdInitializeSeq();
    }
    
    dataserver(key request, string data) {
        if (request == requestDataURL) {
            DataURL = data;
        
            string time = (string)llGetUnixTime();
            HTTPdbStart = llGetTime();
            debugSay(3, "DEBUG-SERVICES", "Requesting data from HTTPdb");
    
            string hashStr = (string)llGetOwner() + time + SALT;
            string requestURI = getURL("httpdb") + "retrieve?q=" + llSHA1String(hashStr) + "&p=cdkey&t=" + time + "&s=" + (string)lastGetTimestamp;
            while((requestID = llHTTPRequest(requestURI, HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                llSleep(1.0);
            }
        }
    }

    on_rez(integer start) {
        serverNames = llListRandomize(serverNames, 1);
        myMod = llFloor(llFrand(5.999999));
        cdPermSanityCheck();

        rezzed = 1;
        configured = 0;
        
        llSleep(3.0);

        string time = (string)llGetUnixTime();
        HTTPdbStart = llGetTime();
        debugSay(3, "DEBUG-SERVICES", "Requesting data from HTTPdb");
    
        string hashStr = (string)llGetOwner() + time + SALT;
        string requestURI = getURL("httpdb") + "retrieve?q=" + llSHA1String(hashStr) + "&p=cdkey&t=" + time + "&s=" + (string)lastGetTimestamp;
        while((requestID = llHTTPRequest(requestURI, HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
            llSleep(1.0);
        }
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

            while ((requestID = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE,
                "application/x-www-form-urlencoded" ], "names[0]" + "=" + llEscapeURL(name) + "&uuids[0]" + "=" + llEscapeURL(uuid)))) == NULL_KEY) {
                    llSleep(1.0);
            }
        }
        // For users document as a tip if they want to add a user by chat command to simply retry after
        // having the avatar touch the key (or any cdkey for that matter).
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
            configured = 1;
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

            if (script == "Main" && name == "timeLeftOnKey") {
                if (databaseReload && (databaseReload < llGetUnixTime())) {
                    databaseReload = llGetUnixTime() + 120;
                    string time = (string)llGetUnixTime();
                    HTTPdbStart = llGetTime();
                    
                    debugSay(3, "DEBUG-SERVICES", "Requesting data from HTTPdb");

                    string hashStr = (string)llGetOwner() + time + SALT;
                    string requestURI = getURL("httpdb") + "retrieve?q=" + llSHA1String(hashStr) + "&p=cdkey&t=" + time + "&s=" + (string)lastGetTimestamp;
                    while((requestID = llHTTPRequest(requestURI, HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                        llSleep(1.0);
                    }
                }
                if (llGetListLength(serverNames)) {
                    if (!gotURL && nextRetry < llGetUnixTime())
                    while ((requestName = llHTTPRequest(getURL("objdns") + "lookup?q=" + llEscapeURL(llList2String(serverNames, requestIndex)),
                            HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) llSleep(1.0);
                    if (gotURL && (lastUpdateCheck < (llGetUnixTime() - updateCheck))) {
                        lastUpdateCheck = llGetUnixTime();
                        queForSave("lastUpdateCheck", (string)lastUpdateCheck);
                        while ((requestID = llHTTPRequest(serverURL, HTTP_OPTIONS + [ "POST" ], "checkversion " + (string)PACKAGE_VERNUM)) == NULL_KEY) llSleep(1.0);
    
                    }
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

            if (script == cdMyScriptName()) return;
            if ((llGetSubString(name,0,9) != "controller") && (llGetSubString(name,0,8) != "blacklist" )) {
                if (!configured && (script == "ServiceReceiver")) return;
            }

            else if (name == "offlineMode") {
                offlineMode = (integer)value;
                dbPostParams = [];
            }
            if (!offlineMode) {
                value = llDumpList2String(llDeleteSubList(split, 0, 0), "|");
                queForSave(name, value);
            }
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if ((cmd == "getBlacklistKey") || (cmd == "getMistressKey")) {
                lmSendConfig("listID", (string)id);
                string name = correctName(llList2String(split, 0));
#ifdef DEVELOPER_MODE
                debugSay(5, "DEBUG-SERVICES", "Looking up name " + name);
#endif
                while((requestID = llHTTPRequest(getURL("name2key") + "lookup?q=" + llEscapeURL(name), HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                    llSleep(1.0);
                }
            }
            else if (cmd == "getTimeUpdates") lastTimeRequest = llGetUnixTime();
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
            string type = llList2String(split, 0);
            string value = llList2String(split, 1);

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
            else if (type == "useHTTPS") useHTTPS = (integer)value;
        }
    }

    timer() {
        if (llGetTime() > postSendTimeout) {
            doHTTPpost();
            llSetTimerEvent(0.0);
        }
    }
}
