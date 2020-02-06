EB_PATH         = ..
EB_INCPATH      = $(EB_PATH)/include
BUILD_PATH      = .
INC_PATH        = $(BUILD_PATH)/inc
SRC_PATH        = $(BUILD_PATH)/src
EB_LIB          = etherbone

#works with python 2 and 3. Set to your python lib and include directory
PY_LIB          = python3.6m
PY_INCPATH      = /usr/include/python3.6m

PREFIX         ?= /usr/local
INSTALLPATH     = $(PREFIX)/bin

T_CXX           = g++
T_CXXFLAGS      = -g -std=c++11 -fPIC -I$(INC_PATH) -I$(EB_INCPATH) -Wall -DETHERBONE_THROWS=1 
SRC_FILES       = ebwrapper.cpp ebwrapper_impl.cpp

T_SOURCES       = $(addprefix $(SRC_PATH)/, $(SRC_FILES)) 
T_OBJECTS       = $(subst .cpp,.o,$(SRC_FILES))
T_LIBS          = -Wl,-rpath,/usr/local/lib  

all: lib

#TODO: currently uses two shared libraries to do the PIMPL wrapping. Reduce to one.
#(SWIG doesn't understand some of EB's datatypes and needs to be kept ignorant of the details)

lib: libebwrapper.so _eb.so

eb_wrap.cxx: $(INC_PATH)/ebwrapper.h eb.i
	swig -I$(INC_PATH) -Wall -c++ -python eb.i

eb_wrap.o: eb_wrap.cxx
	$(T_CXX) $(T_CXXFLAGS) -c $< -l$(PY_LIB) -I$(PY_INCPATH)

%.o: $(SRC_PATH)/%.cpp
	$(T_CXX) $(T_CXXFLAGS) -c $< $(T_LIBS)

libebwrapper.so: $(T_OBJECTS)
	$(T_CXX) $(T_CXXFLAGS) -shared -o $@ $^ $(T_LIBS) -l$(EB_LIB)

_eb.so: $(T_OBJECTS) eb_wrap.o libebwrapper.so
	$(T_CXX) $(T_CXXFLAGS) -shared -o $@ eb_wrap.o $(BUILD_PATH)/libebwrapper.so -l$(PY_LIB) -I$(PY_INCPATH) 

clean::
	rm -rf $(T_OBJECTS) eb_wrap.o libebwrapper.so _eb.so eb_wrap.cxx eb.py eb.pyc __pycache__


