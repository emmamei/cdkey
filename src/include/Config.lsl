#ifndef CONFIG_LSL
#define CONFIG_LSL

//========================================
// BUILD REPORT
//========================================

float Config_version=1.0;

#ifdef HOMING_BEACON
#define OPT_HOMING ["HomingBeacon"]
#else
#define OPT_HOMING []
#endif

#ifdef SINGLE_SELF_WIND
#define OPT_SINGLEWIND ["SingleSelfWind"]
#else
#define OPT_SINGLEWIND []
#endif

#ifdef ROLLOVER
#define OPT_ROLLOVER ["RollOver"]
#else
#define OPT_ROLLOVER []
#endif

#ifdef ADULT_MODE
#define OPT_ADULT ["Adult"]
#else
#define OPT_ADULT ["Child"]
#endif

#ifdef DEBUG_LEVEL
#define OPT_DEBUG ["Debug="+(string)DEBUG_LEVEL]
#else
#define OPT_DEBUG []
#endif

#ifdef DEVELOPER_MODE
#define OPT_KEY_MODE ["Mode=Developer"]
#else
#define OPT_KEY_MODE ["Mode=Normal"]
#endif

#define BUILD_REPORT (OPT_ADULT + OPT_KEY_MODE + OPT_DEBUG + OPT_ROLLOVER + OPT_SINGLEWIND + OPT_HOMING)

#define lmConfigReport() llMessageLinked(LINK_THIS, 142, cdMyScriptName(), NULL_KEY)

//#define cdConfigReport() if (code == 142) llOwnerSay(__SHORTFILE__ + ":" + (string)__LINE__ + "\t\t\t\tCompiled  by " + __AGENTNAME__ + "\t" +  __DATE__ + " " + __TIME__ + "\nWith: " + llList2CSV(BUILD_REPORT))
#define cdConfigureReport() llOwnerSay(__SHORTFILE__ + ": Compiled  by " + __AGENTNAME__ + " on " +  __DATE__ + " at " + __TIME__ + " Options: " + llList2CSV(BUILD_REPORT))

#endif //CONFIG_LSL
