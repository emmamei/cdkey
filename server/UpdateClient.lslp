#include "include/GlobalDefines.lsl"

key requestName;
key requestUpdate;
integer lastUpdateCheck;
integer requestIndex = -1;
integer myVersion = 1000000;

string serviceURL = "https://api.silkytech.com/cdkey/service.php?action=";
string serverURL;

list serverNames = [
    "cdkeyserver.secondlife.silkytech.com"
];

default
{
    state_entry() {
        debugSay(5, "state reset to default");
        // Randomize the timers for retries etc, this way if a group hits
        // the server at once especially the in world server with it's limited
        // single threaded event que size we reduce the chance of just repeating
        // the cycle next check.
        if (++requestIndex < llGetListLength(serverNames)) {
            llSetTimerEvent(30.0 + llFrand(30.0));
        } else {
            requestIndex = 0;
            llSetTimerEvent(900.0 + llFrand(900.0));
        }
    }
    
    on_rez(integer start) {
        llResetScript();
    }
    
    http_response(key request, integer status, list meta, string body) {
        if (request == requestName) {
            if (status == 200) {
                serverURL = body;
                state goturl;
            }
        }
        if (status == 403) {
            llOwnerSay("FORBIDDEN: Devices owned by your avatar are currently blocked from this service.  " +
                       "This may be due to a bug or other unforceen issue causing your objects to access the service " +
                       "too fast.  Please contact secondlife:///app/agent/2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9/about " +
                       "to find out what went wrong and discuss restoring access.");
            llSetScriptState(llGetScriptName(), 0);
        }
        if (++requestIndex < llGetListLength(serverNames)) {
            llSetTimerEvent(30.0 + llFrand(30.0));
        } else {
            requestIndex = 0;
            llSetTimerEvent(900.0 + llFrand(900.0));
        }
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            lmInitState(code);
        }
        else if (code == 135) {
            memReport();
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
        requestName = llHTTPRequest(serviceURL + "geturl&domain=" + llEscapeURL(llList2String(serverNames, requestIndex)), [ HTTP_METHOD, "GET", HTTP_VERIFY_CERT, FALSE ], "");
    }
}

state goturl {
    state_entry() {
        debugSay(5, "state gotURL " + serverURL);
        if (lastUpdateCheck <= (llGetUnixTime() - 43200)) {
            requestUpdate = llHTTPRequest(serverURL, [ HTTP_METHOD, "POST" ], "checkversion " + (string)myVersion);
        }
    }
    
    on_rez(integer start) {
        requestUpdate = llHTTPRequest(serverURL, [ HTTP_METHOD, "POST" ], "checkversion " + (string)myVersion);
    }
    
    http_response(key request, integer status, list meta, string body) {
        if (request == requestUpdate) {
            if (body == "checkversion versionok") {
                lastUpdateCheck = llGetUnixTime();
                llOwnerSay("Version check completed you have the latest version.");
                llSetTimerEvent(900.0 + llFrand(900.0));
            }
            else if (body == "checkversion updatesent") {
                lastUpdateCheck = llGetUnixTime();
                llOwnerSay("Version check completed your updated key is on it's way to you now.");
                llSetTimerEvent(900.0 + llFrand(900.0));
            }
            else if (status != 200) {
                llOwnerSay("Error, failure to contact the update server you key will continue to try or see the help notecard.  " +
                           "For alternative update options.");
                state default;
            }
        }
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            lmInitState(code);
        }
        else if (code == 135) {
            memReport();
        }
        else if (code == 500) {
            string selection = llList2String(split, 0);
            
            if (selection == "Check Update") {
                lastUpdateCheck = 0;
                requestUpdate = llHTTPRequest(serverURL, [ HTTP_METHOD, "POST" ], "checkversion " + (string)myVersion);
            }
        }
    }
    
    timer() {
        if (lastUpdateCheck <= (llGetUnixTime() - 43200)) {
            requestUpdate = llHTTPRequest(serverURL, [ HTTP_METHOD, "POST" ], "checkversion " + (string)myVersion);
        }
    }
}
