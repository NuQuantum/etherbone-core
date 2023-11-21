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
  
  bool connect(const std::string& ebdevname, eb_format_t busformat);
  bool disconnect(); //Close connection
  void write(const unsigned addr, const unsigned value, eb_format_t busformat);
  void writeCycle(const std::vector<unsigned> &addr, const std::vector<unsigned> &value, eb_format_t busformat) const;
  unsigned read(const unsigned addr, eb_format_t busformat);
  std::vector<unsigned long> readCycle(const std::vector<unsigned> &vAddr, eb_format_t busformat) const;
  unsigned findById(const unsigned long vendor, const unsigned id);
};

#endif