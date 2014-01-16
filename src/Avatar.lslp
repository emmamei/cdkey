#include "include/GlobalDefines.lsl"

integer initState = 104;

default {
    state_entry() {
        
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        
        if (code == 102) {
            
        }
        else if (code == 104) {
            if (initState == 104) lmInitState(initState++);
        }
        else if (code == 105) {
            if (initState == 105) lmInitState(initState);
        }
    }
}
