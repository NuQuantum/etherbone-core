# Defines used by the etherbone library - translated from etherbone.h

from enum import IntEnum

class ebStatus(IntEnum):
	EB_OK        =  0  # success
	EB_FAIL      = -1  # system failure
	EB_ADDRESS   = -2  # invalid address
	EB_WIDTH     = -3  # impossible bus width
	EB_OVERFLOW  = -4  # cycle length overflow
	EB_ENDIAN    = -5  # remote endian required
	EB_BUSY      = -6  # resource busy
	EB_TIMEOUT   = -7  # timeout
	EB_OOM       = -8  # out of memory
	EB_ABI       = -9  # library incompatible with application
	EB_SEGFAULT  = -10 # one or more operations failed

class ebFormat(IntEnum):
	EB_DATA8     = 0x01
	EB_DATA16    = 0x02
	EB_DATA32    = 0x04
	EB_DATA64    = 0x08
	EB_DATAX     = 0x0f

	EB_ADDR8     = 0x10
	EB_ADDR16    = 0x20
	EB_ADDR32    = 0x40
	EB_ADDR64    = 0x80
	EB_ADDRX     = 0xf0

	EB_ENDIAN_MASK    = 0x30
	EB_BIG_ENDIAN     = 0x10
	EB_LITTLE_ENDIAN  = 0x20

	EB_DESCRIPTOR_IN  = 0x01
	EB_DESCRIPTOR_OUT = 0x02



