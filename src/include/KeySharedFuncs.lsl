#ifndef KEY_SHARED_FUNC_LSL
#define KEY_SHARED_FUNC_LSL

#include "GlobalDefines.lsl"
#include "LinkMessage.lsl"

//-----------------------------------
// Internal Shared Functions
//-----------------------------------
#define STD_RATE 2.0
#define LOW_RATE 8.0

#define cdWakeScript(a) llSetScriptState(a,1); lmInternalCommand("wakeScript", a, llGetKey())

float lastTimerEvent;
integer timerStarted;

float setWindRate() {
    //float newWindRate;
    //vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    //integer agentInfo = llGetAgentInfo(dollID);

    //newWindRate = baseWindRate;
    //if (afk) newWindRate *= 0.5;

    displayWindRate = baseWindRate;
    if (afk) displayWindRate *= 0.5;

    if (cdWindDown()) windRate = displayWindRate;
    else windRate = 0.0;

    // There are three winding rates:
    //
    // baseWindRate is the basic rate when the Key is full-on and without
    //     restrictions or adjustments
    //
    // displayWindRate appears to be the rate the Key would be going at
    //     if it was operating.
    //
    // windRate is the actual discernable Key winding rate. THIS is the
    //     amount of most importance, and the one that accounts for
    //     the Key's actual winding down - the others are "storage" to
    //     preserve other rates.
    //
    lmSendConfig("baseWindRate", (string)baseWindRate);
    lmSendConfig("displayWindRate", (string)displayWindRate);
    lmSendConfig("windRate", (string)windRate);

    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(<0.0, 0.0, 1.0>, windRate * TWO_PI / 8.0, 1);

    return displayWindRate;
}

#define CHECK "✔"
#define CROSS "✘"

list cdGetButton(string text, key id, integer enabled, integer oneWay) {
   if (enabled) return [CHECK + " " + text];
   else if (!oneWay || cdIsController(id)) return [CROSS + " " + text];
   return [];
}

integer cdRating2Integer(string simRating) {
         if (simRating == "ADULT")      return 3;
    else if (simRating == "MATURE")     return 2;
    else if (simRating == "GENERAL")    return 1;
    else if (simRating == "PG")         return 1;
    else                                return 0;
}

integer cdOutfitRating(string outfit) {
    string rating = llGetSubString(outfit, 0, 2);
         if (rating == "{A}")     return 3;
    else if (rating == "{M}")     return 2;
    else if (rating == "{G}")     return 1;
    else                          return 0;
}

// Gracefully degrades to legacy name without "Resident" if llGetDisplayName is giving a false return
#define cdGetDisplayName(id) cdGracefulDisplayName(id)

string cdGracefulDisplayName(key id) {
   string displayName;
   if (id == dollID) {
      displayName = dollName;
      if (displayName == "") displayName = (dollName = llGetDisplayName(dollID));
      else if (llSubStringIndex(displayName, "???") != -1) displayName = (dollName = llKey2Name(dollID));
      return displayName;
   }
   else {
      displayName = llGetDisplayName(id);
      if (llSubStringIndex(displayName, "???") != -1) displayName = llKey2Name(id);
      return displayName;
   }
}
#endif // KEY_SHARED_FUNC_LSL
