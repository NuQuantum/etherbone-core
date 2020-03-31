#ifndef _EB_WRAPPER_H_
#define _EB_WRAPPER_H_

#include <stdio.h>
#include <iostream>
#include <string>
#include <inttypes.h>
#include <memory>

class EbWrapper {

  private:

  class EbWrapperImpl;
  std::unique_ptr<EbWrapperImpl> impl_;

public:
  EbWrapper();
  ~EbWrapper();
  
  bool connect(const std::string& ebdevname);
  bool disconnect(); //Close connection
  //bool writeCycle(std::vector<unsigned> vVal) const;
  void write(const unsigned addr, const unsigned value) const;
  //std::vector<unsigned> readCycle(std::vector<unsigned> vAddr) const;
  unsigned read(const unsigned addr) const;
  unsigned findById(const unsigned long vendor, const unsigned id);
};

#endif