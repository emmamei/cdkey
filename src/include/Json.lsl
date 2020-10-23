#ifndef JSON_LSL
#define JSON_LSL
float Json_version=1.0;
key requestLoadData;

// Data Type Values
#define RLV_STRIP 0
#define RLV_RESTRICT 1

// Data Source Names
#define RLV_NC "DataRLV"

// Data Keys (Notecard Lines)
#define RLV_STRIP_TOP 0
#define RLV_STRIP_BRA 1
#define RLV_STRIP_BOTTOM 2
#define RLV_STRIP_PANTIES 3
#define RLV_STRIP_SHOES 4
#define RLV_BASE_RESTRICTIONS 5

// General data functions
#define cdLoadData(source,index) requestLoadData = llGetNotecardLine(source,index)
#define cdGetValue(data,reference) llJsonGetValue(data, reference)
#define cdGetElementType(data,reference) llJsonValueType(data, reference)
#define cdSetValue(data,reference,value) llJsonSetValue(data, reference, value)
#define cdInteger2ParamRLV(setState) cdGetValue("[\"y\",\"n\"]",([setState]))
#define cdSetRestrictionsList(restrictions,state) {integer i;\
string restriction;\
string param = cdInteger2ParamRLV(state);\
while( ( restriction = cdGetValue(restrictions,([1,group,i++])) ) != JSON_INVALID) restrictionList += restriction + "=" + param + ",";}

#define cdSendConfig(json) llMessageLinked(LINK_THIS, 301, json, NULL_KEY)

#endif //JSON_LSL
