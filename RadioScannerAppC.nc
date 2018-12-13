#include <debug.h>
configuration RadioScannerAppC {

}

implementation {
	components MainC;
    components RadioScannerC as RS;
    components PS2C;
    components BufferedLcdC;
    components VolumeAdcC;
    components FMClickC;

    RS.PS2 -> PS2C;
    RS.Boot -> MainC.Boot;
    RS.BufferedLcd -> BufferedLcdC;
    RS.ReadVolume -> VolumeAdcC.readVolume;
    RS.FMClick -> FMClickC;
}
