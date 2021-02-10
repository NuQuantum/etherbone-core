#include "sdb-static.h"
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

static struct sdb_device parse_sdb_device(char str[]) {
	struct sdb_device device = {0,};
	sscanf(str," {.device = {"
		       "  .abi_class = %hx,"
		       "  .abi_ver_major = %hhx,"
		       "  .abi_ver_minor = %hhx,"
		       "  .sdb_component = {"
		       "    .addr_first = %lx,"
		       "    .addr_last  = %lx,"
		       "    .product = {"
		       "      .vendor_id = %lx,"
		       "      .device_id = %x," 
		       "      .version   = %x," 
		       "      .date      = %x,"
		       "      .name      = \"%s\","
		       "      .record_type = %hhx," 
		       "     }"
		       "   }"
		       " }}",
		       &device.abi_class,
		       &device.abi_ver_major,
		       &device.abi_ver_minor,
		       &device.sdb_component.addr_first,
		       &device.sdb_component.addr_last,
		       &device.sdb_component.product.vendor_id,
		       &device.sdb_component.product.device_id,
		       &device.sdb_component.product.version,
		       &device.sdb_component.product.date,
		       (char*)&device.sdb_component.product.name,
		       &device.sdb_component.product.record_type);
	device.sdb_component.product.record_type = 0x1;
	return device;
}


static struct sdb_msi parse_sdb_msi(char str[]) {
	struct sdb_msi msi = {0,};
	sscanf(str," {.msi = {"
		       "  .msi_flags = %x,"
		       "  .sdb_component = {"
		       "    .addr_first = %lx,"
		       "    .addr_last  = %lx,"
		       "    .product = {"
		       "      .vendor_id = %lx,"
		       "      .device_id = %x," 
		       "      .version   = %x," 
		       "      .date      = %x,"
		       "      .name      = \"%s\","
		       "      .record_type = %hhx," 
		       "     }"
		       "   }"
		       " }}",
		       &msi.msi_flags,
		       &msi.sdb_component.addr_first,
		       &msi.sdb_component.addr_last,
		       &msi.sdb_component.product.vendor_id,
		       &msi.sdb_component.product.device_id,
		       &msi.sdb_component.product.version,
		       &msi.sdb_component.product.date,
		       (char*)&msi.sdb_component.product.name,
		       &msi.sdb_component.product.record_type);
	msi.sdb_component.product.record_type = 0x3;
	return msi;
}

static struct sdb_bridge parse_sdb_bridge(char str[]) {
	struct sdb_bridge bridge = {0,};
	sscanf(str," {.bridge = {"
		       "  .sdb_child = %lx,"
		       "  .sdb_component = {"
		       "    .addr_first = %lx,"
		       "    .addr_last  = %lx,"
		       "    .product = {"
		       "      .vendor_id = %lx,"
		       "      .device_id = %x," 
		       "      .version   = %x," 
		       "      .date      = %x,"
		       "      .name      = \"%s\","
		       "      .record_type = %hhx," 
		       "     }"
		       "   }"
		       " }}",
		       &bridge.sdb_child,
		       &bridge.sdb_component.addr_first,
		       &bridge.sdb_component.addr_last,
		       &bridge.sdb_component.product.vendor_id,
		       &bridge.sdb_component.product.device_id,
		       &bridge.sdb_component.product.version,
		       &bridge.sdb_component.product.date,
		       (char*)&bridge.sdb_component.product.name,
		       &bridge.sdb_component.product.record_type);
		bridge.sdb_component.product.record_type = 0x2;
	return bridge;
}

static void print_sdb_product(struct sdb_product product) {
	printf("    struct sdb_product {\n");
	printf("      vendor_id  0x%016lx\n", product.vendor_id);
	printf("      device_id          0x%08x\n", product.device_id);
	printf("      version            0x%08x\n", product.version);
	printf("      date               0x%08x\n", product.date);
	printf("      name "); for (int i = 0; i < 19; ++i) printf("%c", product.name[i]); printf("\n");
	printf("      record_type              0x%02x\n", product.record_type);
	printf("    }\n");
}

static void print_sdb_component(struct sdb_component component) {
	printf("  struct sdb_component {\n");
	printf("    addr_first 0x%016lx\n", component.addr_first);
	printf("    addr_last  0x%016lx\n", component.addr_last);
	print_sdb_product(component.product);
	printf("  }\n");
}

void print_sdb_device(struct sdb_device device) {
	printf("struct sdb_device {\n");
	printf("  abi_class         0x%04x\n", device.abi_class);
	printf("  abi_ver_major       0x%02x\n", device.abi_ver_major);
	printf("  abi_ver_minor       0x%02x\n", device.abi_ver_minor);
	print_sdb_component(device.sdb_component);
	printf("}\n");
}

void print_sdb_msi(struct sdb_msi msi) {
	printf("struct sdb_msi {\n");
	printf("  msi_flags         0x%04x\n", msi.msi_flags);
	print_sdb_component(msi.sdb_component);
	printf("}\n");
}
void print_sdb_bridge(struct sdb_bridge bridge) {
	printf("struct sdb_bridge {\n");
	printf("  sdb_child         0x%04lx\n", bridge.sdb_child);
	print_sdb_component(bridge.sdb_component);
	printf("}\n");
}

static struct sdb_static_crossbar* sdb_static_crossbar_from_file_real(const char* filename_prefix, uint32_t sdb_addr, uint32_t base_addr)
{
	// open the file
	char filename[256];
	sprintf(filename, "%s_%08X.h", filename_prefix, sdb_addr);
	FILE *f = fopen(filename, "r");

	if (!f) {
		fprintf(stderr, "error: cannot open file %s\n", filename);
		return NULL;
	}

	struct sdb_static_crossbar* result = (struct sdb_static_crossbar*)malloc(sizeof(struct sdb_static_crossbar));
	memset(result, 0, sizeof(struct sdb_static_crossbar));

	// prepare the pasing
	char ch;
	int num_open_braces = 0;

	// just a string buffer
	char buffer[1024] = {0,};
	int buffer_idx = 0;

	// type of tokens we want to parse
	enum token_types {
		token_type_none,
		token_type_sdb_addr,
		token_type_sdb_record,
	} token_type = token_type_none;

	// parse the file
	while((ch = fgetc(f)) != EOF) {
		// printf("%c",ch);
		if (ch == '{') ++num_open_braces;
		if (ch == '}') --num_open_braces;

		switch(token_type) {
			case token_type_none:
				if (num_open_braces == 0 && ch == '0') { // parse the first hex number in file before the first open brace
					token_type = token_type_sdb_addr;
					buffer_idx = 0;
					buffer[buffer_idx++] = ch;
				} else if (num_open_braces == 2 && ch == '{') {
					token_type = token_type_sdb_record;
					buffer_idx = 0;
					buffer[buffer_idx++] = ch;
				}
			break;
			case token_type_sdb_addr:
				if (ch == '[') { // end of the sdb_addr 
					token_type = token_type_none;
					buffer[buffer_idx++] = 0;
					sscanf(buffer,"%x",&result->sdb_addr);
				} else {
					buffer[buffer_idx++] = ch;
				}
 			break;
 			case token_type_sdb_record:
 				if (num_open_braces == 1 && ch == '}') { // end of the sdb_record
 					token_type = token_type_none;
 					buffer[buffer_idx++] = ch;
 					buffer[buffer_idx++] = 0;
 					switch(buffer[2]) { // first letter of "msi" or "device" etc. is at buffer_idx=2
 						case 'm': // msi
 							result->records[result->num_records].msi = parse_sdb_msi(buffer);
 							result->records[result->num_records].msi.sdb_component.addr_first += base_addr;
 							result->records[result->num_records].msi.sdb_component.addr_last  += base_addr;
 							++result->num_records;
 						break;
 						case 'd': // device
 							result->records[result->num_records].device = parse_sdb_device(buffer);
 							result->records[result->num_records].device.sdb_component.addr_first += base_addr;
 							result->records[result->num_records].device.sdb_component.addr_last  += base_addr;
 							++result->num_records;
 						break;
 						case 'b': // bridge
 						{
 							result->records[result->num_records].bridge = parse_sdb_bridge(buffer);
 							uint32_t sdb_child  = result->records[result->num_records].bridge.sdb_child;
 							uint32_t addr_first = result->records[result->num_records].bridge.sdb_component.addr_first;
 							uint32_t child_sdb_addr = sdb_child - addr_first;
 							printf("looking for %s_%08X.h\n", filename_prefix, child_sdb_addr);
 							result->records[result->num_records].bridge.sdb_child = (uint64_t) sdb_static_crossbar_from_file_real(filename_prefix, child_sdb_addr, base_addr+addr_first);
 							result->records[result->num_records].bridge.sdb_component.addr_first += base_addr;
 							result->records[result->num_records].bridge.sdb_component.addr_last  += base_addr;
 							++result->num_records;
 						}
 						break;
 					}
				} else {
					buffer[buffer_idx++] = ch;
				}
 			break;
		}

		if (num_open_braces == 0 && result->num_records > 0) {
			break;
		}
	}	
	return result;
}
struct sdb_static_crossbar* sdb_static_crossbar_from_file(const char* filename_prefix, uint32_t sdb_addr) {
	return sdb_static_crossbar_from_file_real(filename_prefix, sdb_addr, 0);
}

void sdb_static_crossbar_free(struct sdb_static_crossbar* crossbar) {
	if (crossbar == NULL) return;
	// look for nested crossbars and free them recursively
	for (int i = 0; i < crossbar->num_records; ++i) {
		if (crossbar->records[i].device.sdb_component.product.record_type == 0x02) {
			// bridge found, free underlying crossbar
			struct sdb_static_crossbar* child = (struct sdb_static_crossbar*)crossbar->records[i].bridge.sdb_child;
			sdb_static_crossbar_free(child);			
		}
	}
	free(crossbar);
}

eb_status_t sdb_static_find_by_identity(struct sdb_static_crossbar *crossbar, uint64_t vendor_id, uint32_t device_id, struct sdb_device *output, int *devices) {
	int capacity = *devices;
	*devices = 0;
	for (int i = 0; i < crossbar->num_records; ++i) {
		if (crossbar->records[i].device.sdb_component.product.vendor_id == vendor_id &&
			crossbar->records[i].device.sdb_component.product.device_id == device_id &&
			crossbar->records[i].device.sdb_component.product.record_type == 0x01) {
			// correct device found
			if (capacity > 0) {
				*output = crossbar->records[i].device;
				// print_sdb_device(crossbar->records[i].device);
				++output;
				--capacity;
				++*devices;
			} else {
				printf("sdb_static_find_by_identity: out of capacity\n");
			}
		} else if (crossbar->records[i].device.sdb_component.product.record_type == 0x02) {
			// bridge found
			struct sdb_static_crossbar * child = (struct sdb_static_crossbar*)crossbar->records[i].bridge.sdb_child;
			// call the function with the output pointer moved forward by the number of already found devices
			int capacity_recursive = capacity;
			sdb_static_find_by_identity(child, vendor_id, device_id, output, &capacity_recursive);
			// capacity contains number of devices found after function call
			*devices += capacity_recursive;
		}
	}
	return EB_OK;
}

eb_status_t sdb_static_find_by_identity_msi(struct sdb_static_crossbar *crossbar, uint64_t vendor_id, uint32_t device_id, struct sdb_device *output, eb_address_t* output_msi_first, eb_address_t* output_msi_last, int *devices) {
	int capacity = *devices;
	eb_address_t msi_first = 0, msi_last = 0;
	sdb_static_find_by_identity(crossbar, vendor_id, device_id, output, devices);
	// in order to find msi_first and msi_last, just take sdb_componnen.addr_fist and 
	// sdb_component.addr_last from the first .msi record found... don't know if that is always correct...
	for (int i = 0; i < crossbar->num_records; ++i) {
		if (crossbar->records[i].device.sdb_component.product.record_type == 0x03) {
			// correct device found
			msi_first = crossbar->records[i].msi.sdb_component.addr_first;
			msi_last  = crossbar->records[i].msi.sdb_component.addr_last;
			break;
		}
	}
	for (int i = 0; i < capacity && i < *devices; ++i ) {
		output_msi_first[i] = msi_first;
		output_msi_last[i] = msi_last;
	}
	return EB_OK;
}