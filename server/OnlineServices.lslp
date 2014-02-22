#define DEBUG_LEVEL 9
#include "include/GlobalDefines.lsl"
#include "include/Secure.lsl"

key keyHandler = NULL_KEY;
key requestName;
key requestUpdate;
key requestMistressKey;
key requestBlacklistKey;
key requestSendDB;
key requestLoadDB;
key requestAddKey;
list unresolvedMistressNames;
list unresolvedBlacklistNames;
list MistressList;
list blacklist;
list checkNames;
list HTTP_OPTIONS = [ HTTP_BODY_MAXLENGTH, 16384, HTTP_VERBOSE_THROTTLE, FALSE, HTTP_METHOD ]; 
list NO_STORE = [ "keyHandler", "keyHandlerTime" ];
float keyHandlerTime;
float lastAvatarCheck;
float lastKeyPost;
float lastPost;
float HTTPdbStart;
float HTTPthrottle = 20.0;
float HTTPinterval = 60.0;
integer broadcastOn = -1873418555;
integer namepostcount;
integer expeditePost;
integer MistressWaiting = -1;
integer blacklistWaiting = -1;
integer stdInterval = 6;
integer curInterval = stdInterval;
integer lastUpdateCheck;
integer requestIndex;
integer nextRetry;
integer gotURL;
integer firstRun = 1;
integer initCode;
integer initState = 104;
integer ticks;
integer offlineMode;
integer invMarker;
integer myMod;
integer lastPostTimestamp;
integer lastGetTimestamp;
integer databaseOnline = 1;
integer databaseReload;
integer updateCheck = 10800;
integer useHTTPS = 1;

string serverURL;
string protocol = "https://";
string namepost;
list dbPostParams;
list updateList;

list serverNames = [
    "cdkeyserver.secondlife.silkytech.com",
    "cdkeyserver2.secondlife.silkytech.com"
];

list oldAvatars;

queForSave(string name, string value) {
    if (llListFindList(NO_STORE, [ name ]) != -1) return;
    if (name == "MistressList") name = "MistressListNew";
    if (name == "blacklist") name = "blacklistNew";
    integer index = llListFindList(dbPostParams, [ name ]);
    if (index != -1 && index % 2 == 0) 
        dbPostParams = llListReplaceList(dbPostParams, [ name, llEscapeURL(value) ], index, index + 1);
    else dbPostParams += [ name, llEscapeURL(value) ];
    debugSay(5, "DEBUG-SERVICES", "Queued for save: " + name + "=" + value);
    //if (llListFindList(SKIP_EXPEDITE, [ name ]) == -1) expeditePost = 1;
    llSetTimerEvent(5.0);
}

checkAvatarList() {
    list newAvatars = llListSort(llGetAgentList(AGENT_LIST_REGION, []), 1, 1);
    list curAvatars = newAvatars;
    integer i; integer n = llGetListLength(newAvatars);
    integer posted; float postAge = llGetTime() - lastKeyPost;
    float HTTPlimit = HTTPinterval * 15.0;
    while (i < n) {
        key uuid;
        if (llListFindList(oldAvatars, [ (uuid = llList2Key(newAvatars, i)) ]) == -1) {
            string name = llEscapeURL(llKey2Name(uuid));
            //if ((name != "") && (uuid != NULL_KEY)) name2keyQueue += [ name, uuid ];
            if ((name != "") && (uuid != NULL_KEY) && (llSubStringIndex(namepost, "=" + name + "&") == -1)) {
                integer postlen;
                string adding = "names[" + (string)namepostcount + "]" + "=" + name + "&" +
                                "uuids[" + (string)namepostcount + "]" + "=" + llEscapeURL(uuid);
                if ((postlen = ((llStringLength(namepost + adding) + 1) < 4096)) && (postAge < HTTPlimit)) {
                    if (namepost != "") namepost += "&";
                    namepost += adding;
                    namepostcount++;
                }
                else {
                    debugSay(5, "DEBUG-SERVICES", "name2key: posting " + (string)namepostcount + " keys (" + (string)llStringLength(namepost) + " bytes) interval: " +
                                formatDuration(llGetTime() - lastKeyPost, 0) + " mins");
                    while ((requestAddKey = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE,
                        "application/x-www-form-urlencoded" ], namepost))) == NULL_KEY) {
                            llSleep(1.0);
                    }
                    lastKeyPost = llGetTime();
                    lastPost = lastKeyPost;
                    postAge = llGetTime() - lastKeyPost;
                    namepost = "names[0]" + "=" + name + "&" +
                               "uuids[0]" + "=" + llEscapeURL(uuid);
                    namepostcount = 1;
                    posted = 1;
                }
            }
            i++;
        }
        else {
            newAvatars = llDeleteSubList(newAvatars, i, i);
            n--;
        }
    }
    if (namepost != "" && n != 0) debugSay(5, "DEBUG-SERVICES", "Queued post " + (string)namepostcount + " keys (" + (string)llStringLength(namepost) + " bytes) oldest: " +
                                formatDuration(llGetTime() - lastKeyPost, 0) + " mins");
    lastAvatarCheck = llGetTime();
    oldAvatars = curAvatars;
}

doHTTPpost() {
    if (offlineMode) {
        dbPostParams = [];
        return;
    }
    if ((lastPost + HTTPthrottle) < llGetTime()) {
        if (llGetListLength(dbPostParams) == 0) return;
        string time = (string)llGetUnixTime();
        string dbPostBody;
        updateList = [ ];
        if (llGetListLength(dbPostParams) != 0) {
            dbPostParams = llListSort(dbPostParams, 2, 1);
            integer index; integer i;
            for (i = 0; i < llGetListLength(dbPostParams); i = i + 2) {
                dbPostBody += "&" + llList2String(dbPostParams, i) + "=" + llList2String(dbPostParams, i + 1);
                updateList += llList2String(dbPostParams, i);
            }
        }

        while ((requestSendDB = llHTTPRequest(protocol + "api.silkytech.com/httpdb/store?q=" + llSHA1String(dbPostBody + (string)llGetOwner() + time + SALT) +
            "&t=" + time, HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded" ], dbPostBody)) == NULL_KEY) {
                llSleep(1.0);
        }
    }
    else {
        float ThrottleTime = lastPost - llGetTime() + HTTPthrottle;
        if (!expeditePost) ThrottleTime += HTTPinterval - HTTPthrottle;
        llSetTimerEvent(ThrottleTime);
        expeditePost = 0;        
    }
}

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
    }
    
    attach(key id) {
        if (keyHandler == llGetKey() && id == NULL_KEY) {
            llRegionSay(broadcastOn, "keys released");
            debugSay(5, "BROADCAST-DEBUG", "Broadcast sent: keys released");
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
        if (index != -1) {
            llOwnerSay("Identified Blacklist user " + llDetectedName(0) + " on key touch");
            unresolvedBlacklistNames = llDeleteSubList(unresolvedBlacklistNames, index, index);
            lmInternalCommand("addRemBlacklist", (string)llDetectedKey(0) + "|" + llDetectedName(0), NULL_KEY);
        }
        else {
            index = llListFindList(unresolvedMistressNames, [ llToLower(llDetectedName(0)) ]);
            if (index != -1) {
                llOwnerSay("Identified Controller " + llDetectedName(0) + " on key touch");
                unresolvedMistressNames = llDeleteSubList(unresolvedMistressNames, index, index);
                lmInternalCommand("addMistress", (string)llDetectedKey(0) + "|" + llDetectedName(0), NULL_KEY);
            }
        }
        if (index != -1) {
            while((requestAddKey = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE, 
                "application/x-www-form-urlencoded" ], "name=" + llEscapeURL(llDetectedName(0)) + "&uuid=" + llEscapeURL((string)llDetectedKey(0))))) == NULL_KEY) {
                    llSleep(1.0);
            }
        }
    }
    
    http_response(key request, integer status, list meta, string body) {        
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
        else if (request == requestName) {
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
        else if (request == requestLoadDB) {
            string error = "HTTPdb - Database access ";
            
            if (status == 200) {
                lmSendConfig("databaseOnline", (string)(databaseOnline = 1));
                
                float HTTPdbProcessStart;
                string eventTime = formatFloat(((HTTPdbProcessStart = llGetTime()) - HTTPdbStart) * 1000, 2);
                
                integer lines;
                
                do {
                    integer nextNewLine = llSubStringIndex(body, "\n");
                    if (nextNewLine == -1) nextNewLine = llStringLength(body);
                    
                    string line = llGetSubString(body, 0, nextNewLine - 1);
                    body = llDeleteSubString(body, 0, nextNewLine);
                    
                    lines++;
                    
                    list split = llParseStringKeepNulls(line, [ "=" ], []);
                    string Key = llList2String(split, 0);
                    string Value = llList2String(split, 1);
                    
                    if (Value == "") Value = "";
                    
                    if (Key == "useHTTPS") useHTTPS = (integer)Value;
                    else if (Key == "HTTPinterval") HTTPinterval = (float)Value;
                    else if (Key == "HTTPthrottle") HTTPthrottle = (float)Value;
                    else if (Key == "updateCheck") updateCheck = (integer)Value;
                    else if (Key == "lastGetTimestamp") lastGetTimestamp = (integer)Value;
                    //else if (Key == "MistressListNew") handleAvList(Value, 1, 0);
                    //else if (Key == "MistressList") handleAvList(Value, 1, 1);
                    //else if (Key == "blacklistNew") handleAvList(Value, 2, 0);
                    //else if (Key == "blacklist") handleAvList(Value, 2, 1);
                    else if (Key == "MistressListNew") lmSendConfig("MistressList", Value);
                    else if (Key == "blacklistNew") lmSendConfig("blacklist", Value);
                    else if (Key == "windTimes") lmInternalCommand("setWindTimes", Value, NULL_KEY);
                    else lmSendConfig(Key, Value);
                    
                    if (useHTTPS) protocol = "https://";
                    else protocol = "http://";
                } while (llStringLength(body));
                
                debugSay(5, "DEBUG-SERVICES", "Service post interval setting " + formatFloat(HTTPinterval, 2) + "s throttle setting " + formatFloat(HTTPthrottle, 2) + "s");
                
                string msg = "HTTPdb - Processed " + (string)lines + " records ";
                if (lastPostTimestamp) msg += "with updates since our last post " + (string)((llGetUnixTime() - lastPostTimestamp) / 60) + " minutes ago ";
                msg += "event time " + eventTime + ", processing time " + formatFloat(((llGetTime() - HTTPdbProcessStart) * 1000), 2);
                msg += "ms, total time for DB transaction " + formatFloat((llGetTime() - HTTPdbStart) * 1000, 2) + "ms";
                debugSay(5, "DEBUG-SERVICES", msg);
                
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
            llMessageLinked(LINK_THIS, 102, llGetScriptName() + "|" + "HTTP" + (string)status, NULL_KEY);
            if (initState == 104) lmInitState(initState++);
        }
        else if (request == requestMistressKey || request == requestBlacklistKey) {
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
        else if (request == requestSendDB) {
            if (status == 200) {
                dbPostParams = [];
                list split = llParseStringKeepNulls(body, [ "|" ], []);
                lastPostTimestamp = llList2Integer(split, 1);
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
        else if (request == requestAddKey) {
            list split = llParseStringKeepNulls(body, [ "|" ], []);
            integer new = llList2Integer(split, 1);
            integer old = llList2Integer(split, 2);
            
            debugSay(5, "DEBUG-SERVICES", "Posted " + (string)(old + new) + " keys: " + (string)new + " new, " + (string)old + " old");
        }
        
        if (request != requestLoadDB) {
            integer debug;
            if (status == 200) debug = 7;
            else debug = 1;
            debugSay(debug, "DEBUG-SERVICES-RAW", "HTTP " + (string)status);
            
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
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        
        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;

            string time = (string)llGetUnixTime();
            HTTPdbStart = llGetTime();
            debugSay(6, "DEBUG-SERVICES", "Requesting data from HTTPdb");
            string hashStr = (string)llGetOwner() + time + SALT;
            string requestURI = "https://api.silkytech.com/httpdb/retrieve?q=" + llSHA1String(hashStr) + "&t=" + time + "&s=" + (string)lastGetTimestamp;
            if  (!offlineMode && (
                    (code == 104) || (
                        (code == 105) && 
                        ((llGetUnixTime() - 600) > lastGetTimestamp)
                    )
                )
            ) {
                while((requestLoadDB = llHTTPRequest(requestURI, HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                    llSleep(1.0);
                }
            }
            if ((code == 105) && (initState == 105)) lmInitState(initState++);
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
                    debugSay(6, "DEBUG-SERVICES", "Requesting data from HTTPdb");
                    string hashStr = (string)llGetOwner() + time + SALT;
                    string requestURI = "https://api.silkytech.com/httpdb/retrieve?q=" + llSHA1String(hashStr) + "&t=" + time + "&s=" + (string)lastGetTimestamp;
                    while((requestLoadDB = llHTTPRequest(requestURI, HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                        llSleep(1.0);
                    }
                }
                if (!gotURL && nextRetry < llGetUnixTime()) 
                while ((requestName = llHTTPRequest(protocol + "api.silkytech.com/objdns/lookup?q=" + llEscapeURL(llList2String(serverNames, requestIndex)), 
                        HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) llSleep(1.0);
                if (gotURL && (lastUpdateCheck < (llGetUnixTime() - updateCheck))) {
                    lastUpdateCheck = llGetUnixTime();
                    queForSave("lastUpdateCheck", (string)lastUpdateCheck);
                    while ((requestUpdate = llHTTPRequest(serverURL, HTTP_OPTIONS + [ "POST" ], "checkversion " + (string)PACKAGE_VERNUM)) == NULL_KEY) llSleep(1.0);
                }
                if ((keyHandler == NULL_KEY) || (keyHandlerTime < (llGetTime() - 60))) {
                    keyHandler = llGetKey();
                }
                if (keyHandler == llGetKey()) {
                    llRegionSay(broadcastOn, "keys claimed");
                    debugSay(5, "BROADCAST-DEBUG", "Broadcast Sent: keys claimed");
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
            
            else if (script == llGetScriptName()) return;
            
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
                debugSay(5, "DEBUG-SERVICES", "Looking up name " + name);
                unresolvedMistressNames += llToLower(name);
                while((requestMistressKey = llHTTPRequest("http://api.silkytech.com/name2key/lookup?q=" + llEscapeURL(name), HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
                    llSleep(1.0);
                }
            }
            else if (cmd == "getBlacklistKey") {
                string name = llList2String(split, 0);
                debugSay(5, "DEBUG-SERVICES", "Looking up name " + name);
                unresolvedBlacklistNames += llToLower(name);
                while((requestBlacklistKey = llHTTPRequest("http://api.silkytech.com/name2key/lookup?q=" + llEscapeURL(name), HTTP_OPTIONS + [ "GET" ], "")) == NULL_KEY) {
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
    }
    
    dataserver(key request, string data) {
        integer index = llListFindList(checkNames, [ request ]);
        if (index != -1) {
            string uuid = llList2Key(checkNames, index + 1);
            string name = data;
            
            checkNames = llDeleteSubList(checkNames, index, index + 1);
            index = llListFindList(unresolvedMistressNames, [ llToLower(data) ]);
            if (index != -1) {
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
            while ((requestAddKey = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE,
                "application/x-www-form-urlencoded" ], namepost))) == NULL_KEY) {
                    llSleep(1.0);
            }
        }
    }
    
    timer() {
        doHTTPpost();
        llSetTimerEvent(0.0);
    }
}