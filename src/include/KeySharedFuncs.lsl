#ifndef KEY_SHARED_FUNC_LSL
#define KEY_SHARED_FUNC_LSL

//-----------------------------------
// Internal Shared Functions
//-----------------------------------

float lastTimerEvent;

float setWindRate() {
    float newWindRate;
    vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    integer agentInfo = llGetAgentInfo(dollID);
    integer windDown = isAttached && !collapsed && dollType != "Builder" && dollType != "Key";
    
    newWindRate = baseWindRate;
    if (afk) newWindRate *= 0.5;
    
    if (windRate != newWindRate * windDown) {
        windRate = newWindRate * windDown;
        
        lmSendConfig("baseWindRate", (string)baseWindRate);
        lmSendConfig("windRate", (string)windRate);
    }
    
    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 10.0), 1);

    return newWindRate;
}

#define CHECK "✔"
#define CROSS "✘"

list getButton(string text, key id, integer enabled, integer oneWay) {
   if (enabled) return [CHECK + " " + text];
   else if (!oneWay || getControllerStatus(id)) return [CROSS + " " + text];
   return [];
}

integer rating2Integer(string simRating) {
         if (simRating == "ADULT")      return 3;
    else if (simRating == "MATURE")     return 2;
    else if (simRating == "GENERAL")    return 1;
    else                                return 0;
}

integer outfitRating(string outfit) {
    string rating = llGetSubString(outfit, 0, 2);
         if (rating == "{A}")     return 3;
    else if (rating == "{M}")     return 2;
    else if (rating == "{G}")     return 1;
    else                          return 0;
}

#endif // KEY_SHARED_FUNC_LSL
