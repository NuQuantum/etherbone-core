#ifndef _EB_WRAPPER_H_
#define _EB_WRAPPER_H_

#include <stdio.h>
#include <iostream>
#include <string>
#include <inttypes.h>
#include <memory>
#include <vector>

#define STD_BUSFMT 0xFF	//EB_DATAX | EB_ADDRX

class EbWrapper {

  private:

  class EbWrapperImpl;
  std::unique_ptr<EbWrapperImpl> impl_;

public:
  EbWrapper();
  ~EbWrapper();
  
  bool connect(const std::string& ebdevname);
  bool connectEx(const std::string& ebdevname, int busfmt = STD_BUSFMT);
  bool disconnect(); //Close connection
  void write(const unsigned addr, const unsigned value) const;
  void writeEx(const unsigned addr, const unsigned value, int busfmt = STD_BUSFMT) const;
  void writeCycle(std::vector<unsigned> addr, std::vector<unsigned> value) const; 
  void writeCycleEx(std::vector<unsigned> addr, std::vector<unsigned> value, int busfmt = STD_BUSFMT) const; 
  std::vector<unsigned long> readCycle(std::vector<unsigned> vAddr) const;
  std::vector<unsigned long> readCycleEx(std::vector<unsigned> vAddr, int busfmt = STD_BUSFMT) const;
  unsigned read(const unsigned addr) const;
  unsigned readEx(const unsigned addr, int busfmt = STD_BUSFMT) const;
  unsigned findById(const unsigned long vendor, const unsigned id);
};

#endif