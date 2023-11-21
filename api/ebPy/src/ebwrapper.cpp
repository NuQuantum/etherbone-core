#include "ebwrapper.h"
#include "ebwrapper_impl.h"

  EbWrapper::EbWrapper() : impl_(new EbWrapperImpl()) {}
  EbWrapper::~EbWrapper() = default;

  // Etherbone interface
  bool EbWrapper::connect(const std::string& en)                                             {return impl_->connect(en, EB_ADDRX|EB_DATAX);} //Open connection to a DM via Etherbone
  bool EbWrapper::connectEx(const std::string& en, int busfmt)		                     {return impl_->connect(en, busfmt);} //Open connection to a DM via Etherbone

  bool EbWrapper::disconnect()                                                               {return impl_->disconnect();} //Close connection

  void EbWrapper::write(const unsigned addr, const unsigned value) const                     {return impl_->write(addr, value, EB_ADDRX|EB_DATAX);}
  void EbWrapper::writeEx(const unsigned addr, const unsigned value, int busfmt) const                     
											     {return impl_->write(addr, value, busfmt);}

  void EbWrapper::writeCycle(std::vector<unsigned> addr, std::vector<unsigned> value) const  {return impl_->writeCycle(addr, value, EB_ADDRX|EB_DATAX);}
  void EbWrapper::writeCycleEx(std::vector<unsigned> addr, std::vector<unsigned> value, int busfmt) const  
											     {return impl_->writeCycle(addr, value, busfmt);}

  unsigned EbWrapper::read(const unsigned addr) const                                        {return impl_->read(addr, EB_ADDRX|EB_DATAX);}
  unsigned EbWrapper::readEx(const unsigned addr, int busfmt) const  		             {return impl_->read(addr, busfmt);}

  std::vector<unsigned long> EbWrapper::readCycle(std::vector<unsigned> vAddr) const	     {return impl_->readCycle(vAddr, EB_ADDRX|EB_DATAX);}
  std::vector<unsigned long> EbWrapper::readCycleEx(std::vector<unsigned> vAddr, int busfmt) const	
											     {return impl_->readCycle(vAddr, busfmt);}

  unsigned EbWrapper::findById(const unsigned long vendor, const unsigned id) 		     {return impl_->findById(vendor, id);}