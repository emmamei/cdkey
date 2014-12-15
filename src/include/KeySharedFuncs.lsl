#ifndef KEY_SHARED_FUNC_LSL
#define KEY_SHARED_FUNC_LSL

#include "GlobalDefines.lsl"
#include "LinkMessage.lsl"
#include "Utility.lsl"

//-----------------------------------
// Internal Shared Functions
//-----------------------------------
#define STD_RATE 30.0
#define LOW_RATE 60.0

#define cdWakeScript(a) llSetScriptState(a,1); lmInternalCommand("wakeScript", a, llGetKey())

float lastTimerEvent;
integer timerStarted;

float setWindRate() {
    //float newWindRate;
    //vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    //integer agentInfo = llGetAgentInfo(dollID);

    //newWindRate = baseWindRate;
    //if (afk) newWindRate *= 0.5;

    windingDown = cdWindDown();
    windRate = baseWindRate;

    if (afk) windRate *= 0.5 * baseWindRate;

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
    // The difference between windRate and displayWindRate is that windRate
    // can have a flag value of zero. The windRate value could be folded
    // into the displayWindRate value and a flag of "windingDown" could be
    // used instead - for clarity and simplicity and separation of meanings.

    // This routine is not only setting the Wind Rate - but refreshing
    // winding rate values on the wire - EVERY time. This needs to be
    // segregated out into a different area as it is unrelated to this
    // function.
    //
    // Note too that baseWindRate never changes in this function at all.
    //
    broadcastWindRate();

    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    if (windingDown) llTargetOmega(<0.0, 0.0, 1.0>, windRate * TWO_PI / 8.0, 1);
    else             llTargetOmega(<0.0, 0.0, 1.0>,                     0.0, 1);

    // Note that this is mostly irrelevant: this function is used to set
    // the displayWindRate as a side effect anyway - so the return is useless,
    // and setting the displayWindRate to the value returned is also useless.
    //
    return windRate;
}

broadcastWindRate() {
    lmSendConfig("baseWindRate", (string)baseWindRate);
    //lmSendConfig("displayWindRate", (string)displayWindRate);
    lmSendConfig("windRate", (string)windRate);
    lmSendConfig("windingDown", (string)windingDown);
}

#define CHECK "✔"
#define CROSS "✘"

// Folds a trailing space in
#define CHECKP "✔ "
#define CROSSP "✘ "

list cdGetButton(string text, key id, integer enabled, integer oneWay) {

   //debugSay(5,"LIB-MENU","cdGetButton: text = \"" + text + "\"; enabled = " + (string)enabled + "; oneWay = " + (string)oneWay);
   //debugSay(5,"LIB-MENU","Controller status = " + (string)(cdIsController(id)));
   if (enabled) return [CHECKP + text];

   // Trying to diwable - only a Controller can clear it
   if (!oneWay || cdIsController(id)) return [CROSSP + text];
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
