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
    components GlcdC;
    components DatabaseC;
    components new TimerMilliC() as Scroll_Timer;
    components new TimerMilliC() as Volume_Timer;
    components new TimerMilliC() as DateTime_Timer;

    RS.PS2 -> PS2C;
    RS.Boot -> MainC.Boot;
    RS.BufferedLcd -> BufferedLcdC;
    RS.ReadVolume -> VolumeAdcC.readVolume;

    RS.FMClick -> FMClickC;
    RS.FMClick_init -> FMClickC;

    RS.Glcd ->GlcdC;
    RS.Scroll_Timer -> Scroll_Timer;
    RS.Volume_Timer -> Volume_Timer;
    RS.DateTime_Timer -> DateTime_Timer;

    RS.Database -> DatabaseC;

}
