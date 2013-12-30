// Taker.lsl
//
// DATE: 18 December 2012
//
// 8/19 sits in key, helps change key.  Taker 4 doesn't have allowing inventory drop for getpin
#include "include/GlobalDefines.lsl"

integer cd6011;
integer cd6200;
integer listen_cd6011;
integer wait;

integer getOwnerSubStr(key id) {
    return (-1 * (integer) ("0x" + llGetSubString((string) id,-5,-1)));
}

setup() {
    integer ncd = getOwnerSubStr(llGetOwner()) - 6011;

    if (cd6011 != ncd) {
        // reset listen_cd6011 (?)
        llListenRemove(listen_cd6011);
        cd6011 = ncd;
        listen_cd6011 = llListen(cd6011, "", "", "");
        cd6200 = cd6011 - 122;
    }
}

default {
    state_entry() { lmScriptReset(); }

    timer() {
        // countdown...
        wait -= 1;
        if (wait == 0) {
            llSetTimerEvent(0.0);
            llAllowInventoryDrop(FALSE);
        }
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            setup();
            lmInitializationCompleted(code);
        }
    }

    listen(integer channel, string name, key id, string choice) {
        if (channel == cd6011) {
            if (llGetSubString(choice,0,2) == "-~-") {
                string todelete = llGetSubString(choice,3,-1);
    
                llOwnerSay(todelete + " is being removed.");
                llRemoveInventory(todelete);
            }
            else if ( choice == "~getpin") {
                integer newpin = (integer) llFrand(-500000.0) - 19;
                llSetRemoteScriptAccessPin(newpin);
                integer ncd = getOwnerSubStr(id) - 6013;   //not needed?
                llSay(cd6200,(string)newpin);
            }
            else {
                if (llGetInventoryType(choice) != -1) {
                    llRemoveInventory(choice);
                }
                llAllowInventoryDrop(TRUE);

                integer ncd = getOwnerSubStr(llGetOwner()) - 6013;
                llSay(ncd + 7, choice);
                
                // Timer set...
                wait = 15;
                llSetTimerEvent(10.0);
                //presumably no need to listen?
            }
        }
    }
}
