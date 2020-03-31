#include "ebwrapper_impl.h"

EbWrapper::EbWrapperImpl::EbWrapperImpl() {}
EbWrapper::EbWrapperImpl::~EbWrapperImpl() {}

bool EbWrapper::EbWrapperImpl::connect(const std::string& dev) {
    ebdevname = dev;
    bool ret;
    try {
      ebs.open(0, EB_DATAX|EB_ADDRX);
      ebd.open(ebs, ebdevname.c_str(), EB_DATAX|EB_ADDRX, 3);
      ret = true;
    } catch (etherbone::exception_t const& ex) {
      ret = false;
    } return ret;

  }

  bool EbWrapper::EbWrapperImpl::disconnect() {
    bool ret;

    try {
      ebd.close();
      ebs.close();
      ret = true;
    } catch (etherbone::exception_t const& ex) {
      ret = false;
    }
    return ret;
  }

  void EbWrapper::EbWrapperImpl::write(const unsigned addr, const unsigned value) {
    ebd.write((eb_address_t)addr, EB_DATAX|EB_ADDRX, (eb_data_t)value);
  }
  //std::vector<unsigned> readCycle(std::vector<unsigned> vAddr) const;
  unsigned EbWrapper::EbWrapperImpl::read(const unsigned addr) {
    eb_data_t ret;
    ebd.read((eb_address_t)addr, EB_DATAX|EB_ADDRX, (eb_data_t*)&ret);
    return (unsigned)ret;
  }
/*
  void EbWrapper::EbWrapperImpl::write(const std::vector<unsigned> addr&, const std::vector<unsigned> value&) {
    Cycle cyc;

    cyc.open(ebd);
    if addr.size() != value.size() throw std::runtime_error("Address and value vectors must be the same size");
    for (auto& [a, v] : zip(addr, value)) {cyc.write((eb_address_t)a, EB_DATAX|EB_ADDRX, (eb_data_t)v);}
    cyc.close();  
  }

  //std::vector<unsigned> readCycle(std::vector<unsigned> vAddr) const;
  unsigned EbWrapper::EbWrapperImpl::read(const unsigned addr) {
    eb_data_t ret;
    ebd.read((eb_address_t)addr, EB_DATAX|EB_ADDRX, (eb_data_t*)&ret);
    return (unsigned)ret;
  }
  */

  unsigned EbWrapper::EbWrapperImpl::findById(const unsigned long vendor, const unsigned id) {
    std::vector<struct sdb_device> devs;
    unsigned retAdr = -1;
    unsigned cnt = 0;
    ebd.sdb_find_by_identity((uint64_t)vendor, (uint32_t)id, devs);
    cnt = devs.size();
    if (cnt > 0) retAdr = devs[0].sdb_component.addr_first;
    return retAdr;
            
  }