//-----------------------------------
// Internal Shared Functions
//-----------------------------------

float lastTimerEvent;

float setWindRate() {
    float newWindRate;
    vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    integer agentInfo = llGetAgentInfo(dollID);
    integer windDown = isAttached && !collapsed && dollType != "Builder" && dollType != "Key";
    
    newWindRate = 1.0;
    if (afk) newWindRate *= 0.5;
    
    if (windRate != newWindRate * windDown) {
        windRate = newWindRate * windDown;
        
        lmSendConfig("windRate", (string)windRate, NULL_KEY);
    }
    
    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 15.0), 1);
    
    return newWindRate;
}

integer setFlags(integer clear, integer set) {
    integer oldFlags = globalFlags;
    globalFlags = (globalFlags & ~clear) | set;
    if (globalFlags != oldFlags) {
        lmSendConfig("globalFlags", "0x" + bits2nybbles(globalFlags), NULL_KEY);
        return 1;
    }
    else return 0;
}


