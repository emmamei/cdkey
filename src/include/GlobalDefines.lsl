// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
#ifndef GLOBAL_DEFINES
#define GLOBAL_DEFINES
float GlobalDefines_version=1.0;

#include "config.h"

// Set Firestorm options, just in case
#define USE_LAZY_LISTS
#define USE_SWITCHES

// Link message codes

// Init stages
//
// Stage 1: Preferences have now been read (if any)
#define INIT_STAGE1       101

// Stage 2: Runs after post-configuration, including wind time etc.
#define INIT_STAGE2       102

// Stage 3:
#define INIT_STAGE3       104

// Stage 4:
#define INIT_STAGE4       105

// Stage 5: All startup stages are complete: report and finish
#define INIT_STAGE5       110

// #define E 11
// #define F 12
// #define G 15
#define MEM_REPORT        135
#define MEM_REPLY         136
#define CONFIG_REPORT     142
#define SIM_RATING_CHG    150
#define SEND_CONFIG       300
#define SET_CONFIG        301
#define SANITY_CONFIG     301
#define INTERNAL_CMD      305
#define TIMING_CMD        310
#define RLV_CMD           315
#define RLV_RESET         350
#define MENU_SELECTION    500
#define POSE_SELECTION    502
#define TYPE_SELECTION    503

#define UNIQ 1245 // unique channel for updaters to communicate on

//#define cdSetHovertext(x,c) if(primText!=x)llSetText(x,c,1.0)
//#define RED    <1.0,0.0,0.0>
//#define YELLOW <1.0,1.0,0.0>
//#define WHITE  <1.0,1.0,1.0>
//
// llSetText wiki page suggests these values:
//
#define RED    <1.0, 0.255, 0.212>
#define YELLOW <1.0, 0.863, 0.0  >
#define WHITE  <1.0, 1.0  , 1.0  >

#define CRITICAL RED
#define WARN YELLOW
#define INFO WHITE

// Afk settings
#define NOT_AFK "0"
#define MENU_AFK "1"
#define AUTO_AFK "2"

#define VSTR  + "\nScript Date: " + PACKAGE_VERSION
#define MAIN "~Main Menu~"
#define UPMENU "~Up~"

// Special types are types that are present in the Dolly, no
// matter if there are any notecards OR directories present.
// A special type is permanently present.
//
//    - Regular: used for standard Dolls, including non-transformable
//    - Slut: can be stripped (like Pleasure Dolls)
//    - Display: poses dont time out
//    - Domme: messages shift focus slightly (treat like normal type)
//    - Builder: key slows drastically, etc: only for Developers
//
// Note that the Slut Doll type is only present for Adult Keys, and the
// Builder Doll type is only present for Developer Keys.
//
#ifdef ADULT_MODE

#ifdef DEVELOPER_MODE
#define SPECIAL_TYPES [ "Regular", "Slut", "Display", "Builder" ]
#else
#define SPECIAL_TYPES [ "Regular", "Slut", "Display" ]
#endif

#else

#ifdef DEVELOPER_MODE
#define SPECIAL_TYPES [ "Regular", "Display", "Builder" ]
#else
#define SPECIAL_TYPES [ "Regular", "Display" ]
#endif

#endif

// Collapse animation - and documentation
#define ANIMATION_COLLAPSED "collapse"

// No animation
#define ANIMATION_NONE ""

// Carry distance for the new carry code
#define CARRY_RANGE 2.5

// llTakeControls() mask all available controls
#define CONTROL_ALL 0x5000033f
// llTakeControls() mask for the basic movement keys (4 arrow keys)
#define CONTROL_MOVE 0xf
// llTakeControls() mask for AFK mode slow movement
#define CONTROL_SLOW 0x3

// Dolls home landmark name
#define LANDMARK_HOME "Home"

// Name of the Community Dolls Room landmark
#define LANDMARK_CDHOME "Community Dolls at BDSM Pasha Desires"

// Name of the help notecard
#define NOTECARD_HELP "Community Dolls Key Help and Manual"

// Name of the key object
#define OBJECT_KEY "Community Dolls Key"

// Name of the preferences notecard
#define NOTECARD_PREFERENCES "Preferences"

// Name of the intro text notecard
//#define NOTECARD_INTRO "IntroText"

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
#define SEC_TO_MIN 60
#define SECS_PER_MIN 60

// Community Dolls web URLs
#define WEB_DEV "https://github.com/emmamei/cdkey/tree/Development"
#define WEB_DOMAIN "http://communitydolls.com/"
#define WEB_BLOG "http://communitydolls.blogspot.com/"
#define WEB_GROUP "secondlife:///app/group/0f0c0dd5-a611-2529-d5c7-1284fb719003/about"

// Maximum number of @getinvworn failures while dressing
#define MAX_DRESS_FAILURES 5

// This defines the config settings that we never expedite HTTP POST for
#define SKIP_EXPEDITE [ "poseExpire", "timeLeftOnKey", "timeToJamRepair", "wearLockExpire", "winderRechargeTime" ]

// Timeouts
#define WEAR_LOCK_TIMEOUT 600
#define TYPE_LOCK_TIME 300

#define DEMO_LIMIT 300
#define POSE_TIMEOUT 300
#define CARRY_TIMEOUT 300
#define JAM_TIMEOUT ((integer)llFrand(180) + 120)
#define TIME_BEFORE_TP 900
#define TIME_BEFORE_EMGWIND 1800
#define EMERGENCY_LIMIT_TIME 43200 // 12 (RL) Hours = 43200 Seconds)

// Permissions scripts should request
//
//     * 0x0004 - PERMISSION_TAKE_CONTROLS
//     * 0x0010 - PERMISSION_TRIGGER_ANIMATION
//     X 0x0020 - PERMISSION_ATTACH
//     * 0x0400 - PERMISSION_TRACK_CAMERA
//     * 0x8000 - PERMISSION_OVERRIDE_ANIMATIONS
//
// Starred items are automatically given to attached objects on request
//
#define PERMISSION_MASK 0x8414

// Keys of important people in life of the Key:
#define AGENT_CHRISTINA_HALPIN        "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d"
#define AGENT_ANDROMEDA_LAMPLIGHT     "636bf2bd-45f5-46e0-ad9a-b00f54224e01"
#define AGENT_MAYSTONE_RESIDENT_RAW   c5e11d0a-694f-46cc-864b-e42340890934
#define AGENT_MAYSTONE_RESIDENT       "c5e11d0a-694f-46cc-864b-e42340890934"
#define AGENT_SILKY_MESMERISER_RAW    2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9
#define AGENT_SILKY_MESMERISER        "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9"

#define DOLLY_CONTROLLERS controllerList
#include "CommonGlobals.lsl"

#define RUNNING 1
#define NOT_RUNNING 0

#define LOW_FPS 30.0
#define LOW_DILATION 0.6
#define cdLowScriptTrigger   (llGetRegionFPS() < LOW_FPS || llGetRegionTimeDilation() < LOW_DILATION)

// Used by this file below for OPTION_DATE
//#define PACKAGE_VERSION "26 February 2014"

// Defines level of "ghostliness" visibiliity
#define GHOST_VISIBILITY 0.4

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

//========================================
// LIST MACROS
//
// These are designed to make things easier to read, easier to
// comprehened, and thus easier to maintain and understand

// From: http://wiki.secondlife.com/wiki/LlListFindList
#define cdFindInList(a,b) (~llListFindList(a, (list)(b)))
/*

if(~llListFindList(myList, (list)item))
{//it exists
    // This works because ~(-1) produces 0, but ~ of any other value produces non-zero and causes the 'if' to succeed
    // So any return value (including 0) that corresponds to a found item, will make the condition succeed
    // It saves bytecode and is faster then doing != -1
    // This is a bitwise NOT (~) not a negation (-)
}

*/

#define cdSplitArgs(a) llParseStringKeepNulls((a), [ "|" ], [])
#define cdSplitString(a) llParseString2List(a, [ "," ], [])
#define cdList2ListStrided(src,start,end,every) llList2ListStrided((list)src[start, end], 0, -1, every)
#define cdGetFirstChar(a) llGetSubString(a, 0, 0)
#define cdButFirstChar(a) llGetSubString(a, 1, STRING_END)
#define cdChat(a) llSay(0, a)
#define cdStopTimer() llSetTimerEvent(0.0)
#define cdPause() llSleep(0.5)
#define cdSayTo(m,i) llRegionSayTo(i, 0, m)
#define cdSay(a) llSay(PUBLIC_CHANNEL,(a))
#define cdDebugMsg(a) llSay(DEBUG_CHANNEL,(a))
#define cdSetKeyName(a) llSetObjectName(a)

// Can't define cdResetKey here because it is different in Start.lsl than it is in others
//#define cdResetKey() llResetOtherScript("Start")

#define generateRandomComChannel() ((((integer)("0x" + llGetSubString((string)owner, -8, -1)) & 0x3FFFFFFF) ^ 0xBFFFFFFF ) + UNIQ)
#define generateRandomPin() (llCeil(llFrand(123456) + 654321))

#define CHECK "✔"
#define CROSS "✘"

#define CIRCLE_PLUS "⊕"
#define CIRCLE_MINUS "⊖"

// Dress module prefix test defines
//
// Note that we can't use "=" because it will mess up the RLV
// commands when used, and this may be true for others like ":"
// and so forth.
//
#define isGroupFolder(c)        ((c) == "#")
#define isHiddenFolder(c)       ((c) == "~")
#define isPlusFolder(c)         ((c) == "+")
#define isAvatarFolder(c)       ((c) == "&")
#define isTypeFolder(c)         ((c) == "*")
#define isParentFolder(c)       ((c) == ">")
#define isRated(c)              ((c) == "{")
#define isChrootFolder(f)       (llGetSubString(f,0,1) == "!>")

// #define COLOR_NAMES [ "Purple", "Pink", "Red", "Green", "Blue", "Cyan", "Yellow", "Orange", "White", "Black", "CUSTOM" ]
// #define COLOR_VALUE [ <0.3, 0.1, 0.6>, <0.9, 0.1, 0.8>, <0.8, 0.1, 0.1>, <0.1, 0.8, 0.1>, <0.1, 0.1, 0.8>, <0.1, 0.8, 0.8>, <0.8, 0.8, 0.1>, <0.8, 0.4, 0.1>, <0.9, 0.9, 0.9>, <0.1, 0.1, 0.1>, <0,0,0> ]
#define COLOR_NAMES [ "Purple", "Pink", "Red", "Green", "Blue", "Cyan", "Yellow", "Orange", "White", "CUSTOM" ]
#define COLOR_VALUE [ <0.3, 0.1, 0.6>, <0.9, 0.1, 0.8>, <0.8, 0.1, 0.1>, <0.1, 0.8, 0.1>, <0.1, 0.1, 0.8>, <0.1, 0.8, 0.8>, <0.8, 0.8, 0.1>, <0.8, 0.4, 0.1>, <0.9, 0.9, 0.9>, <0,0,0> ]

// Max Controllers - Set a limit on the number of user defined controllers so the list
// cannot grow to arbitrary lengths and consume all memory.
#define MAX_ACCESS_ITEMS 11

#define NOT_COLLAPSED 0
#define NO_TIME 1
#define JAMMED 2

#define cdControllerCount()      llFloor(llGetListLength(controllerList) / 2)
#define cdHasControllers()       (llGetListLength(controllerList))
#define cdAttached()             llGetAttached()
#define cdDollAway()             ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0)
#define cdCarried()              (carrierID != NULL_KEY)
#define cdSelfPosed()            (poserID == dollID)
//#define cdRunTimer()           (configured && cdAttached() && RLVchecked)
//#define cdMyScriptName()         llGetScriptName()
#define cdMyScriptLine()         (string)__LINE__

#define FALSE 0
#define TRUE 1
#define UNSET -1

#define ATTACH_BACK 9
#define ATTACH_HUD_CENTER_1 35
#define ATTACH_HUD_CENTER_2 31
#define DEBUG_CHANNEL 0x7FFFFFFF
#define INVENTORY_SCRIPT 10
#define INVENTORY_ANIMATION 20
#define PUBLIC_CHANNEL 0
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
//#define cdWindDown() (!collapsed && isAttached)

#define uncarry() lmInternalCommand("uncarry", "", NULL_KEY)
//#define uncollapse(old) lmInternalCommand("uncollapse", "0", NULL_KEY)
#define dollyName() llGetDisplayName(dollID)

#define NORMAL_TIMER_RATE 0.5 * mainTimerEnable
#define REDUCED_TIMER_RATE 5.0 * mainTimerEnable

// Tests of id
#define cdIsDoll(id)                    (id == dollID)
#define cdIsCarrier(id)                 (id == carrierID)

// Here's the test: if we want Dolly included or not
#define cdIsExternalController(id)      (~llListFindList(controllerList, (list)((string)id)))
#define cdIsController(id)              cdGetControllerStatus(id)

#include "KeySharedFuncs.lsl"
#include "RestrainedLoveAPI.lsl"
#include "Utility.lsl"
#include "Config.lsl"
#include "LinkMessage.lsl"

integer cdGetControllerStatus(key id) {

    // Rules:
    //   Dolly is a Controller only if there aren't any User Controllers
    //   A User is a Controller if they are in the controller list
    //
    if (cdIsDoll(id))
        return (controllerList == []);
    else {
        return (cdFindInList(controllerList,((string)id)));
    }
}

// GLOBAL_DEFINES
#endif

