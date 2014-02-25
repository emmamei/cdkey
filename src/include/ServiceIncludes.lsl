#include "include/Secure.lsl"

#define YES 1
#define NO 0
#define NOT_FOUND -1

key keyHandler = NULL_KEY;
key requestID;
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
integer ticks;
integer offlineMode;
integer invMarker;
integer myMod;
integer lastPostTimestamp;
integer lastGetTimestamp;
integer databaseOnline = YES;
integer databaseReload;
integer updateCheck = 10800;

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

#define lmServiceMessage(type,data,id) llMessageLinked(LINK_THIS, 850, SCRIPT_NAME + "|" + type + "|" + data, id)
#define lmSendRequestID(type,id) lmServiceMessage("requestID", type, id)

queForSave(string name, string value) {

    if (llListFindList(NO_STORE, [ name ]) != NOT_FOUND) return;

    if (name == "MistressList") name = "MistressListNew";
    if (name == "blacklist") name = "blacklistNew";

    integer index = llListFindList(dbPostParams, [ name ]);

    if (index != NOT_FOUND && index % 2 == 0)
        dbPostParams = llListReplaceList(dbPostParams, [ name, llEscapeURL(value) ], index, index + 1);
    else dbPostParams += [ name, llEscapeURL(value) ];

    debugSay(5, "DEBUG-SERVICES", "Queued for save: " + name + "=" + value);

    //if (llListFindList(SKIP_EXPEDITE, [ name ]) == NOT_FOUND) expeditePost = 1;
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

        if (llListFindList(oldAvatars, [ (uuid = llList2Key(newAvatars, i)) ]) == NOT_FOUND) {
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
                } else {
                    debugSay(5, "DEBUG-SERVICES", "name2key: posting " + (string)namepostcount + " keys (" + (string)llStringLength(namepost) + " bytes) interval: " +
                                formatDuration(llGetTime() - lastKeyPost, 0) + " mins");

                    while ((requestAddKey = (llHTTPRequest("http://api.silkytech.com/name2key/add", HTTP_OPTIONS + [ "POST", HTTP_MIMETYPE,
                        "application/x-www-form-urlencoded" ], namepost))) == NULL_KEY) {
                            llSleep(1.0);
                    }

                    lastKeyPost = llGetTime();
                    lastPost = lastKeyPost;
                    postAge = llGetTime() - lastKeyPost;
                    namepost = "names[0]=" + name +
                               "&uuids[0]=" + llEscapeURL(uuid);
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
#if DEVELOPER_MODE
    if (namepost != "" && n != 0)
        debugSay(5, "DEBUG-SERVICES", "Queued post " + (string)namepostcount +
            " keys (" + (string)llStringLength(namepost) + " bytes) oldest: " +
            formatDuration(llGetTime() - lastKeyPost, 0) + " mins");
#endif
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
    } else {
        float ThrottleTime = lastPost - llGetTime() + HTTPthrottle;

        if (!expeditePost) ThrottleTime += HTTPinterval - HTTPthrottle;

        llSetTimerEvent(ThrottleTime);
        expeditePost = 0;
    }
}