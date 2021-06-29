//========================================
// StatusRLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"

#define CHATMSG_MAXLEN 896
#define TESTING_DATASERVER 1

//========================================
// VARIABLES
//========================================

string scriptName;
integer statusChannel = 55117;
integer statusHandle;
integer rlvCmdIssued;

//========================================
// FUNCTIONS
//========================================

doRlvClear(string commandString) {
    // this is a blanket clear, but it doesn't mean to us what
    // it means normally: we have a base RLV set

    debugSay(2,"DEBUG-STATUSRLV","RLV clear command issued from " + script);
    //llSay(DEBUG_CHANNEL,"rlvClearCmd run from " + script);

    llOwnerSay("@clear"); // clear command

    if (commandString != "")
        llOwnerSay("@" + commandString); // restore restrictions if need be

    lmInternalCommand("restoreRestrictions",script,NULL_KEY); // restore RLV restrictions
    lmInternalCommand("reloadExceptions",script,NULL_KEY); // then restore exceptions
}

doRlvCommand(string commandString) {

#ifdef DEVELOPER_MODE
    if (commandString == "clear") {
        llSay(DEBUG_CHANNEL,"Clear command run from " + script + " using lmRlvInternalCmd - use rlvClearCmd instead");
        lmRlvInternalCmd("rlvClearCmd",commandString);
        return;
    }

    // This could thereotically happen...
    if (commandString == "" || commandString == "0") {
        llSay(DEBUG_CHANNEL,"requested RLV command (in runRlvCommand) from " + script + " is empty!");
        return;
    }

    if (llStringLength(commandString) > CHATMSG_MAXLEN) {
        llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is too long!");
        return;
    }

    debugSay(6,"DEBUG-STATUSRLV","RLV received: @" + commandString);
#endif

    llOwnerSay("@" + commandString);
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        rlvOk = TRUE;
        myName = llGetScriptName();
        keyID = llGetKey();

        cdInitializeSeq();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        cdInitializeSeq();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer lmSource, integer lmInteger, string lmData, key lmID) {

        parseLinkHeader(lmData,lmInteger);

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];
            integer integerValue = (integer)value;

            switch (name) {

                case "rlvOk": {
                    rlvOk = integerValue;
                    break;
                }

#ifdef DEVELOPER_MODE
                case "debugLevel": {
                    debugLevel = integerValue;
                    break;
                }
#endif
            }

            return;
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            //split = llDeleteSubList(split, 0, 0);

            switch (cmd) {
                case "instantMessage": {

                    // This is segregated for speed: this script (StatusRLV) doesn't have
                    // an overriding need to not have a 2s delay in it
                    llInstantMessage(lmID,(string)split[0]);
                    break;
                }
            } // switch
        } // INTERNAL_CMD
        else if (code == RLV_CMD) {
            string internalRlvCommand = (string)split[1];
            string rlvCommand = (string)split[2];

#ifdef DEVELOPER_MODE
            string rlvScript = (string)split[0];

            debugSay(4,"DEBUG-STATUSRLV","RLV_CMD script " + rlvScript + ": internalRlvCommand = " + internalRlvCommand + ": rlvCommand = " + rlvCommand);

            if (rlvOk != TRUE) {
                if (rlvOk == UNSET) llSay(DEBUG_CHANNEL,"RLV command issued with RLV inactive from " + rlvScript + "! (" + rlvCommand + ")");
                return;
            }
#endif

            switch(internalRlvCommand) {

                case "rlvClearCmd": {
                    doRlvClear(rlvCommand);
                    break;
                }

                case "rlvRunCmd": {
                    doRlvCommand(rlvCommand);
                    break;
                }

                default: {
                    doRlvCommand(internalRlvCommand);
                    break;
                }
            }
        }
        else if (code == RLV_RESET) {
            rlvOk = (integer)split[0];

            if (rlvOk == TRUE)
                lmInternalCommand("restoreRestrictions",script,NULL_KEY); // restore RLV restrictions
        }
        else if (code < 200) {
            if (code == CONFIG_REPORT) {

                cdConfigureReport();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                float delay = (float)split[0];

                memReport(myName,delay);
            }
#endif
        }
    }
}

//========== STATUSRLV ==========
