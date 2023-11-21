%module eb
%include stdint.i
%include std_string.i
%include typemaps.i
%include cpointer.i
%include std_vector.i


// Make etherbone_wrap.cxx include this header:
%{
#include "ebwrapper.h"
%}


// Instantiate possible versions of std::vector used
namespace std {
  %template(vectori) vector<int>;
  %template(vectoru) vector<unsigned>;
  %template(vectorl) vector<long>;
  %template(vectorul) vector<unsigned long>;
};  


// Make SWIG look into this header:
%include "ebwrapper.h"

