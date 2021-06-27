//========================================
// testScript.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

key queryLandmarkData;

//========================================
// FUNCTIONS
//========================================

#define getRegionLocation(d) (llGetRegionCorner() + ((vector)d))
#define locationToString(d) ((string)((integer)d.x) + "/" + (string)((integer)d.y) + "/" + (string)((integer)d.z))

rlvTeleport(string locationData) {

    //debugSay(6,"DEBUG-LANDMARK","queryLandmarkData = " + (string)queryLandmarkData);

    vector globalLocation = getRegionLocation(locationData);
    string globalPosition = locationToString(globalLocation);

    //debugSay(6,"DEBUG-LANDMARK","Dolly should be teleporting now...");
    //debugSay(6,"DEBUG-LANDMARK","Position = " + globalPosition);
    llOwnerSay("Position = " + globalPosition);

    llOwnerSay("Dolly is now teleporting.");

    // Note this will be rejected if @unsit=n or @tploc=n are active
    //lmRunRlvAs("TP-LANDMARK","unsit=y"); // restore restriction
    //lmRunRlvAs("TP-LANDMARK","tploc=y"); // restore restriction

    // Perform TP
    //lmRunRlvAs("TP-LANDMARK","tpto:" + globalPosition + "=force");

    // FIXME: Determine whether this is needed or not

    // Restore restrictions as needed
    //lmRunRlvAs("TP-LANDMARK","tploc=n"); // restore restriction
    //lmRunRlvAs("TP-LANDMARK","unsit=n"); // restore restriction
}

doTeleport(string landmark) {
/*
    if (!isLandmarkPresent(landmark)) {
        //debugSay(6,"DEBUG-LANDMARK","No landmark by the name of \"" + landmark + "\" is present in inventory.");
        llSay(DEBUG_CHANNEL,"No landmark named " + landmark);
        return;
    }
*/

    // This should trigger a dataserver event
    queryLandmarkData = llRequestInventoryData(landmark);

    if (queryLandmarkData == NULL_KEY) {
        //llSay(DEBUG_CHANNEL,"Landmark <" + landmark + "> does not exist.");
        llSay(DEBUG_CHANNEL,"llRequestInventoryData error.");
        return;
    }

    //debugSay(6,"DEBUG-LANDMARK","queryLandmarkData set to " + (string)queryLandmarkData);
    llOwnerSay("queryLandmarkData set to " + (string)queryLandmarkData);
    //debugSay(6,"DEBUG-LANDMARK","Teleporting dolly " + dollName + " to  inventory landmark \"" + landmark + "\".");
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        doTeleport("Home");
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {

    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {

    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key queryID, string queryData) {

        if (queryID == queryLandmarkData) {
            rlvTeleport(queryData);
        }
#ifdef DEVELOPER_MODE
        else {
            debugSay(6,"DEBUG-LANDMARK","queryID is not equal to queryLandmarkData - skipping");
        }
#endif
    }
}

//========== TESTSCRIPT ==========
