#include "ebwrapper.h"
#include "ebwrapper_impl.h"

  EbWrapper::EbWrapper() : impl_(new EbWrapperImpl()) {}
  EbWrapper::~EbWrapper() = default;

  // Etherbone interface
  bool EbWrapper::connect(const std::string& en)                                             {return impl_->connect(en);} //Open connection to a DM via Etherbone
  bool EbWrapper::disconnect()                                                               {return impl_->disconnect();} //Close connection
  void EbWrapper::write(const unsigned addr, const unsigned value) const                     {return impl_->write(addr, value);} //Open connection to a DM via Etherbone
  unsigned EbWrapper::read(const unsigned addr) const                                        {return impl_->read(addr);} //Close connection
  unsigned EbWrapper::findById(const unsigned long vendor, const unsigned id) {return impl_->findById(vendor, id);}