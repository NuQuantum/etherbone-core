#include <stdio.h>
#include <iostream>
#include <string>
#include <inttypes.h>
#include <time.h>
#include <unistd.h>

#include "ebwrapper.h"


int main(int argc, char* argv[]) {




  EbWrapper ebw;



  try {
    ebw.connect(std::string("dev/ttyUSB0"));
  } catch (std::runtime_error const& err) {
    std::cerr  << ": Could not connect to TR. Cause: " << err.what() << std::endl; return -20;
  }

  


  return 0;
}
