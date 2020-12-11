//========================================
// New.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

// Minimalist script to verify that upgrade worked

default {
    on_rez(integer start_param) {
        llSay(PUBLIC_CHANNEL, "Update is successful.");
        llSleep(1.0);
        llRemoveInventory(llGetScriptName());
    }
}

//========== NEW ==========
