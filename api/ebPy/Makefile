EBPATH	?= /home/mkreider/projects/bel_projects/ip_cores/etherbone-core/api
EB_LIB	=-letherbone
EB_INCPATH	= $(EBPATH)/include
LIBPATH	= /home/mkreider/projects/ebPy

PREFIX	?= /usr/local
INSTALLPATH	= $(PREFIX)/bin

T_CXX	= g++
T_CXXFLAGS	= -g -std=c++11 -fPIC -I$(LIBPATH) -I$(EB_INCPATH) -Wall -DETHERBONE_THROWS=1 
SRC_FILES	= ebwrapper.cpp ebwrapper_impl.cpp

T_SOURCES	= $(addprefix $(SRCPATH)/, $(SRC_FILES)) 
T_OBJECTS	= $(subst .cpp,.o,$(SRC_FILES))
T_LIBS	= -Wl,-rpath,/usr/local/lib $(EB_LIB) 

TOOLPATH	= $(LIBPATH)
SRCPATH = $(LIBPATH)

all: lib foo

lib: libebwrapper.so _eb.so

eb_wrap.cxx: ebwrapper.h eb.i
	swig -Wall -c++ -python eb.i

eb_wrap.o: eb_wrap.cxx
	$(T_CXX) $(FOO) $(T_CXXFLAGS) -c $< -o $@  -lpython2.7 -I/usr/include/python2.7/

%.o: $(SRCPATH)/%.cpp
	$(T_CXX) $(FOO) $(T_CXXFLAGS) -c $< -o $@ $(T_LIBS)

libebwrapper.so: $(T_OBJECTS)
	$(T_CXX) $(T_CXXFLAGS) -shared -o $@ $^ $(T_LIBS)

_eb.so: $(T_OBJECTS) eb_wrap.o libebwrapper.so
	$(T_CXX) $(T_CXXFLAGS) -shared -o $@ eb_wrap.o $(LIBPATH)/libebwrapper.so -lpython2.7 -I/usr/include/python2.7/ 


clean::
	rm -f $(TOOLPATH)/*.o $(TOOLPATH)/*.a $(TOOLPATH)/*.so $(TOOLPATH)/*.elf $(TOOLPATH)/libebwrapper.so $(TOOLPATH)/_eb.so $(TOOLPATH)/foo $(TOOLPATH)/*.pyc $(TOOLPATH)/eb.py $(TOOLPATH)/eb_wrap.cxx

.SECONDEXPANSION:
foo: main.cpp libebwrapper.so
	$(T_CXX) $(T_CXXFLAGS) -o $@ $< $(LIBPATH)/libebwrapper.so $(T_LIBS) 


#
#g++ -fPIC -Wall -Wextra -shared etherbone_wrap.cxx -o _etherbone.so -lstdc++ -L. -letherbone -lpython2.7 -Wl,--verbose -I/usr/include/python2.7/

