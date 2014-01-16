// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
#ifndef GLOBAL_DEFINES
#define GLOBAL_DEFINES

// The date of this code in this key, we should really look into a proper version numbering system sometime
#define OPTION_DATE PACKAGE_VERSION

#include "config.h"

#define hasCarrier (carrierID != NULL_KEY)    
#define numControllers llGetListLength(USER_CONTROLLERS)
#ifndef DEVELOPER_MODE
#define isAttached (llGetAttached() == ATTACH_BACK)
#define isAllowedRLV (llGetAttached() == ATTACH_BACK)
#else
#define isAttached ((llGetAttached() == ATTACH_BACK) || (llGetAttached() == ATTACH_HUD_CENTER_1) || (llGetAttached() == ATTACH_HUD_CENTER_2))
#define isAllowedRLV ((llGetAttached() == ATTACH_BACK) || (llGetAttached() == ATTACH_HUD_CENTER_2))
#endif
#define isDollAway ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0)
#define isWindingDown (!collapsed && isAttached && dollType != "Builder" && dollType != "Key")
#define mainTimerEnable (configured && isAttached && RLVchecked)
#define MistressNameList "secondlife:///app/agent/" + llDumpList2String(MistressList, "/displayname, secondlife:///app/agent/") + "/displayname"

#define isDoll (id == dollID)
#define isCarrier (id == carrierID) && !isDoll
#define isBuiltin (llListFindList(BUILTIN_CONTROLLERS, [ (string)id ]) != -1)
#define isMistress (llListFindList(USER_CONTROLLERS, [ (string)id ]) != -1)
#define isController (llListFindList(BUILTIN_CONTROLLERS + MistressList, [ (string)id ]) != -1) && !isDoll

// Dress module prefix test defines
#define isGroupItem(f) (llGetSubString(f,0,0) == "#")
#define isHiddenItem(f) (llGetSubString(f,0,0) == "~")
#define isPlusItem(f) (llGetSubString(f,0,0) == "+")
#define isStandAloneItem(f) (llGetSubString(f,0,0) == "=")
#define isTransformingItem(f) (llGetSubString(f,0,0) == "*")
#define isParentFolder(f) (llGetSubString(f,0,0) == ">")
#define isChrootFolder(f) (llGetSubString(f,0,1) == "!>")

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
#define NOTECARD_PREFERENCES "Preferences" //Test
// Name of the intro text notecard
#define NOTECARD_INTRO "IntroText"
// Permissions scripts should request
#define PERMISSION_MASK 0x8434
// Wind down rate factor in AFK mode
#define RATE_AFK 0.5
// Wind down rate factor in standard mode
#define RATE_STANDARD 1.0
// Time dilation at which we go to reduced activity
#define DILATION_HIGH 0.90
// Time dilation at which we return to normal mode
#define DILATION_LOW 0.95
// LockMeister/FS AO channel
#define LOCKMEISTER_CHANNEL -8888
// Seconds per minute
#define SEC_TO_MIN 60
// Community dolls website
#define WEB_DOMAIN "http://communitydolls.com/"
// Maximum number of @getinvworn failures while dressing
#define MAX_DRESS_FAILURES 5
// Timeouts
#define WEAR_LOCK_TIME 600.0
#define DEMO_LIMIT 300.0
#define POSE_LIMIT 300.0
#define CARRY_TIMEOUT 60.0
#define JAM_DEFAULT_TIME 90.0

// Max Controllers - Set a limit on the number of user defined controllers so the list
// cannot grow to arbitrary lengths and consume all memory.
#define MAX_USER_CONTROLLERS 12

#define SCRIPT_NAME llGetScriptName()

#define ATTACH_BACK 9
#define ATTACH_HUD_CENTER_1 35
#define ATTACH_HUD_CENTER_2 31
#define DEBUG_CHANNEL 0x7FFFFFFF
#define FALSE 0
#define INVENTORY_SCRIPT 10
#define INVENTORY_ANIMATION 20
#define PUBLIC_CHANNEL 1
#define TRUE 1
#define TWO_PI 6.283185307179586476925286766559

#define WIND_EMERGENCY -1
#define WIND_NORMAL 1

// Link messages
#define lmSendToAgent(msg, id) llMessageLinked(LINK_THIS, 11, msg, id)
#define lmPrefsComplete(count) llMessageLinked(LINK_THIS, 102, SCRIPT_NAME + "|" + (string)(count), scriptkey)
#define lmMemReport(delay) llMessageLinked(LINK_THIS, 135, SCRIPT_NAME + "|" + (string)delay, scriptkey)
#define lmInternalCommand(command, parameter, id) llMessageLinked(LINK_THIS, 305, SCRIPT_NAME + "|" + command + "|" + parameter, id)
#define lmRLVreport(active, apistring, apiversion) llMessageLinked(LINK_THIS, 350, SCRIPT_NAME + "|" + (string)active + "|" + apistring + "|" + (string)apiversion, scriptkey)
#define lmRunRLV(command) llMessageLinked(LINK_THIS, 315, SCRIPT_NAME + "|" + command, scriptkey)
#define lmConfirmRLV(forscript, command) llMessageLinked(LINK_THIS, 320, SCRIPT_NAME + "|" + forscript + "|" + command, scriptkey)
#define lmScriptReset() llMessageLinked(LINK_THIS, 999, SCRIPT_NAME, scriptkey)
#define lmOwnerCheckFail() llMessageLinked(LINK_THIS, 999, SCRIPT_NAME + "|" + (string)CHANGED_OWNER, scriptkey)
#define lmSendConfig(name, value) llMessageLinked(LINK_THIS, 300, SCRIPT_NAME + "|" + name + "|" + value, scriptkey)
#define lmInitState(code) llMessageLinked(LINK_THIS, code, SCRIPT_NAME, scriptkey)
#define lmMenuReply(choice, name, id) llMessageLinked(LINK_THIS, 500, choice + "|" + name, id)

// Defines for various virtual functions to save typing and memory by inlining
#define isInteger(input) ((string)((integer)input) == input)
#define getLinkDesc(linknum) llList2String(llGetLinkPrimitiveParams(linknum, [ PRIM_DESC ]), 0)
#define getObjectScriptTime(id) (1000.0 * llList2Float(llGetObjectDetails(id, [ OBJECT_SCRIPT_TIME ]), 0))
#define getScriptTime() formatFloat(getObjectScriptTime(llGetKey()), 3) + "ms"
#define getWindRate() llList2Float(llGetPrimitiveParams([ PRIM_OMEGA ]), 1) / (TWO_PI / 15.0)
#define timerNextFrame() llSetTimerEvent(0.01 * mainTimerEnable)

#define uncarry() lmInternalCommand("uncarry", "", scriptkey)
#define uncollapse() lmInternalCommand("uncollapse", "", scriptkey)

// Keys of important people in life of the Key:
#define AGENT_CHRISTINA_HALPIN "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d"
#define AGENT_GREIGHIGHLAND_RESIDENT "64d26535-f390-4dc4-a371-a712b946daf8"
#define AGENT_MAYSTONE_RESIDENT "c5e11d0a-694f-46cc-864b-e42340890934"
#define AGENT_SILKY_MESMERISER "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9"

#define BUILTIN_CONTROLLERS [ AGENT_SILKY_MESMERISER, AGENT_MAYSTONE_RESIDENT, AGENT_CHRISTINA_HALPIN, AGENT_GREIGHIGHLAND_RESIDENT ]
#define USER_CONTROLLERS MistressList
#define ALL_CONTROLLERS USER_CONTROLLERS + BUILTIN_CONTROLLERS

#define NORMAL_TIMER_RATE 0.5 * mainTimerEnable
#ifdef LOW_SCRIPT_MODE
#define REDUCED_TIMER_RATE 5.0 * mainTimerEnable
#endif

#include "CommonGlobals.lsl"
#include "KeySharedFuncs.lsl"
#include "RestrainedLoveAPI.lsl"
#include "Utility.lsl"

#endif // GLOBAL_DEFINES


