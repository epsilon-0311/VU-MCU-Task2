#include <debug.h>
configuration RadioScannerAppC {

}

implementation {
	components MainC;
    components RadioScanner as RS;
    components PS2C;
    components BufferedLcdC;
    components VolumeAdcC;

    RS.PS2 -> PS2C;
    RS.Boot -> MainC.Boot;
    RS.BufferedLcd -> BufferedLcdC;
    RS.ReadVolume -> VolumeAdcC.readVolume;

}