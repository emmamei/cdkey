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

msg (string s) {
    llOwnerSay(s);
    llSleep(delayTime);
}

default {
    link_message(integer source, integer num, string choice, key id) {
        if (num == 200) { // Triggered from Main.lsl

            llOwnerSay("---- Community Doll Key loaded: Version: 25 March 2013");
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
        }
    }
}
