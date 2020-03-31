import eb

ebobj = eb.EbWrapper()
ebobj.connect("dev/ttyUSB0")
vendorID 	= 0x0000000000000651 
productID 	= 0x10040200
prioAdr = ebobj.findById(vendorID, productID)
print("prioadr 0x%8x " % (prioAdr))
print("1st word ram 0x%8x" % ebobj.read(0x4120000))
