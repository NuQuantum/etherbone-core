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