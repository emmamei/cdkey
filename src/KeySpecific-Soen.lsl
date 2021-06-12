//========================================
// KeySpecific.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define RUNNING 1
#define NOT_RUNNING 0
#define UNSET -1
#define USER_NAME_QUERY_TIMEOUT 15
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdResetKey() llResetOtherScript("Start")

#define cdCapability(c,p,u) { s += p; if (!(c)) { s += " not"; }; s += " " + u + ".\n"; }
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"
#define cdList2String(a) llDumpList2String(a,"|")

#define KEY_SPECIFIC_PRODUCT "Soen's Basic Key"

//=======================================
// VARIABLES
//=======================================

//=======================================
// FUNCTIONS
//=======================================

keyParticlesStart(float rate) {

    list coreParameters = [

        // Texture Parameters:
        PSYS_SRC_TEXTURE, llGetInventoryName(INVENTORY_TEXTURE, 0),
        PSYS_PART_START_SCALE, <0.1, 0.1, 0.0>,  PSYS_PART_END_SCALE, <0.0, 0.0, 0>, 
        PSYS_PART_START_COLOR, <1.0, 1.0, 1.0>,  PSYS_PART_END_COLOR, <1.0,1.0,1.0>, 
        PSYS_PART_START_ALPHA, 0.5,              PSYS_PART_END_ALPHA, 1.0,     

        // Production Parameters:
        PSYS_SRC_BURST_PART_COUNT, 1, 
        PSYS_SRC_BURST_RATE,       rate / 10,
        PSYS_PART_MAX_AGE,         2.0, 
        PSYS_SRC_MAX_AGE,          0.0, 

        // Placement Parameters:
        PSYS_SRC_PATTERN, 8, // 1=DROP, 2=EXPLODE, 4=ANGLE, 8=CONE,

        // Placement Parameters (for any non-DROP pattern):
        PSYS_SRC_BURST_SPEED_MIN, 0.01,
        PSYS_SRC_BURST_SPEED_MAX, 0.01, 
        PSYS_SRC_BURST_RADIUS, 0.02,

        // Placement Parameters (only for ANGLE & CONE patterns):
        PSYS_SRC_ANGLE_BEGIN, 0.25 * PI,
        PSYS_SRC_ANGLE_END,   0.75 * PI,  
        PSYS_SRC_OMEGA, <0.0, 0.0, 0.0>, 

        // After-Effect & Influence Parameters:
        PSYS_SRC_ACCEL, <0.0, 0.0, 0.0>,
        PSYS_PART_FLAGS, (integer) ( 
          0
          | PSYS_PART_INTERP_COLOR_MASK   
          | PSYS_PART_INTERP_SCALE_MASK   
          | PSYS_PART_EMISSIVE_MASK   
       )
    ];

    llParticleSystem(coreParameters);
}

keyParticlesToggle(integer turnOnParticles) {

    if (turnOnParticles == TRUE) {
        debugSay(4,"DEBUG-SOEN","Particles turned on.");
        keyParticlesStart(1.0);
    }
    else {
        debugSay(4,"DEBUG-SOEN","Particles turned off.");
        llParticleSystem([]);
    }
}

//========================================
// STATES
//========================================

default {
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        keyID = llGetKey();
        dollName = dollyName();
        myName = llGetScriptName();

        // Beware listener is now available to users other than the doll
        // make sure to take this into account within all handlers.
        //chatHandle = llListen(chatChannel, "", "", "");
        cdInitializeSeq();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        parseLinkHeader(data,i);

        if (code == SEND_CONFIG) {
            string name  = (string)split[0];
            string value = (string)split[1];

            split = llDeleteSubList(split,0,0);

            switch (name): {

                case "isVisible": {
                    debugSay(4,"DEBUG-SOEN","isVisible read at " + value);

                    // If isVisible is already set - we don't have to change it,
                    // nor do we have to set the particles again
                    if (isVisible != (integer)value) {

                        isVisible = (integer)value;
                        keyParticlesToggle(isVisible);
                    }
                    break;
                }

#ifdef NOT_USED
                case "visibility": {
                    debugSay(4,"DEBUG-SOEN","Visibility read at " + value);
                    keyParticlesToggle(isVisible);
                    break;
                }
#endif

                case "collapsed": {
                    debugSay(4,"DEBUG-SOEN","Collapse read at " + value);
                    keyParticlesToggle(value == (string)FALSE);
                    break;
                }
            }
        }
#ifdef NOT_USED
        else if (code == SET_CONFIG) {
            string setName = (string)split[0];
            string value   = (string)split[1];
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];
            rlvAPIversion = (string)split[1];
        }
#endif
        else if (code < 200) {
            if (code == INIT_STAGE1) {
                llOwnerSay("Key-specific extensions loaded for " + KEY_SPECIFIC_PRODUCT);
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport(myName,(float)split[0]);
            }
#endif
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

#ifdef NOT_USED
    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string msg) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  chatCommand = filter by specific message

        //----------------------------------------
        // CHAT COMMAND CHANNEL
        //----------------------------------------

        if (channel == chatChannel) {
        }
    }

#define removeLastListTerm(a) llDeleteSubList(a,-2,-1);
#define stopTimer() llSetTimerEvent(0.0)

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
    }
#endif
}

//========== KEYSPECIFIC-SOEN ==========
