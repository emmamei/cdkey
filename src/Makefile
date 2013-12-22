# makefile

.SUFFIXES: .lsl

SRC=Dress.cpp \
	Main.cpp \
	MenuHandler.cpp \
	RLV.cpp \
	Start.cpp \
	Taker.cpp \
	Transform.cpp

OUT=Dress.lsl \
	Main.lsl \
	MenuHandler.lsl \
	RLV.lsl \
	Start.lsl \
	Taker.lsl \
	Transform.lsl

INCLUDES=include/GlobalDefines.lsl \
	include/KeySharedFuncs.lsl \
	include/Utility.lsl

%.lsl: %.cpp
	cpp -C $< | sed 's/^#.*$$//' | cat -s > $@

all: $(OUT)
	cp $^ ../key

clean:
	rm -f *.lsl ../key/*.lsl

