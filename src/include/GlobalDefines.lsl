// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
#ifndef GLOBAL_DEFINES
#define GLOBAL_DEFINES

// The date of this code in this key, we should really look into a proper version numbering system sometime
#define OPTION_DATE "23/Dec/13"

// Enables optional sim friendly mode support
#define LOW_SCRIPT_MODE
// Enables various developer specific features of the key
#define DEVELOPER_MODE
#define TESTER_MODE
// Selects between llSay on DEBUG_CHANNEL and OwnerSay for delivering debugSay messages these options
// are mutually exclusive define either or none to disable but not both.
#define DEBUG_TO_OWNER
//#define DEBUG_TO_DEBUG
// Enables code related to adult features this way we can disable this to remove all such code entirely
#define ADULT_MODE
// Enables link message debugging code now in Main.lsl - Note this is kinda spammy only if needed
//#define LINK_DEBUG
// Enables intro messages during initial startup
#define INTRO_ENABLED

#define hasCarrier (carrierID != NULL_KEY)    
#define hasController (MistressID != NULL_KEY)
#define isAttached (llGetAttached() == ATTACH_BACK)
#define isCarrier ((id == carrierID) && !isDoll)
#define isDoll (id == dollID)
#define isDollAway ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0)
#define isController (isMistress(id) && !isDoll)
#define isWindingDown (!collapsed && isAttached && dollType != "Builder" && dollType != "Key")
#define mainTimerEnable (configured && isAttached && RLVchecked)

// Collapse animation - and documentation
#define ANIMATION_COLLAPSED "collapse"
// Carry distance for the new carry code
#define CARRY_RANGE 1.5
// llTakeControls() mask all available controls
#define CONTROL_ALL 0x5000033f
// llTakeControls() mask for the basic movement keys (4 arrow keys)
#define CONTROL_MOVE 0x15
// Dolls home landmark name
#define LANDMARK_HOME "Home"
// Name of the Community Dolls Room landmark
#define LANDMARK_CDROOM "Community Dolls Room"
// Name of the help notecard
#define NOTECARD_HELP "Community Dolls Key Help and Manual"
// Name of the preferences notecard
#define NOTECARD_PREFERENCES "Preferences"
// Name of the intro text notecard
#define NOTECARD_INTRO "IntroText"
// Permissions scripts should request
#define PERMISSION_MASK 0x8034
// Wind down rate factor in AFK mode
#define RATE_AFK 0.5
// Wind down rate factor in standard mode
#define RATE_STANDARD 1.0
// Time dilation at which we go to reduced activity
#define DILATION_HIGH 0.950
// Time dilation at which we return to normal mode
#define DILATION_LOW 0.975
// LockMeister/FS AO channel
#define LOCKMEISTER_CHANNEL -8888
// Seconds per minute
#define SEC_TO_MIN 60.0
// Community dolls website
#define WEB_DOMAIN "http://communitydolls.com/"

#define SCRIPT_NAME llGetScriptName()

// debugSay
#ifdef DEBUG_TO_OWNER
#define debugSay(msg) llOwnerSay(msg)
#else
#ifdef DEBUG_TO_DEBUG
#define debugSay(msg) llSay(DEBUG_CHANNEL, msg)
#else
#define debugSay(dummy)
#endif // DEBUG_TO_DEBUG
#endif // DEBUG_TO_OWNER

// Define some functions like debugSay() etc as dummy when not
// in developer mode
#ifndef DEVELOPER_MODE
#define debugSay(dummy)
#endif

#define DEBUG_CHANNEL 0x7FFFFFFF
#define FALSE 0
#define INVENTORY_SCRIPT 10
#define INVENTORY_ANIMATION 20
#define PUBLIC_CHANNEL 1
#define TRUE 1
#define TWO_PI 6.283185307179586476925286766559

// Link messages
#define lmSendToAgent(msg, id) llMessageLinked(LINK_THIS, 11, msg, id)
#define lmPrefsComplete(count) llMessageLinked(LINK_THIS, 102, SCRIPT_NAME + "|" + (string)(count), scriptkey)
#define lmMemReport() llMessageLinked(LINK_THIS, 135, SCRIPT_NAME, scriptkey)
#define lmSendConfig(name, value) llMessageLinked(LINK_THIS, 300, SCRIPT_NAME + "|" + name + "|" + value, scriptkey)
#define lmInternalCommand(command, parameter, id) llMessageLinked(LINK_THIS, 305, SCRIPT_NAME + "|" + command + "|" + parameter, id)
#define lmRLVreport(active, apistring, apiversion) llMessageLinked(LINK_THIS, 350, SCRIPT_NAME + "|" + (string)active + "|" + apistring + "|" + (string)apiversion, scriptkey)
#define lmRunRLV(command) llMessageLinked(LINK_THIS, 315, SCRIPT_NAME + "|" + command, scriptkey)
#define lmConfirmRLV(forscript, command) llMessageLinked(LINK_THIS, 320, SCRIPT_NAME + "|" + forscript + "|" + command, scriptkey)
#define lmScriptReset() llMessageLinked(LINK_THIS, 999, SCRIPT_NAME, scriptkey)
#define lmOwnerCheckFail() llMessageLinked(LINK_THIS, 999, SCRIPT_NAME + "|" + (string)CHANGED_OWNER, scriptkey)
#define lmSendConfig(name, value) llMessageLinked(LINK_THIS, 300, SCRIPT_NAME + "|" + name + "|" + value, scriptkey)
#define lmInitState(code) llMessageLinked(LINK_THIS, code, SCRIPT_NAME, scriptkey)

// Defines for various virtual functions to save typing and memory by inlining
#define isMistress(id) (llListFindList(ALL_CONTROLLERS, [ id ]) != -1)
#define getLinkDesc(linknum) (string)llGetLinkPrimitiveParams(linknum, [ PRIM_DESC ])
#define getObjectScriptTime(id) (1000.0 * llList2Float(llGetObjectDetails(id, [ OBJECT_SCRIPT_TIME ]), 0))
#define getScriptTime() formatFloat(getObjectScriptTime(llGetKey()), 3) + "ms"
#define getWindRate() llList2Float(llGetPrimitiveParams([ PRIM_OMEGA ]), 1) / (TWO_PI / 15.0)
#define timerNextFrame() llSetTimerEvent(0.01 * mainTimerEnable)

// Short internal command functions
#define uncarry() lmInternalCommand("uncarry", carrierName + "|" + (string)carrierID, scriptkey)
#define carry(name, id) lmInternalCommand("carry", name + "|" + (string)id, scriptkey)
#define collapse() lmInternalCommand("collapse", "", scriptkey)
#define uncollapse() lmInternalCommand("uncollapse", "", scriptkey)
#define afk(afk, auto, rate, time) lmInternalCommand("setAFK", (string)afk + "|" + (string)auto + "|" + (string)rate + "|" + (string)time, scriptkey)
#define pose(posename, name, id) lmInternalCommand("setPose", posename + "|" + name + "|" + (string)id, scriptkey)
#define unpose() lmInternalCommand("unpose", poserName + "|" + (string)poserID, scriptkey)

// Keys of important people in life of the Key:
#define AGENT_CHRISTINA_HALPIN "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d"
#define AGENT_GREIGHIGHLAND_RESIDENT "64d26535-f390-4dc4-a371-a712b946daf8"
#define AGENT_MAYSTONE_RESIDENT "c5e11d0a-694f-46cc-864b-e42340890934"
#define AGENT_SILKY_MESMERISER "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9"

#define BUILTIN_CONTROLLERS [ AGENT_SILKY_MESMERISER, AGENT_MAYSTONE_RESIDENT, AGENT_CHRISTINA_HALPIN, AGENT_GREIGHIGHLAND_RESIDENT ]
#define USER_CONTROLLERS MistressList + [ MistressID ]
#define ALL_CONTROLLERS USER_CONTROLLERS + BUILTIN_CONTROLLERS

#define NORMAL_TIMER_RATE 0.5 * mainTimerEnable
#ifdef LOW_SCRIPT_MODE
#define REDUCED_TIMER_RATE 5.0 * mainTimerEnable
#endif

#include "Utility.lsl"
#include "KeySharedFuncs.lsl"
#include "CommonGlobals.lsl"

#endif // GLOBAL_DEFINES

