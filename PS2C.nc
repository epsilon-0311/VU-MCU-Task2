configuration PS2C{
    provides interface PS2;
}
implementation{
  
    components MainC;
    components PS2P;
    components HplAtmegaPinChange2C;
    components HplAtm1280GeneralIOC;
    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTA, (uint16_t)&DDRA, (uint16_t)&PINA) as PortA;
    PS2 = PS2P;
    
    PS2P.Boot -> MainC.Boot;
    PS2P.HplAtmegaPinChange -> HplAtmegaPinChange2C;
    PS2P.Clock -> HplAtm1280GeneralIOC.PortK7;
    PS2P.Data -> HplAtm1280GeneralIOC.PortK6;
    PS2P.CharPort -> PortA.GeneralIOPort;
}