// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//

<<<<<<< HEAD:src/include/GlobalDefines.lsl
// The date of this code in this key, we should really look into a proper version numbering system sometime
#define OPTION_DATE "18/Dec/13"

// Enables various developer specific features of the key
#define DEVELOPER_MODE
#define TESTER_MODE
// Enables code related to adult features this way we can disable this to remove all such code entirely
#define ADULT_MODE
// Enables link message debugging code now in Main.lsl - Note this is kinda spammy only if needed
#define LINK_DEBUG
=======
#define OPTION_DATE "19/Dec/13"   // The date of this code in this key, we should really look into a proper version numbering system sometime

#define LOW_SCRIPT_MODE           // Enables the low script mode code
#define DEVELOPER_MODE            // Enables various developer specific features of the key
#define TESTER_MODE               // Enables tester mode allowing access to some features the doll would not normally have for testing
#define ADULT_MODE                // Enables code related to adult features this way we can disable this to remove all such code entirely
#define LINK_DEBUG                // Enables link message debugging code now in Main.lsl - Note this is kinda spammy only if needed
>>>>>>> 2dd32d98973fb71a4b61191399bc328d3b28581b:lsl/preprocessor/include/GlobalDefines.lsl

#define isAttached (llGetAttached() == ATTACH_BACK)
#define isCarried (carrierID != NULL_KEY)
#define hasController (MistressID != NULL_KEY)

<<<<<<< HEAD:src/include/GlobalDefines.lsl
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
// Permissions scripts should request
#define PERMISSION_MASK 0x8034
// Wind down rate factor in AFK mode
#define RATE_AFK 0.5
// Wind down rate factor in standard mode
#define RATE_STANDARD 1.0

// Seconds per minute
#define SEC_TO_MIN 60.0
// Community dolls website
#define WEB_DOMAIN "http://communitydolls.com/"
=======
#define ANIMATION_COLLAPSED "collapse"                          // Collapse animation - and documentation
#define CARRY_RANGE 1.5                                         // Carry distance for the new carry code
#define CONTROL_ALL 0x5000033f                                  // llTakeControls() mask all available controls
#define CONTROL_MOVE 0x15                                       // llTakeControls() mask for the basic movement keys (4 arrow keys)
#define LANDMARK_HOME "Home"                                    // Dolls home landmark name
#define LANDMARK_CDROOM "Community Dolls Room"                  // Name of the Community Dolls Room landmark
#define NOTECARD_HELP "Community Dolls Key Help and Manual"	// Name of the help notecard
#define PERMISSION_MASK 0x8034                                  // Permissions scripts should request
#define RATE_AFK 0.5                                            // Wind down rate factor in AFK mode
#define RATE_STANDARD 1.0                                       // Wind down rate factor in standard mode
#define LAG_HIGH_THRESHOLD 0.92					// If region time dilation is worse than this go to sim friendly mode
#define LAG_LOW_THRESHOLD 0.97					// If region time dilation is better than this we will return to normal
#define SEC_TO_MIN 60.0                                         // Seconds per minute
#define WEB_DOMAIN "http://communitydolls.com/"			// Community dolls website
>>>>>>> 2dd32d98973fb71a4b61191399bc328d3b28581b:lsl/preprocessor/include/GlobalDefines.lsl

#define SCRIPT_NAME llGetScriptName()

// Link messages
#define lmMemReport() llMessageLinked(LINK_THIS, 135, SCRIPT_NAME, NULL_KEY)
#define lmInternalCommand(command, parameter, id) llMessageLinked(LINK_THIS, 305, SCRIPT_NAME + "|" + command + "|" +parameter, id)
#define lmRunRLV(command) llMessageLinked(LINK_THIS, 315, SCRIPT_NAME + "|" + command, NULL_KEY)
#define lmSendConfig(name, value, id) llMessageLinked(LINK_THIS, 300, SCRIPT_NAME + "|" + name + "|" + value,id)
#define lmSendToAgent(msg, id) llMessageLinked(LINK_THIS, 11,msg,id)
#define lmScriptReset() llMessageLinked(LINK_THIS, 999, SCRIPT_NAME, NULL_KEY)
#define lmInitializationCompleted(code) llMessageLinked(LINK_THIS, code, SCRIPT_NAME, NULL_KEY)

// Keys of important people in life of the Key:
#define AGENT_CHRISTINA_HALPIN "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d"
#define AGENT_GREIGHIGHLAND_RESIDENT "64d26535-f390-4dc4-a371-a712b946daf8"
#define AGENT_MAYSTONE_RESIDENT "c5e11d0a-694f-46cc-864b-e42340890934"
#define AGENT_SILKY_MESMERISER "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9"

#include "Utility.lsl"
#include "KeySharedFuncs.lsl"

