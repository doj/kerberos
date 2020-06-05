#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <conio.h>
#include <stdlib.h>
#include <cbm.h>

#include "util.h"
#include "midi.h"
#include "regs.h"
#include "menu.h"
#include "midi_commands.h"
#include "kerberos.h"
#include "config.h"

void waitVsync(void);

static void __fastcall__
incrementDiskNumber(uint8_t id)
{
	uint8_t number = getConfigValue(id);
	number++;
	if (number == 12) number = 8;
	setConfigValue(id, number);
}

void configureSettings(void)
{
	uint8_t i;
	uint8_t slot;
	char slotName;
	for (;;) {
		slotName = getConfigValue(KERBEROS_CONFIG_AUTOSTART_SLOT);
		if (slotName > 9) {
			slotName = slotName - 10 + 'A';
		} else {
			slotName += '0';
		}
		showTitle("Configure Settings");
		cprintf("I: Mirror MIDI  in to MIDI thru: %s\r\n"
			"O: Mirror MIDI out to MIDI thru: %s\r\n"
			"\r\n"
			"1: Cartridge disk 1 drive number: %i\r\n"
			"2: Cartridge disk 2 drive number: %i\r\n"
			"\r\n"
			"A: Autostart slot (0=off): %c\r\n"
			"T: always listen on MIDI for transfer: %i\r\n"
			"\r\n"
			"S: Save and back\r\n"
			"\x1f: Back without save\r\n"
			, getConfigValue(KERBEROS_CONFIG_MIDI_IN_THRU) ? "on" : "off"
			, getConfigValue(KERBEROS_CONFIG_MIDI_OUT_THRU) ? "on" : "off"
			, getConfigValue(KERBEROS_CONFIG_DRIVE_1)
			, getConfigValue(KERBEROS_CONFIG_DRIVE_2)
			, slotName
			, getConfigValue(KERBEROS_CONFIG_TRANSFER_ALWAYS_ENABLED)
			);
		enableInterrupts();
		while (!kbhit());
		disableInterrupts();
		switch (cgetc()) {
			case 'i':
				setConfigValue(KERBEROS_CONFIG_MIDI_IN_THRU, !getConfigValue(KERBEROS_CONFIG_MIDI_IN_THRU));
				break;
			case 'o':
				setConfigValue(KERBEROS_CONFIG_MIDI_OUT_THRU, !getConfigValue(KERBEROS_CONFIG_MIDI_OUT_THRU));
				break;
			case '1':
				incrementDiskNumber(KERBEROS_CONFIG_DRIVE_1);
				break;
			case '2':
				incrementDiskNumber(KERBEROS_CONFIG_DRIVE_2);
				break;
			case 'a':
				slot = getConfigValue(KERBEROS_CONFIG_AUTOSTART_SLOT);
				slot++;
				if (slot == 26) slot = 0;
				setConfigValue(KERBEROS_CONFIG_AUTOSTART_SLOT, slot);
				break;
			case '0':
				setConfigValue(KERBEROS_CONFIG_AUTOSTART_SLOT, 0);
				break;
            case 't':
                setConfigValue(KERBEROS_CONFIG_TRANSFER_ALWAYS_ENABLED, !getConfigValue(KERBEROS_CONFIG_TRANSFER_ALWAYS_ENABLED));
                break;
			case 's':
				if (getConfigValue(KERBEROS_CONFIG_DRIVE_1) == getConfigValue(KERBEROS_CONFIG_DRIVE_2)) {
					cputs("\r\nPlease choose different drive numbers\r\n"
					      "for the cartridge disks\r\n\r\n");
					anyKey();
					break;
				}
				saveConfigs();
				cputs("\r\nsettings saved!");
				for (i = 0; i < 90; i++) waitVsync();
				return;
			case LEFT_ARROW_KEY:
				loadConfigs();
				return;
		}
	}
}

//
// Editor modelines  -  https://www.wireshark.org/tools/modelines.html
//
// Local variables:
// c-basic-offset: 4
// tab-width: 4
// indent-tabs-mode: nil
// eval: (c-set-offset 'case-label '+)
// End:
//
// vi: set shiftwidth=4 tabstop=4 expandtab:
// :indentSize=4:tabSize=4:noTabs=true:
//
