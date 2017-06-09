#include <debug.h>
configuration LunarLanderAppC {

}

implementation {
    components MainC;
    components LunarLanderC as LL;
    components PS2C;
    components BufferedLcdC;
    components ScoreC;
    components VolumeAdcC;
    components RandomC;
    components TouchScreenC;
    components TerrainGeneratorC;
    components VS1011eC;
    
    //DEBUG
    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTA, (uint16_t)&DDRA, (uint16_t)&PINA) as PortA;
    components new TimerMilliC() as Timer;
    
    LL.PS2 -> PS2C;
    LL.CharPort -> PortA.GeneralIOPort;
    LL.Boot -> MainC.Boot;
    LL.BufferedLcd -> BufferedLcdC;
    LL.Score -> ScoreC;
    LL.ReadVolume -> VolumeAdcC.readVolume;
    LL.initRandom -> RandomC.ParamInit;
    LL.GLCD -> TouchScreenC.Glcd;
    LL.TouchScreen -> TouchScreenC.TouchScreen;
    LL.TG -> TerrainGeneratorC;
    LL.MP3 -> VS1011eC;
    
    //debug
    LL.Random -> RandomC.Random;
    LL.DebugTimer -> Timer;
}
