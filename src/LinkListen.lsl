// LinkListen.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 8 December 2013
//
// Optional debug script to monitor link message activity
// between the scripts while being compatible with the new
// startup and initialization system.

#include "include/GlobalDefines.lsl"

// Selector format
// 1st Param, lowest link code value to match inclusive.
// 2nd Param, highest link code value to match inclusive.
// 3rd Param, if specified substring match on src script name, "" for no filter
// 4th Param, if specified substring match on the msg payload, "" for no filter
list selectors = [ 
    100, 110, "", "",
    136, 136, "", "",
    301, 304, "", "",
    315, 315, "", "",
    500, 500, "", ""
];

default
{
    state_entry() {
        selectors = llListSort(selectors, 3, 1);
    }
    
    link_message(integer sender, integer i, string data, key id) {
        llSetMemoryLimit(llGetUsedMemory()+2048);
        
        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);
        
        if (code != 700) {
            integer i; integer n = llGetListLength(selectors) / 3; integer ok;
            while (!ok && (i < n) && (llList2Integer(selectors, i*3) <= code)) {
                if ((code <= llList2Integer(selectors, i*3+1)) &&
                    ((llList2String(selectors, i*3+2) == "") || (llSubStringIndex(script, llList2String(selectors, i*3+2)) != -1)) &&
                    ((llList2String(selectors, i*3+3) == "") || (llSubStringIndex(data, llList2String(selectors, i*3+3)) != -1))) {
                        if (id != NULL_KEY) data +=  "; " + (string)id;
                        llOwnerSay((string)code + "; " + script + "; " + llList2CSV(split));
                        ok = 1;
                }
                i++;
            }
        }
        else {
            if (id != NULL_KEY) data +=  "; " + (string)id;
            llOwnerSay((string)code + "; " + llList2String(split,0) + "; " + llList2CSV(llDeleteSubList(split,0,0)));
        }
        
        if (code == 135) {
            float delay = cdListFloatElement(split, 0);
            scaleMem();
            memReport(cdMyScriptName(),delay);
        }
        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            
            if (name == "debugLevel") debugLevel = (integer)value;
        }
    }
}
