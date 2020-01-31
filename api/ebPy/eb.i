%module eb
%include stdint.i
%include std_string.i
%include typemaps.i
%include cpointer.i




// Make SWIG look into this header:
%include "ebwrapper.h"

// Make etherbone_wrap.cxx include this header:
%{
#include "ebwrapper.h"
%}
