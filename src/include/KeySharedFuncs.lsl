#ifndef KEY_SHARED_FUNC_LSL
#define KEY_SHARED_FUNC_LSL
float KeySharedFuncs_version=1.0;

#include "GlobalDefines.lsl"
#include "LinkMessage.lsl"
#include "Utility.lsl"

//-----------------------------------
// Internal Shared Functions
//-----------------------------------
#define STD_RATE 30.0
#define LOW_RATE 60.0

#define cdWakeScript(a) llSetScriptState(a,1); lmInternalCommand("wakeScript", a, llGetKey())

#ifdef DEVELOPER_MODE
float lastTimerEvent;
float thisTimerEvent;
float timerInterval;
#endif
integer timerStarted;

#define CHECK "✔"
#define CROSS "✘"

// Folds a trailing space in
#define CHECKP "✔ "
#define CROSSP "✘ "

// Small function - but hopefully not too much a space hog
//integer cdSayToAgentPlusDoll(string msg, key id) {
//    llOwnerSay(msg);
//    if (cdIsDoll(id) && id != NULL_KEY) cdSayTo(msg,id);
//}
#define cdSayToAgentPlusDoll(msg,id)  llOwnerSay(msg); if (!cdIsDoll(id)) cdSayTo(msg,id);

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
