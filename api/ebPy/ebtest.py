import eb

ebobj = eb.EbWrapper()
ebobj.connect("dev/ttyUSB0")
print("0x%8x" % ebobj.read(0x4120000))