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
        
        lmSendConfig("windRate", (string)windRate);
    }
    
    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 10.0), 1);

    //debugSay(9, "Vector: " + (string)(llVecNorm(<0.0, 0.0, 1.0>)) + "\nRate: " + formatFloat(windRate * (TWO_PI / 10.0), 2));

    return newWindRate;
}

#endif // KEY_SHARED_FUNC_LSL
