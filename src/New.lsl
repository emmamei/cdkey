//========================================
// New.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

// Minimalist script to verify that upgrade worked

default {
    state_entry() {
        if (llGetStartParameter() == 100) {
            llOwnerSay("Key has been updated.");
        }

        llOwnerSay("Update was successful.");
        llSleep(1.0);
        llRemoveInventory(llGetScriptName());
    }
}

//========== NEW ==========
