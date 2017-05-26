#include <debug.h>
configuration LunarLanderAppC {

}

implementation {
    components MainC;
    components LunarLanderC as LL;
    components PS2C;
    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTA, (uint16_t)&DDRA, (uint16_t)&PINA) as PortA;
    components BufferedLcdC;
    
    LL.PS2 -> PS2C;
    LL.CharPort -> PortA.GeneralIOPort;
    LL.Boot -> MainC.Boot;
    LL.BufferedLcd -> BufferedLcdC;
}
