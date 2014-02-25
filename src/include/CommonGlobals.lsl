#ifndef COMMON_GLOBALS
#define COMMON_GLOBALS
//----------------------------
// COMMON GLOBALS
//----------------------------
key carrierID               = NULL_KEY;
key dresserID               = NULL_KEY;
key dollID                  = NULL_KEY;
key poserID                 = NULL_KEY;
key uniqueID		    = NULL_KEY;

list MistressList           = [];
list blacklist;

string carrierName;
string dresserName;
string poserName;
string dollName;
string dollType             = "Regular";
string keyAnimation;
string simRating;

float dilationMedian        = 1.0;
float keyLimit              = 10800.0;
float timeLeftOnKey         = 1800.0;
float windamount            = 1800.0;
float baseWindRate          = RATE_STANDARD;

integer afk;
integer autoTP;
integer canAFK              = 1;
integer canCarry            = 1;
integer canDress            = 1;
integer canFly              = 1;
integer canPose             = 1;
integer canRepeat           = 1;
integer canSit              = 1;
integer canStand            = 1;
integer canWear             = 1;
integer canUnwear           = 1;
integer collapsed;
integer configured;
integer demoMode;
integer detachable          = 1;
integer doWarnings;
integer helpless;
integer isTransformingKey   = 1;
integer lowScriptMode;
integer offlineMode;
integer pleasureDoll;
integer poseSilence;
integer quiet;
integer RLVok;
integer signOn;
integer takeoverAllowed;
integer visible             = 1;

integer initState	    = 104;
integer initCode;
#ifdef DEVELOPER_MODE
integer debugLevel          = DEBUG_LEVEL;
#else
#ifdef TESTER_MODE
integer debugLevel          = DEBUG_LEVEL;
#endif //TESTER_MODE
#endif //DEVELOPER_MODE

integer dialogChannel;
integer dialogHandle;
#endif // COMMON_GLOBALS



