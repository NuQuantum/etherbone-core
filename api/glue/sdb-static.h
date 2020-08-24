/** @file sdb.c
 *  @brief Implement the SDB data structure on the local bus.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Use files generated during synthesis (or simulation) of gateware
 *  to allow access to SDB structures without connected hardware.
 *
 *  @author Michael Reese <m.reese@gsi.de>
 *
 *  @bug Is a dirty hack!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */
#ifndef SDB_STATIC_H
#define SDB_STATIC_H

#include "../etherbone.h"

#include <stdio.h>
#include <stdint.h>

struct sdb_static_crossbar {
  uint32_t sdb_addr;
  union sdb_record records[100];
  int num_records;
};

EB_PRIVATE struct sdb_static_crossbar* sdb_static_crossbar_from_file(const char* filename_prefix, uint32_t sdb_addr);
EB_PRIVATE eb_status_t sdb_static_find_by_identity(struct sdb_static_crossbar *crossbar, uint64_t vendor_id, uint32_t device_id, struct sdb_device *output, int *devices);
EB_PRIVATE eb_status_t sdb_static_find_by_identity_msi(struct sdb_static_crossbar *crossbar, uint64_t vendor_id, uint32_t device_id, struct sdb_device *output, eb_address_t* output_msi_first, eb_address_t* output_msi_last, int *devices);


EB_PRIVATE void print_sdb_device(struct sdb_device device);
EB_PRIVATE void print_sdb_msi(struct sdb_msi msi);
EB_PRIVATE void print_sdb_bridge(struct sdb_bridge bridge);

#endif
