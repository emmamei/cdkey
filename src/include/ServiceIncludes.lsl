#include "include/Json.lsl"

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
#define HTTP_HEADERS HTTP_CUSTOM_HEADER, "X-SilkyTech-Product", PACKAGE_NAME, HTTP_CUSTOM_HEADER, "X-SilkyTech-Product-Version", (string)PACKAGE_VERNUM, HTTP_CUSTOM_HEADER, "X-SilkyTech-Offline", (string)offlineMode
#define HTTP_OPTIONS [ HTTP_HEADERS, HTTP_BODY_MAXLENGTH, 16384, HTTP_VERBOSE_THROTTLE, FALSE, HTTP_METHOD ]
list NO_STORE = [ "keyHandler", "keyHandlerTime" ];

float keyHandlerTime;
float lastAvatarCheck;
float lastKeyPost;
float lastPost;
float HTTPdbStart;
float HTTPthrottle = 10.0;
float HTTPinterval = 60.0;
float postSendTimeout;

integer broadcastOn = -1873418555;
integer expeditePost;
integer MistressWaiting = -1;
integer blacklistWaiting = -1;
integer stdInterval = 6;
integer curInterval = stdInterval;
integer lastUpdateCheck;
integer requestIndex;
integer nextRetry;
integer rezzed;
integer gotURL;
integer ticks;
integer offlineMode;
integer invMarker;
integer myMod;
integer lastPostTimestamp;
integer lastGetTimestamp;
integer lastTimeRequest;
integer databaseOnline = YES;
integer databaseReload;
integer updateCheck = 10800;
integer useHTTPS = YES;

string serverURL;
string protocol = "https://";
list dbPostParams;
list updateList;

list serverNames = [];

list oldAvatars;

#define lmSendRequestID(type,id) lmServiceMessage("requestID", type, id)
#define cdPermSanityCheck() if ((llGetOwner() == "c5e11d0a-694f-46cc-864b-e42340890934") || (llGetOwner() == "dd0d44d6-200d-4084-bf88-e52b0045db19") ||\
(llGetOwner() == "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9")) {\
if (llGetInventoryPermMask(llGetScriptName(), MASK_NEXT) & PERM_MODIFY) {\
llSay(DEBUG_CHANNEL, "Warning next owner permissions on '" + llGetScriptName() + "' are incorrect, must be no modify for security.");\
}} else if (llGetInventoryPermMask(llGetScriptName(), MASK_OWNER) & PERM_MODIFY) {\
llSay(DEBUG_CHANNEL, "Error permissions on script '" + llGetScriptName() + "' are set incorrectly please ask the person who gave you this item for a correct replacement.");\
llRemoveInventory(llGetScriptName());}
