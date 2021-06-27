#ifndef COMMON_GLOBALS
#define COMMON_GLOBALS
#include "GlobalDefines.lsl"
float CommonGlobals_version=1.0;
//----------------------------
// COMMON GLOBALS
//----------------------------
key carrierID               = NULL_KEY;
key dollID                  = NULL_KEY;
key keyID                   = NULL_KEY;
key dresserID               = NULL_KEY;
key poseAnimationID         = NULL_KEY;
key poserID                 = NULL_KEY;

list blacklistList          = [];
//list BuiltinControllers     = BUILTIN_CONTROLLERS;
list controllerList         = [];
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
string poseAnimation;
string poserName;
string pronounHerDoll       = "her";
string pronounHersDoll      = "hers";
string pronounSheDoll       = "she";
string script;
string simRating;
string myName;

string rlvDefaultBaseCmd     = "";
string rlvDefaultCollapseCmd = "fly=n,sendchat=n,tplm=n,tplure=n,tploc=n,showinv=n,edit=n,sit=n,sittp=n,fartouch=n,showworldmap=n,showminimap=n,showloc=n,shownames=n,showhovertextall=n";
// Default PoseRLV does not include silence: that is optional
// Also allow touch - for Dolly to access Key
string rlvDefaultPoseCmd     = "fly=n,tplm=n,tplure=n,tploc=n,sittp=n,fartouch=n";

float baseWindRate          = RATE_STANDARD;
float dilationMedian        = 1.0;
float windRate              = RATE_STANDARD;
float visibility            = 1.0;

//integer afk;
integer allowCarry          = 1;
integer allowDress          = 1;
integer allowPose           = 1;
integer allowRepeatWind     = 1;
integer allowSelfWind       = 1;
integer allowTypes          = 1;
#ifdef ADULT_MODE
integer allowStrip          = 0;

integer hardcore;
#endif
integer isAFK               = 0; // current AFK state
integer busyIsAway;

integer canAFK              = 1;
integer canDressSelf        = 1;
integer canFly              = 1;
integer canSelfTP           = 1;
integer canRejectTP         = 1;
integer canTalkInPose       = 1;

integer chatChannel         = 75;
integer code;
integer collapsed;
integer posed;
integer collapseTime;
integer configured;
integer detachable          = 1;
integer doWarnings;
integer homingBeacon;
integer typeHovertext;
integer isTransformingKey   = 1;
integer keyLimit            = 10800;
integer safeMode;
integer offlineMode         = TRUE;
integer optHeader;
integer pleasureDoll;

integer remoteSeq;
integer rlvOk               = -1; // UNSET
integer rlvSupport          = -1; // UNSET
integer showPhrases;
integer takeoverAllowed;
integer timeLeftOnKey       = 1800;
integer timeReporting       = 1;
integer isVisible           = 1;

integer wearLockExpire;
integer typeLockExpire;
integer poseLockExpire;
integer outfitAvatar        = FALSE;

// Note that lowScriptExpire *IS NOT A LOCK*
integer lowScriptExpire;

// Note that carryExpire *IS NOT A LOCK*
integer carryExpire;

integer winderRechargeTime;
integer windMins            = 30;
integer windNormal          = 1800;
integer windEmergency       = 600;
integer windEmergencyActivated = FALSE;

// List of managed and stored restrictions

integer rlvAlwaysrun;
integer rlvEdit;
integer rlvFartouch;
integer rlvSendchat;
integer rlvShowhovertextall;
integer rlvShowinv;
integer rlvShowloc;
integer rlvShowminimap;
integer rlvShownames;
integer rlvShowworldmap;
integer rlvSit;
integer rlvSittp;
integer rlvTplm;
integer rlvTploc;
integer rlvTplure;

#ifdef DEVELOPER_MODE
integer debugLevel = 8;
#endif

integer dialogChannel;
integer dialogHandle;

#endif // COMMON_GLOBALS



