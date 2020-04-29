#include "floppy.h"
#include <stdio.h>
#include <cbm.h>
#include <errno.h>

static const char* blockPointer0 = "b-p: 5 0";
#define blockPointer0_len 8
static char buf[16];
static char fd2 = -1;
static char fd5 = -1;

uint8_t
closeFileDescriptors(uint8_t err)
{
	cbm_close(2);
	cbm_close(5);
	fd2 = -1;
	fd5 = -1;
	return err;
}

static uint8_t __fastcall__
checkOpen(uint8_t device)
{
	uint8_t err = 0;
	if (fd2 != device) {
		if (fd2 > 0) {
			cbm_close(2);
			fd2 = -1;
		}
		err = cbm_open(2, device, 15, "");
		if (err) {
			return closeFileDescriptors(err);
		}
		fd2 = device;
	}
	if (fd5 != device) {
		if (fd5 > 0) {
			cbm_close(5);
			fd5 = -1;
		}
		err = cbm_open(5, device, 5, "#");
		if (err) {
			return closeFileDescriptors(err);
		}
		fd5 = device;
	}
	return 0;
}

uint8_t
readBlock(uint8_t device, uint8_t track, uint8_t sector, uint8_t* data)
{
	int len;
	// open command and data files
	uint8_t err = checkOpen(device);
	if (err) {
		return closeFileDescriptors(err);
	}

	// load data from disk to floppy RAM
	len = sprintf(buf, "u1: 5 0 %i %i", track, sector);
	if (cbm_write(2, buf, len) < 0) {
		return closeFileDescriptors(_oserror);
	}

	// set block pointer to 0
	if (cbm_write(2, blockPointer0, blockPointer0_len) < 0) {
		return closeFileDescriptors(_oserror);
	}

	// read floppy RAM
	if (cbm_read(5, data, 256) < 0) {
		return closeFileDescriptors(_oserror);
	}

	return 0;
}

uint8_t
writeBlock(uint8_t device, uint8_t track, uint8_t sector, uint8_t* data)
{
	int len;
	// open command and data files
	uint8_t err = checkOpen(device);
	if (err) {
		return closeFileDescriptors(err);
	}

	// set block pointer to 0
	if (cbm_write(2, blockPointer0, blockPointer0_len) < 0) {
		return closeFileDescriptors(_oserror);
	}

	// write data to floppy RAM
	if (cbm_write(5, data, 256) < 0) {
		return closeFileDescriptors(_oserror);
	}

	// write data in floppy RAM to disk
	len = sprintf(buf, "u2: 5 0 %i %i", track, sector);
	if (cbm_write(2, buf, len) < 0) {
		return closeFileDescriptors(_oserror);
	}

	return 0;
}

//
// Editor modelines  -  https://www.wireshark.org/tools/modelines.html
//
// Local variables:
// c-basic-offset: 8
// tab-width: 8
// indent-tabs-mode: t
// eval: (c-set-offset 'case-label '+)
// End:
//
// vi: set shiftwidth=8 tabstop=8 expandtab:
// :indentSize=8:tabSize=8:noTabs=false:
//
