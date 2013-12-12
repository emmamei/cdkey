// Start.lsl
//
// DATE: 18 December 2012
//
// This is the initial hypnotic suggestion and RolePlay
// called from Main.lsl.  The text is sent to the Key
// owner over the space of about three minutes when the
// Key is first used.
//
// As of 30 October 2013, this script is unused.

float delayTime = 15.0; // in seconds

key ncPrefsKey;
key ncPrefsLoadedUUID = NULL_KEY;
string ncName = "Preferences";
integer ncLine;
integer replyHandle;

string optiondate = "12 December 2013";

msg (string s) {
    llOwnerSay(s);
    llSleep(delayTime);
}

initConfiguration() {
    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(ncName) == INVENTORY_NOTECARD) {

        // Start reading from first line (which is 0)
        ncLine = 0;
        ncPrefsKey = llGetNotecardLine(ncName, ncLine);

    } else {

        // File missing - report for debugging only
        llOwnerSay("No configuration found (" + ncName + ")");
    }
}

default {
    link_message(integer source, integer num, string choice, key id) {
        if (num == 200) { // Triggered from Main.lsl

            llOwnerSay("---- Community Doll Key loaded: Version: " + optiondate);
            llOwnerSay("---- Key: " + llKey2Name(id));

            // First minute....
            msg("You feel a key being put on your back, the weight settling in. Imagine that as vividly as you can.");
            msg("You feel a pinch as tendrils from the key sink into your back, and then a flood of cool relief as they sink in further.");
            msg("The tendrils are releasing doll hormones into your body, and you feel the rush through every pore in your body.");
            msg("The hormones are relaxing you and making you feel comfortable with being a doll. Any fears you had have slipped away and are forgotten.");

            // Second minute....
            msg("You realize how wonderful it would be to be displayed and everyone just admire you for your beauty - and you marvel that you never knew this before.");
            msg("You now realize how wonderful it is to be liked - more wonderful than you ever knew.");
            msg("You realize your dependency on the community; this will define you. You now accept and welcome this.");
            msg("You only now realize how beautiful you are. You were always beautiful - but now it becomes obvious because you are a doll.");

            // Third minute...
            msg("You realize now that other dolls are your sisters - and understand you like no one else.");
        } else if (num == 11) {
            llInstantMessage(id, choice);
        }
    }
    
    state_entry() {
        initConfiguration();
    }
    
    dataserver(key query_id, string data) {
        if (query_id == ncPrefsKey) {
            if (data == EOF) ncPrefsLoadedUUID = llGetInventoryKey(ncName);
            if (data != "" && llGetSubString(data, 0, 0) != "#") // ignore comments and blank lines
                llMessageLinked(LINK_SET, 101, data, NULL_KEY);
            ncPrefsKey = llGetNotecardLine(ncName, ++ncLine);
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryKey(ncName) != ncPrefsLoadedUUID) {
                // Get a unique number
                integer ncd = -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-7,-1));
                integer channel = ncd - 5467;
                replyHandle = llListen(channel, "", "", "");
                
                llSetTimerEvent(60);
                llDialog(llGetOwner(), "Detected a change in your Preferences notecard, would you like to load the new settings?\n\n" +
                  "WARNING: All current data will be lost!", [ "Reload Config", "Keep Settings" ], channel);
            }
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (message == "Reload Config") {
            llResetOtherScript("Main");
        }
    }
    
    timer() {
        llListenRemove(replyHandle);
    }
}
