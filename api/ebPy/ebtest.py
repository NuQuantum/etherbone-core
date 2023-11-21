import eb
from ebdef import ebStatus, ebFormat

ebobj = eb.EbWrapper()
if (ebobj.connect("dev/wbm0")):
	print("ebobj connect OK")
	vendorID 	= 0x000000000000ce42 
	#vendorID	= 0x0000000000000651 
	productID 	= 0xde0d8ced	
	#productID	= 0x10040200
	ioAdr = ebobj.findById(vendorID, productID)
	print("WR PPS Addr: 0x%08x " % (ioAdr))
	#print("1st word  0x%08x" % ebobj.read(ioAdr+8))
	addr = [ioAdr, ioAdr+4, ioAdr+8, ioAdr+12]
	data = ebobj.readCycleEx(addr, ebFormat.EB_DATA32 | ebFormat.EB_ADDR32)
	print("Data: ", data)
	timestamp = (data[3] & 0xFF)*(1<<32) + data[2] + data[1]*8e-9;
	print("Timestamp: ", timestamp);

else:
	print("ebobj connect ERROR")

print("Finished.")
