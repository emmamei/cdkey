#include "include/GlobalDefines.lsl"
#include "secret.lsl"

key RequestURL;
float delay = 10.0;
float nextRun;
string URL;

string domain = "cdkeyserver.secondlife.silkytech.com";
string keyName = "Community Doll Key";
string password = PASSWORD;
integer version = 1000000;

integer newSent;
integer updatesSent;
integer pingsRecieved;

doPost() {
    llHTTPRequest("https://api.silkytech.com/cdkey/service.php?action=urlupdate", 
        [
            HTTP_VERIFY_CERT, FALSE,
            HTTP_METHOD, "POST",
            HTTP_MIMETYPE, "application/x-www-form-urlencoded"
        ],
            "domain=" + llEscapeURL(domain) + "&" + 
            "password=" + llEscapeURL(password) + "&" +
            "url=" + llEscapeURL(URL)
    );
}

default
{
    state_entry() {
        llSetColor(<1.0, 0.0, 0.0>, ALL_SIDES);
        RequestURL = llRequestSecureURL();
        llSetTimerEvent(1.0);
    }
    
    on_rez(integer start) {
        llReleaseURL(URL);
        llResetScript();
    }
    
    changed(integer change) {
        if (change & (CHANGED_REGION | CHANGED_REGION_START)) {
            llReleaseURL(URL);
            llResetScript();
        }
    }
    
    http_request(key id, string method, string body) {
        if (method == URL_REQUEST_GRANTED) {
            URL = body;
            doPost();
        }
        else {
            list split = llParseString2List(body, [ " " ], []);
            string command = llList2String(split, 0);
            
            if (command == "sendkey") {
                key target = llList2Key(split, 1);
                llHTTPResponse(id, 200, "sendkey " + (string)target + " ok");
                newSent++;
                llGiveInventory(target, keyName);
            }
            else if (command == "checkversion") {
                integer clientVersion = llList2Integer(split, 1);
                
                pingsRecieved++;
                if (clientVersion < version) {
                    key target = llGetHTTPHeader(id, "x-secondlife-owner-key");
                    llOwnerSay("Sending update to secondlife:///app/agent/" + (string)target + "/about (" + (string)target + ")");
                    llHTTPResponse(id, 200, "checkversion updatesent");
                    updatesSent++;
                    llGiveInventory(target, keyName);
                }
                else {
                    llHTTPResponse(id, 200, "checkversion versionok");
                }
            }
            else {
                llHTTPResponse(id, 400, "bad request");
            }
        }
    }
    
    http_response(key id, integer status, list meta, string body) {
        if (body != "OK") {
            nextRun = llGetTime() + delay;
            llSetColor(<1,0,0>, ALL_SIDES);
        } else {
            nextRun = 0.0;
            delay = 10.0;
            llSetColor(<0,1,0>, ALL_SIDES);
        }
    }
    
    timer() {
        if (nextRun != 0.0 && nextRun < llGetTime()) {
            delay += delay;
            if (delay > 600.0) delay = 600.0;
            doPost();
        }
        
        float hours = llGetTime() / 3600.0;
        string msg = "Server: " + domain + "\n";
        msg += "New Keys Sent:\t" + (string)newSent + " (" + formatFloat((float)newSent / hours, 2) + "/hr)\n";
        msg += "Version Pings:\t" + (string)pingsRecieved + " (" + formatFloat((float)pingsRecieved / hours, 2) + "/hr)\n";
        msg += "Updates Sent:\t" + (string)updatesSent + " (" + formatFloat((float)updatesSent / hours, 2) + "/hr)\n";
        if (llGetColor(0) == <0.0, 1.0, 0.0>) msg += "Uptime:";
        else msg += "Downtime:";
        msg += "\t" + formatFloat(hours, 2) + " hours";
        llSetText(msg, llGetColor(0), llGetAlpha(0));
    }
}
