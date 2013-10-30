// 8/19 sits in key, helps change key.  Taker 4 doesn't have allowing inventory drop for getpin


integer cd6011;
integer cd6200;
integer listen_cd6011;
integer wait;

setup() {
    integer ncd = ( -1 * (integer)("0x"+llGetSubString((string)llGetOwner(),-5,-1)) ) -6011;
    if (cd6011 != ncd) {
        llListenRemove(listen_cd6011);
        cd6011 = ncd;
        listen_cd6011 = llListen(cd6011, "", "", "");
        cd6200 = cd6011 - 122;
    }
}


default {
    state_entry() {
        cd6011 = 0;
        setup();
    }

    on_rez(integer iParam) {  //when key is put on, or when logging back on
        setup();
    }

    timer() {  
        wait -= 1;
        if (wait == 0) {
            llSetTimerEvent(0.0);
            llAllowInventoryDrop(FALSE);
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
                integer ncd =   -1 * (integer)("0x"+llGetSubString((string)id,-5,-1))  -6013;   //not needed?
                llSay(cd6200,(string)newpin);
            }
            else {
                if (llGetInventoryType( choice ) != -1) {
                    llRemoveInventory(choice);
                }
                llAllowInventoryDrop(TRUE);

                integer ncd =   -1 * (integer)("0x"+llGetSubString((string)id,-5,-1))  -6013;
                llSay(ncd+7, choice);
                wait = 15;
                llSetTimerEvent(10.0);
                //presumably no need to listen?
            }
        }
    }
}

