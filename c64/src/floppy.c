#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <cbm.h>
#include <errno.h>

const char* blockPointer0 = "b-p: 5 0";
char buf[16];

uint8_t readBlock(uint8_t device, uint8_t track, uint8_t sector, uint8_t* data)
{
	uint8_t err;

	// open command and data files
	err = cbm_open(2, device, 15, "");
	if (err) goto end;
	err = cbm_open(5, device, 5, "#");
	if (err) goto end;

	// load data from disk to floppy RAM
	sprintf(buf, "u1: 5 0 %i %i", track, sector);
	if (cbm_write(2, buf, strlen(buf)) < 0) {
		err = _oserror;
		goto end;
	}

	// set block pointer to 0
	if (cbm_write(2, blockPointer0, strlen(blockPointer0)) < 0) {
		err = _oserror;
		goto end;
	}

	// read floppy RAM
	if (cbm_read(5, data, 256) < 0) {
		err = _oserror;
	}

	// close files and return error status
end:	cbm_close(5);
	cbm_close(2);
	return err;
}

uint8_t writeBlock(uint8_t device, uint8_t track, uint8_t sector, uint8_t* data)
{
	uint8_t err;

	// open command and data files
	err = cbm_open(2, device, 15, "");
	if (err) goto end;
	err = cbm_open(5, device, 5, "#");
	if (err) goto end;

	// set block pointer to 0
	if (cbm_write(2, blockPointer0, strlen(blockPointer0)) < 0) {
		err = _oserror;
		goto end;
	}

	// write data to floppy RAM
	if (cbm_write(5, data, 256) < 0) {
		err = _oserror;
		goto end;
	}

	// write data in floppy RAM to disk
	sprintf(buf, "u2: 5 0 %i %i", track, sector);
	if (cbm_write(2, buf, strlen(buf)) < 0) {
		err = _oserror;
	}

	// close files and return error status
end:	cbm_close(5);
	cbm_close(2);
	return err;
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
