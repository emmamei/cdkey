// LinkListen.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 27 October 2014
//
// Optional debug script to monitor link message activity
// between the scripts while being compatible with the new
// startup and initialization system.

#include "include/GlobalDefines.lsl"

key keyID               =   NULL_KEY;
key carrierID           =   NULL_KEY;

string carrierName;

integer msgcount;

list controllers;

// Selector format
// 1st Param, lowest link code value to match inclusive.
// 2nd Param, highest link code value to match inclusive.
// 3rd Param, if specified substring match on src script name, "" for no filter
// 4th Param, if specified substring match on the msg payload, "" for no filter
// Note on match order that may help make things faster
// Selectors are sorted at script init by the first parameter knowing this with the fairly sparse
// allocation of link numbers we have means that 
list selectors = [
     100, 100, "", ""
];

string identifySrc(key sourceID) {
    integer i;
         if (sourceID == dollID)                                            return "Dolly";
    else if (sourceID == keyID)                                             return "Internal";
    else if (sourceID == DATABASE_ID)                                       return "RemoteMySQL";
    else if (cdIsBuiltinController(sourceID))                               return "Builtin:"       + llGetDisplayName(sourceID);
    else if ((i=llListFindList(controllers,[(string)sourceID])) != -1)     return "Controller:"    + llList2String(controllers, i+1);
    else if (sourceID == carrierID)                                         return "Carrier:"       + carrierName;
    else if (llGetOwnerKey(sourceID) == sourceID)                           return "PublicUser:"    + llGetDisplayName(sourceID);
    else if (sourceID == NULL_KEY)                                          return "MissingID";
    else                                                                    return "UnknownType";
}

default
{
    state_entry() {
        dollID = llGetOwner();
        selectors = llListSort(selectors, 4, 1);
    }
    
    on_rez(integer start) {
        keyID = llGetKey();
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
        
        string output;
        if (code != 700) {
            integer i; integer n = llGetListLength(selectors) / 4; integer ok;
            while (!ok && (i < n) && (llList2Integer(selectors, i*4) <= code)) {
                if ((code <= llList2Integer(selectors, i*4+1)) &&
                    ((llList2String(selectors, i*4+2) == "") || (llSubStringIndex(script, llList2String(selectors, i*4+2)) != -1)) &&
                    ((llList2String(selectors, i*4+3) == "") || (llSubStringIndex(data, llList2String(selectors, i*4+3)) != -1))) {
                        output = (string)code + "; " + script + "; " + llList2CSV(split) +  " ~ {" + identifySrc(id) + "}";
                        ok = 1;
                }
                i++;
            }
        }
        else {
            output = llList2String(split,0) + "; " + llList2CSV(llDeleteSubList(split,0,0)) +  " ~ {" + identifySrc(id) + "}";
        }
        
        if (code == 135) {
            float delay = cdListFloatElement(split, 0);
            scaleMem();
            memReport(cdMyScriptName(),delay);
        }
        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            
                 if (name == "debugLevel")          debugLevel = (integer)value;
            else if (name == "controllers")      controllers = llDeleteSubList(split,0,0);
            else if (name == "carrierID")            carrierID = (key)value;
            else if (name == "carrierName")        carrierName = value;
        }
        
        if (output != "") llOwnerSay("[" + llGetSubString((string)llGetTime(),0,-2) + "] <#" + (string)(++msgcount) + "> " + output);
    }
}
