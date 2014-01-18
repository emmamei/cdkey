#include "include/GlobalDefines.lsl"
#include "include/Secure.lsl"

key requestName;
key requestUpdate;
key requestKey;
key requestSendDB;
key requestLoadDB;
list unresolvedNames;
float lastPost;
float HTTPdbStart;
float HTTPthrottle = 20.0;
float HTTPinterval = 60.0;
integer stdInterval = 6;
integer curInterval = stdInterval;
integer lastUpdateCheck;
integer requestIndex;
integer myVersion = 140102;
integer nextRetry;
integer gotURL;
integer firstRun = 1;
integer initState;
integer ticks;
integer offlineMode;
integer invMarker;
integer myMod;
integer lastPostTimestamp;
integer databaseOnline;
integer updateCheck = 10800;
integer useHTTPS = 1;

string serverURL;
string protocol = "https://";
list dbPostParams;
list updateList;

list serverNames = [
    "cdkeyserver.secondlife.silkytech.com",
    "cdkeyserver2.secondlife.silkytech.com"
];

list oldAvatars;

queForSave(string name, string value) {
    integer index = llListFindList(dbPostParams, [ name ]);
    if (index != -1 && index % 2 == 0) 
        dbPostParams = llListReplaceList(dbPostParams, [ name, llEscapeURL(value) ], index, index + 1);
    else dbPostParams += [ name, llEscapeURL(value) ];
    llSetTimerEvent(1.0);
}

doHTTPpost() {
    if (lastPost == 0.0 || llGetTime() - lastPost > HTTPthrottle) {
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
        //llOwnerSay(llUnescapeURL(dbPostBody));
        requestSendDB = llHTTPRequest(protocol + "api.silkytech.com/httpdb/store?q=" + llSHA1String(dbPostBody + (string)llGetOwner() + time + SALT) +
            "&t=" + time, [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded" ], dbPostBody);  
            
        llSetTimerEvent(HTTPinterval);
    }
    else {
        float ThrottleTime = lastPost - llGetTime() + HTTPthrottle;
        debugSay(3, "Throttling HTTP requests for " + formatFloat(ThrottleTime, 2) + "s to comply with service specified throttle " + formatFloat(HTTPthrottle, 2) + "s");
        llSetTimerEvent(ThrottleTime);
    }
}

default
{
    state_entry() {
        lmScriptReset();
        llSetTimerEvent(60.0);
        myMod = llFloor(llFrand(5.999999));
        serverNames = llListRandomize(serverNames, 1);
    }
    
    on_rez(integer start) {
        serverNames = llListRandomize(serverNames, 1);
        myMod = llFloor(llFrand(5.999999));
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
    }
    
    touch_start(integer num) {
        integer index = llListFindList(unresolvedNames, [ llDetectedName(0) ]);
        if (index != -1) {
            llOwnerSay("Identified Mistress " + llDetectedName(0) + " on key touch");
            unresolvedNames = llDeleteSubList(unresolvedNames, index, index);
            lmSendConfig("MistressID", (string)llDetectedKey(0));
            llHTTPRequest(protocol + "api.silkytech.com/name2key/add", [ HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded" ],
                "name=" + llEscapeURL(llDetectedName(0)) + "&uuid=" + llEscapeURL(llDetectedKey(0)));
        }
    }
    
    http_response(key request, integer status, list meta, string body) {
        debugSay(9, "HTTP " + (string)status + ": " + body);
        
        if (request == requestUpdate) {
            if (llGetSubString(body, 0, 21) == "checkversion versionok") {
                if (llStringLength(body) > 22) updateCheck = (integer)llGetSubString(body, 23, -1);
                lastUpdateCheck = llGetUnixTime();
                debugSay(5, "Next check in " + (string)updateCheck + " seconds");
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
            llSleep(0.1);
            if (status == 200) {
                lmSendConfig("databaseOnline", (string)(databaseOnline = 1));
                
                float HTTPdbProcessStart;
                string eventTime = formatFloat(((HTTPdbProcessStart = llGetTime()) - HTTPdbStart) * 1000, 2);
                
                list lines = llParseString2List(body, [ "\n" ], []);
                integer i;
                
                for (i = 0; i < llGetListLength(lines); i++) {
                    scaleMem();
                    
                    string line = llList2String(lines, i);
                    list split = llParseStringKeepNulls(line, [ "=" ], []);
                    string Key = llList2String(split, 0);
                    string Value = llList2String(split, 1);
                    
                    if (Value == line) Value = "";
                    if (Key != "useHTTPS" && Key != "HTTPinterval" && Key != "HTTPthrottle") lmSendConfig(Key, Value);
                    else {
                        if (Key == "useHTTPS") useHTTPS = (integer)Value;
                        if (Key == "HTTPinterval") HTTPinterval = (float)Value;
                        if (Key == "HTTPthrottle") HTTPthrottle = (float)Value;
                        if (Key == "updateCheck") updateCheck = (integer)Value;
                    }
                    if (useHTTPS) protocol = "https://";
                    else protocol = "http://";
                }
                
                debugSay(5, "Service post interval setting " + formatFloat(HTTPinterval, 2) + "s throttle setting " + formatFloat(HTTPthrottle, 2) + "s");
                
                string msg = "HTTPdb - Processed " + (string)llGetListLength(lines) + " records ";
                if (lastPostTimestamp) msg += "with updates since our last post " + (string)((llGetUnixTime() - lastPostTimestamp) / 60) + " minutes ago ";
                msg += "event time " + eventTime + ", processing time " + formatFloat(((llGetTime() - HTTPdbProcessStart) * 1000), 2);
                msg += "ms, total time for DB transaction " + formatFloat((llGetTime() - HTTPdbStart) * 1000, 2) + "ms";
                debugSay(5, msg);
                lmInitState(initState);
            }
            else {
                error += "failed: Continuing in offline mode.";
                offlineMode = 1;
                databaseOnline = 0;
                llOwnerSay(error);
            }
            llMessageLinked(LINK_THIS, 102, llGetScriptName(), NULL_KEY);
        }
        else if (request == requestKey) {
            integer index = llSubStringIndex(body, "=");
            string name = llGetSubString(body, 0, index - 1);
            string uuid = llGetSubString(body, index + 1, -1);
            if (uuid == "NOT FOUND") {
                llOwnerSay("Failed to find " + name + " in the name2key database, please check the name is correct and in legacy name format.  If the name is correct it is probably safe to ignore this message and the database will be updated when " + name + " touches your key next.");
            }
            else {
                index = llListFindList(unresolvedNames, [ name ]);
                unresolvedNames = llDeleteSubList(unresolvedNames, index, index);
                lmSendConfig("MistressID", uuid);
            }
        }
        else if (request == requestSendDB) {
            if (status == 200) {
                dbPostParams = [];
                list split = llParseStringKeepNulls(body, [ "|" ], []);
                lastPostTimestamp = llList2Integer(split, 1);
                debugSay(5, "HTTPdb update success " + llList2String(split, 2) + " updated records: " + llList2CSV(updateList));
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
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        
        scaleMem();
        
        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            initState = code;
            if (!offlineMode && (code == 104 || (code == 105 && !firstRun))) {
                string time = (string)llGetUnixTime();
                if (code == 104) firstRun = 1;
                HTTPdbStart = llGetTime();
                debugSay(5, "Requesting data from HTTPdb");
                string hashStr = (string)llGetOwner() + time + SALT;
                string requestURI = "https://api.silkytech.com/httpdb/retrieve?q=" + llSHA1String(hashStr) + "&t=" + time;
                if (lastPostTimestamp != 0) requestURI += "&s=" + (string)lastPostTimestamp;
                requestLoadDB = llHTTPRequest(requestURI, [ HTTP_METHOD, "GET" ], "");
            }
            else {
                lmInitState(code);
                firstRun = 0;
            }
        }
        if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
            if (name == "lastUpdateCheck") lastUpdateCheck = (integer)value;
            if (name == "nextRetry") nextRetry = (integer)value;
            
            if (script == llGetScriptName()) return;
            
            if (name == "MistressByName") {
                debugSay(5, "Looking up name " + value);
                requestKey = llHTTPRequest(protocol + "api.silkytech.com/name2key/lookup?q=" + llEscapeURL(value), [ HTTP_METHOD, "GET" ], "");
            }
            else if (name == "offlineMode") {
                offlineMode = (integer)value;
                dbPostParams = [];
            }
            else if (!offlineMode) {
                value = llDumpList2String(llList2List(split, 2, -1), "|");
                queForSave(name, value);
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
    
    timer() {
        if (!gotURL && nextRetry < llGetUnixTime()) 
            requestName = llHTTPRequest(protocol + "api.silkytech.com/objdns/lookup?q=" + llEscapeURL(llList2String(serverNames, requestIndex)), 
                          [ HTTP_METHOD, "GET" ], "");
        if (gotURL && (lastUpdateCheck < (llGetUnixTime() - updateCheck))) {
            lastUpdateCheck = llGetUnixTime();
            queForSave("lastUpdateCheck", (string)lastUpdateCheck);
            requestUpdate = llHTTPRequest(serverURL, [ HTTP_METHOD, "POST" ], "checkversion " + (string)myVersion);
        }
        
        doHTTPpost();
    }
}