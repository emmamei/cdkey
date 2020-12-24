//========================================
// New.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

// Minimalist script to verify that upgrade worked

#define RUNNING 1
#define NOT_RUNNING 0
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)

doRestart() {
    integer n;
    string script;

    // The UpdaterClient script could be running now, but
    // since we are restarting, don't let the timer continue,
    // since we'll be resetting it anyway.
    cdStopScript("UpdaterClient");

    // Set all other scripts to run state and reset them
    n = llGetInventoryNumber(INVENTORY_SCRIPT);
    while(n--) {

        script = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (script != "Start") {

            cdRunScript(script);
            //llResetOtherScript(script);
        }
    }

    llSleep(1.0);
    cdRunScript("Start");
    llResetOtherScript("Start");
}

default {
    state_entry() {
        if (llGetStartParameter() == 100) {
            llOwnerSay("Key has been updated.");
        }

        llOwnerSay("Update was successful.");

        //doRestart();

        llSleep(1.0);
        llRemoveInventory(llGetScriptName());
    }
}

//========== NEW ==========
