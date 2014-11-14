// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
#ifndef GLOBAL_DEFINES
#define GLOBAL_DEFINES

#include "config.h"

// Link message codes
// #define A 102
// #define B 104
// #define C 105
// #define D 110
#define MEM_REPORT 135
#define CONFIG 300
#define INTERNAL_CMD 305
#define RLV_CMD 315
// #define E 350
#define MENU_SELECTION 500

#define VSTR  + "\nScript Date: " + PACKAGE_VERSION
#define MAIN "~Main Menu~"
// Remove elements of Startup code
// #define NO_STARTUP 1
// Collapse animation - and documentation
#define ANIMATION_COLLAPSED "collapse"
// Carry distance for the new carry code
#define CARRY_RANGE 1.5
// llTakeControls() mask all available controls
#define CONTROL_ALL 0x5000033f
// llTakeControls() mask for the basic movement keys (4 arrow keys)
#define CONTROL_MOVE 0xf
// llTakeControls() mask for AFK mode slow movement
#define CONTROL_SLOW 0x3
// Dolls home landmark name
#define LANDMARK_HOME "Home"
// Name of the Community Dolls Room landmark
#define LANDMARK_CDROOM "Community Dolls at BDSM Pasha Desires"
// Name of the help notecard
#define NOTECARD_HELP "Community Dolls Key Help and Manual"
// Name of the preferences notecard
#define NOTECARD_PREFERENCES "Preferences"
// Name of the intro text notecard
#define NOTECARD_INTRO "IntroText"
// Wind down rate factor in AFK mode
#define RATE_AFK 0.5
// Wind down rate factor in standard mode
#define RATE_STANDARD 1.0
// Time dilation at which we go to reduced activity
#define DILATION_HIGH 0.95
// Time dilation at which we return to normal mode
#define DILATION_LOW 0.98
// LockMeister/FS AO channel
#define LOCKMEISTER_CHANNEL -8888
// Seconds per minute
#define SEC_TO_MIN 60.0
// Community dolls website
#define WEB_DOMAIN "http://communitydolls.com/"
// Maximum number of @getinvworn failures while dressing
#define MAX_DRESS_FAILURES 5
// This defines the config settings that we never expedite HTTP POST for
#define SKIP_EXPEDITE [ "poseExpire", "timeLeftOnKey", "timeToJamRepair", "wearLockExpire", "winderRechargeTime" ]
// Timeouts
#define WEAR_LOCK_TIME 600.0
#define DEMO_LIMIT 300.0
#define POSE_LIMIT 300.0
#define CARRY_TIMEOUT 300.0
#define JAM_DEFAULT_TIME 90.0

// Permissions scripts should request
//
//     * 0x0004 - PERMISSION_TAKE_CONTROLS
//     * 0x0010 - PERMISSION_TRIGGER_ANIMATION
//     * 0x0020 - PERMISSION_ATTACH
//     * 0x0400 - PERMISSION_TRACK_CAMERA
//     * 0x8000 - PERMISSION_OVERRIDE_ANIMATIONS
//
// Starred items are automatic on attach...
//
#define PERMISSION_MASK 0x8434

// Keys of important people in life of the Key:
#define AGENT_CHRISTINA_HALPIN        "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d"
#define AGENT_ANDROMEDA_LAMPLIGHT     "636bf2bd-45f5-46e0-ad9a-b00f54224e01"
#define AGENT_MAYSTONE_RESIDENT_RAW   c5e11d0a-694f-46cc-864b-e42340890934
#define AGENT_MAYSTONE_RESIDENT       "c5e11d0a-694f-46cc-864b-e42340890934"
#define AGENT_SILKY_MESMERISER_RAW    2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9
#define AGENT_SILKY_MESMERISER        "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9"

#define BUILTIN_CONTROLLERS [AGENT_SILKY_MESMERISER,AGENT_MAYSTONE_RESIDENT,AGENT_CHRISTINA_HALPIN,AGENT_ANDROMEDA_LAMPLIGHT]
list BuiltinControllers = BUILTIN_CONTROLLERS;
#define USER_CONTROLLERS controllers
#include "CommonGlobals.lsl"

// Once CommonGlobals is included redefine BUILTIN_CONTROLLERS to use the BuiltinControllers variable
// otherwise we end up with many copies of the actual list data itself using more memory.
#undef BUILTIN_CONTROLLERS
#define BUILTIN_CONTROLLERS BuiltinControllers
#define ALL_CONTROLLERS USER_CONTROLLERS + BUILTIN_CONTROLLERS

// Tests of id
#define cdIsDoll(id)                    (id == dollID)
#define cdIsCarrier(id)                 (id == carrierID)
#define cdIsBuiltinController(id)       (llListFindList(BUILTIN_CONTROLLERS, [ (string)id ]) != -1)
#define cdIsUserController(id)          (llListFindList(USER_CONTROLLERS, [ (string)id ]) != -1)
#define cdIsController(id)              cdGetControllerStatus(id)


// Used by this file below for OPTION_DATE
//#define PACKAGE_VERSION "26 February 2014"

// used by ServiceRequestor.lsl for updates
//#define PACKAGE_VERNUM "11.11"

// used by Start.lsl to set key name
//#define PACKAGE_STRING "Community Doll Key"

// The date of this code in this key, we should really look into a proper version numbering system sometime
#define OPTION_DATE PACKAGE_VERSION

#define STRING_END -1
#define NO_FILTER ""
#define YES 1
#define NO 0

// List definitions: makes things easier to comprehend

// Note: ....P in names is a LISP convention: acts like a question mark
#define cdListElement(a,b) llList2String(a, b)
#define cdListFloatElement(a,b) llList2Float(a, b)
#define cdListIntegerElement(a,b) llList2Integer(a, b)
#define cdListElementP(a,b) llListFindList(a, [ b ])
#define cdSplitArgs(a) llParseStringKeepNulls((a), [ "|" ], [])
#define cdSplitString(a) llParseString2List(a, [ "," ], [])
#define cdList2ListStrided(src,start,end,every) llList2ListStrided(llList2List(src, start, end), 0, -1, every)
#define cdGetFirstChar(a) llGetSubString(a, 0, 0)
#define cdButFirstChar(a) llGetSubString(a, 1, STRING_END)
#define cdChat(a) llSay(0, a)
#define cdStopTimer() llSetTimerEvent(0.0)
#define cdListenAll(a) llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
#define cdPause() llSleep(0.5)

#define CHECK "✔"
#define CROSS "✘"

#define CIRCLE_PLUS "⊕"
#define CIRCLE_MINUS "⊖"

// Dress module prefix test defines
#define isGroupItem(c)        (c == "#")
#define isHiddenItem(c)       (c == "~")
#define isPlusItem(c)         (c == "+")
#define isStandAloneItem(c)   (c == "=")
#define isTransformingItem(c) (c == "*")
#define isParentFolder(c)     (c == ">")
#define isChrootFolder(f)     (llGetSubString(f,0,1) == "!>")

#define CORE_SCRIPTS [ "Aux", "Avatar", "ChatHandler", "Dress", "Main", "MenuHandler", "ServiceRequester", "ServiceReceiver", "Start", "StatusRLV", "Transform" ]
#define COLOR_NAMES [ "Purple", "Pink", "Red", "Green", "Blue", "Cyan", "Yellow", "Orange", "White", "Black", "CUSTOM" ]
#define COLOR_VALUE [ <0.3, 0.1, 0.6>, <0.9, 0.1, 0.8>, <0.8, 0.1, 0.1>, <0.1, 0.8, 0.1>, <0.1, 0.1, 0.8>, <0.1, 0.8, 0.8>, <0.8, 0.8, 0.1>, <0.8, 0.4, 0.1>, <0.9, 0.9, 0.9>, <0.1, 0.1, 0.1>, <0,0,0> ]

// Max Controllers - Set a limit on the number of user defined controllers so the list
// cannot grow to arbitrary lengths and consume all memory.
#define MAX_ACCESS_ITEMS 11

#define cdControllerCount()		llFloor(llGetListLength(USER_CONTROLLERS) / 2)
#define cdAttached()			llGetAttached()
#define cdDollAway()			((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0)
#define cdCarried()			(carrierID != NULL_KEY)
#define cdCollapsedAnim()		(keyAnimation == ANIMATION_COLLAPSED)
#define cdNoAnim()			(keyAnimation == "")
#define cdPoseAnim()                    (!cdNoAnim() && !cdCollapsedAnim())
#define cdPosed()			(!collapsed && !cdNoAnim())
#define cdSelfPosed()			(poserID == dollID)
#define cdWindDown()			(!collapsed && cdAttached() && (dollType != "Builder") && (dollType != "Key"))
#define cdRunTimer()			(configured && cdAttached() && RLVchecked)
#define cdMyScriptName()		llGetScriptName()
#define cdMyScriptLine()		(string)__LINE__

#define ATTACH_BACK 9
#define ATTACH_HUD_CENTER_1 35
#define ATTACH_HUD_CENTER_2 31
#define DEBUG_CHANNEL 0x7FFFFFFF
#define FALSE 0
#define INVENTORY_SCRIPT 10
#define INVENTORY_ANIMATION 20
#define PUBLIC_CHANNEL 0
#define TRUE 1
#define TWO_PI 6.283185307179586476925286766559
#define NOT_FOUND -1

#define WIND_EMERGENCY -1
#define WIND_NORMAL 1

// Defines for various virtual functions to save typing and memory by inlining
#define isInteger(input) ((string)((integer)input) == input)
#define getLinkDesc(linknum) llList2String(llGetLinkPrimitiveParams(linknum, [ PRIM_DESC ]), 0)
#define getObjectScriptTime(id) (1000.0 * llList2Float(llGetObjectDetails(id, [ OBJECT_SCRIPT_TIME ]), 0))
#define getScriptTime() formatFloat(getObjectScriptTime(llGetKey()), 3) + "ms"
#define getWindRate() llList2Float(llGetPrimitiveParams([ PRIM_OMEGA ]), 1) / (TWO_PI / 15.0)
#define timerNextFrame() llSetTimerEvent(0.01 * mainTimerEnable)

#define uncarry() lmInternalCommand("uncarry", "", NULL_KEY)
#define uncollapse(old) lmInternalCommand("uncollapse", "0", NULL_KEY)

#define NORMAL_TIMER_RATE 0.5 * mainTimerEnable

#ifdef SIM_FRIENDLY
#define REDUCED_TIMER_RATE 5.0 * mainTimerEnable
#endif // SIM_FRIENDLY

#include "KeySharedFuncs.lsl"
#include "RestrainedLoveAPI.lsl"
#include "Utility.lsl"
#include "Config.lsl"
#include "LinkMessage.lsl"

integer cdGetControllerStatus(key id) {
    if (cdIsBuiltinController(id)) {
        return TRUE;
    }
    else {
        if (cdIsDoll(id)) return (!cdControllerCount());
        else return (cdIsUserController(id));
    }
    return FALSE;
}

// GLOBAL_DEFINES
#endif

