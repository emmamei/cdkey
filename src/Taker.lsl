//========================================
// Taker.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/GlobalDefines.lsl"

integer cd6011;
integer cd6200;
integer listen_cd6011;
integer wait;

integer initState = 104;

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

        scaleMem();

        if (code == 104 || code == 105) {
            string script = llList2String(split, 0);
            if (script != "Start") return;
            if (code == 104 && initState == 104) lmInitState(initState++);
            else if (code == 105 && initState == 105) lmInitState(initState++);
        }
        else if (code == 110) {
            initState = 105;
            llSetScriptState(llGetScriptName(), 0);
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
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

