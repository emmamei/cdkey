#ifndef LINK_MSG_LIB
#define LINK_MSG_LIB

#define cdReadLinkHeader() list split = llParseString2List(data,["|"],[]); string script = llList2String(split,0); integer line = llList2Integer(split,1); integer seq = (code&0xFFFF0000)>>16; integer opt = (code & 0x00000D00)>>10; integer code = (code & 0x000002FF); split = llDeleteSubList(split,0,1+opt)


// Link messages
#define lmSendToAgent(msg, id)                          llMessageLinked(LINK_THIS, 11,  cdMyScriptName()+"|"+cdMyScriptLine()+"|"+msg,id)
#define lmSendToAgentPlusDoll(msg,id)                   llMessageLinked(LINK_THIS, 12,  cdMyScriptName()+"|"+cdMyScriptLine()+"|"+msg,id)
#define lmSendToController(msg)                         llMessageLinked(LINK_THIS, 15,  cdMyScriptName()+"|"+cdMyScriptLine()+"|"+msg,NULL_KEY)
#define lmConfigComplete(count)                         llMessageLinked(LINK_THIS, 102, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+(string)(count),NULL_KEY)
#define lmInitState(num)                                llMessageLinked(LINK_THIS,(num),cdMyScriptName()+"|"+cdMyScriptLine()+"|"+(string)(num),NULL_KEY)
#define lmMemReport(delay,user)                         llMessageLinked(LINK_THIS, 135, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+(string)delay+"|"+(string)user,NULL_KEY)
#define lmMemReply(json)                                llMessageLinked(LINK_THIS, 136, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+json,NULL_KEY)
#define lmRating(simrating)                             llMessageLinked(LINK_THIS, 150, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+simrating, NULL_KEY)
#define lmSendConfig(name,value)                        llMessageLinked(LINK_THIS, 300, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+name+"|"+value,NULL_KEY)
#define lmInternalCommand(command,parameter,id)         llMessageLinked(LINK_THIS, 305, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+command+"|"+parameter, id)
#define lmStrip(part)                                   llMessageLinked(LINK_THIS, 305, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+"strip"+"|"+part,id)
#define lmRunRLV(command)                               llMessageLinked(LINK_THIS, 315, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+"|"+command,NULL_KEY)
#define lmRunRLVas(vmodule,command)                     llMessageLinked(LINK_THIS, 315, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+vmodule+"|"+command, NULL_KEY)
#define lmConfirmRLV(forscript,command)                 llMessageLinked(LINK_THIS, 320, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+forscript+"|"+command, NULL_KEY)
#define lmRLVreport(active,apistring,apiversion)        llMessageLinked(LINK_THIS, 350, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+(string)active+"|"+apistring+"|"+(string)apiversion,NULL_KEY)
//#define lmUpdateStatistic(name,value)                 llMessageLinked(LINK_THIS, 399, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+name+"|"+value,NULL_KEY)
#define lmMenuReply(choice,name,id)                     llMessageLinked(LINK_THIS, 500, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+choice+"|"+name,id)
#define lmTextboxReply(type,name,choice,id)             llMessageLinked(LINK_THIS, 501, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+(string)type+"|"+name+"|"+choice,id)
#define lmBroadcastReceived(name,msg,id)                llMessageLinked(LINK_THIS, 800, cdMyScriptName()+"|"+cdMyScriptLine()+"|"+name+"|"+llGetOwnerKey(id)+"|"+msg,id)

// Virtual function style new link commands
#define cdCarry(id)             lmInternalCommand("carry", (carrierName = llGetDisplayName(id)), (carrierID = id))
#define cdUncarry()             lmInternalCommand("uncarry", carrierName, carrierID)


#endif
