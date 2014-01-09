#ifndef COMMON_GLOBALS
#define COMMON_GLOBALS
//----------------------------
// COMMON GLOBALS
//----------------------------
key carrierID               = NULL_KEY;
key dresserID               = NULL_KEY;
key dollID                  = NULL_KEY;
key poserID                 = NULL_KEY;
key scriptkey               = NULL_KEY;

list MistressList           = [];

string carrierName;
string dresserName;
string poserName;
string dollName;
string dollType             = "Regular";
string keyAnimation;
//string mistressName         = "";
#ifdef ADULT_MODE  
string simRating;
#endif

float dilationMedian        = 1.0;
float keyLimit              = 10800.0;
float timeLeftOnKey         = 1800.0;
float windamount            = 1800.0;
float windRate              = RATE_STANDARD;

integer afk;
integer autoTP;
integer canAFK              = 1;
integer canCarry            = 1;
integer canDress            = 1;
integer canFly              = 1;
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
integer pleasureDoll;
integer quiet;
integer RLVok;
integer signOn;
integer takeoverAllowed;
integer timeReporting       = 2;
integer visible             = 1;

integer dialogChannel;
integer dialogHandle;

string dollShortName;
string keyDefaultName;
string keyOwnerSayName;
string keyShortName;

#endif // COMMON_GLOBALS



