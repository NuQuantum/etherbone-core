#ifndef _EB_WRAPPER_IMPL_H_
#define _EB_WRAPPER_IMPL_H_

#include <stdio.h>
#include <iostream>
#include <string>
#include <inttypes.h>
#include "etherbone.h"
#include "ebwrapper.h"

#define SDB_VENDOR_GSI      0x0000000000000651ULL
#define SDB_DEVICE_LM32_RAM 0x54111351
#define SDB_DEVICE_DIAG     0x18060200




using namespace etherbone;


class EbWrapper::EbWrapperImpl {

private:
  Socket ebs;
  Device ebd;
  std::string ebdevname;

public:
  EbWrapperImpl();
  ~EbWrapperImpl();
  
  bool connect(const std::string& ebdevname);
  bool disconnect(); //Close connection
  //bool writeCycle(std::vector<unsigned> vVal) const;
  void write(const unsigned addr, const unsigned value);
  //std::vector<unsigned> readCycle(std::vector<unsigned> vAddr) const;
  unsigned read(const unsigned addr);
  unsigned findById(const unsigned long vendor, const unsigned id);
};

#endif