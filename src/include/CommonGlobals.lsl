#ifndef COMMON_GLOBALS
#define COMMON_GLOBALS
#include "GlobalDefines.lsl"
//----------------------------
// COMMON GLOBALS
//----------------------------
key carrierID               = NULL_KEY;
key dollID                  = NULL_KEY;
key dresserID               = NULL_KEY;
key keyAnimationID          = NULL_KEY;
key poserID                 = NULL_KEY;
key uniqueID                = NULL_KEY;

list blacklist              = [];
list BuiltinControllers     = BUILTIN_CONTROLLERS;
list controllers            = [];
list split                  = [];

string backMenu             = MAIN;
string carrierName;
string chatPrefix;
string dollGender           = "Female";
string dollName;
string dollDisplayName;
// dollType has a default, but don't set it here'
string dollType;
string dresserName;
string keyAnimation;
string poserName;
string pronounHerDoll       = "Her";
string pronounSheDoll       = "She";
string script;
string simRating;

float baseWindRate          = RATE_STANDARD;
float collapseTime;
float dilationMedian        = 1.0;
float displayWindRate	    = RATE_STANDARD;
float keyLimit              = 10800.0;
float timeLeftOnKey         = 1800.0;
float windAmount            = 1800.0;
float windRate              = RATE_STANDARD;

integer afk;
integer allowCarry          = 1;
integer allowDress          = 1;
integer allowPose           = 1;
integer allowRepeatWind     = 1;
#ifdef ADULT_MODE
integer allowStrip          = 1;
#endif
integer autoAFK             = 1;
integer autoTP;
integer busyIsAway;
integer canAFK              = 1;
integer canDressSelf        = 1;
integer canFly              = 1;
integer canSelfTP           = 1;
integer canSit              = 1;
integer canStand            = 1;
integer code;
integer collapsed;
integer configured;
integer demoMode;
integer detachable          = 1;
integer doWarnings;
integer hardcore;
integer homingBeacon;
integer hovertextOn;
integer isTransformingKey   = 1;
integer lowScriptMode;
integer offlineMode         = TRUE;
integer optHeader;
integer pleasureDoll;
integer poseSilence         = 1;
integer quiet               = 1;
integer remoteSeq;
integer RLVok               = -1;
integer showPhrases;
integer takeoverAllowed;
integer timeReporting       = 1;
integer visible             = 1;
integer wearLock;
integer winderRechargeTime;
integer windingDown         = 1;

#ifdef DEVELOPER_MODE
integer debugLevel          = DEBUG_LEVEL;
#endif

integer dialogChannel;
integer dialogHandle;

vector gemColour;
#endif // COMMON_GLOBALS



