key RequestURL;
float delay = 10.0;
string URL;

string domain = "cdkeyserver.secondlife.silkytech.com";
string keyName = "Community Doll Key";
string password = "<DOMAIN PASSWORD>";
integer version = 1000000;

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
        RequestURL = llRequestSecureURL();
    }
    
    on_rez(integer start) {
        llReleaseURL(URL);
        RequestURL = llRequestSecureURL();
    }
    
    changed(integer change) {
        if (change & (CHANGED_REGION | CHANGED_REGION_START)) {
            llReleaseURL(URL);
            RequestURL = llRequestSecureURL();
        }
    }
    
    http_request(key id, string method, string body) {
        if (method = URL_REQUEST_GRANTED) {
            URL = body;
            doPost();
        }
        else {
            list split = llParseString2List(body, [ "|" ], []);
            string command = llList2String(split, 0);
            
            if (command = "sendkey") {
                key target = llList2Key(split, 1);
                llHTTPResponse(id, 200, "sendkey " + (string)target + " ok");
                llGiveInventory(target, keyName);
            }
            else if (command = "checkversion") {
                integer clientVersion = llList2Integer(split, 1);
                
                if (clientVersion < version) {
                    key target = llGetHTTPHeader(id, "X-Secondlife-Owner-Key");
                    llHTTPResponse(id, 200, "checkversion updatesent");
                    llGiveInventory(target, keyName);
                }
                else {
                    llHTTPResponse(id, 200, "checkversion versionok");
                }
            }
        }
    }
    
    http_response(key id, integer status, list meta, string body) {
        if (body != "OK") {
            llSetTimerEvent(delay);
            llSetColor(<1,0,0>, ALL_SIDES);
        } else {
            llSetColor(<0,1,0>, ALL_SIDES);
        }
    }
    
    timer() {
        delay += delay;
        doPost();
    }
}
