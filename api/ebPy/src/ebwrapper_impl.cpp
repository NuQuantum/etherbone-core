#include "ebwrapper_impl.h"

//Standard bus format: EB_DATAX|EB_ADDRX

EbWrapper::EbWrapperImpl::EbWrapperImpl() {}
EbWrapper::EbWrapperImpl::~EbWrapperImpl() {}

bool EbWrapper::EbWrapperImpl::connect(const std::string& dev, eb_format_t busfmt) {
    ebdevname = dev;
    bool ret;
    try {
      ebs.open(0, busfmt);
      ebd.open(ebs, ebdevname.c_str(), busfmt, 3);
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

  void EbWrapper::EbWrapperImpl::write(const unsigned addr, const unsigned value, eb_format_t busfmt) {
    ebd.write((eb_address_t)addr, busfmt, (eb_data_t)value);
  }

  unsigned EbWrapper::EbWrapperImpl::read(const unsigned addr, eb_format_t busfmt) {
    eb_data_t ret;
    ebd.read((eb_address_t)addr, busfmt, (eb_data_t*)&ret);
    return (unsigned)ret;
  }

  void EbWrapper::EbWrapperImpl::writeCycle(const std::vector<unsigned> &addr, const std::vector<unsigned> &value, eb_format_t busfmt) const {
    Cycle cyc;
    cyc.open(ebd);
    //If address and data vector sizes don't match, use the smaller one
    unsigned size = addr.size();
    if (value.size() < size) size = value.size();
    for (unsigned long i = 0; i < size; i++)
      cyc.write((eb_address_t)addr[i], busfmt, (eb_data_t)value[i]);
    cyc.close();  
  }

  std::vector<unsigned long> EbWrapper::EbWrapperImpl::readCycle(const std::vector<unsigned> &vAddr, eb_format_t busfmt) const {
    std::vector<unsigned long> result(vAddr.size(), 0);
    Cycle cyc;
    cyc.open(ebd);
    for (unsigned long i = 0; i < result.size(); i++)
      cyc.read(vAddr[i], busfmt, &(result[i]));
    cyc.close();
    return result;
  }

  unsigned EbWrapper::EbWrapperImpl::findById(const unsigned long vendor, const unsigned id) {
    std::vector<struct sdb_device> devs;
    unsigned retAdr = -1;
    unsigned cnt = 0;
    ebd.sdb_find_by_identity((uint64_t)vendor, (uint32_t)id, devs);
    cnt = devs.size();
    if (cnt > 0) retAdr = devs[0].sdb_component.addr_first;
    return retAdr;
            
  }
