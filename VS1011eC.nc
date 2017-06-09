configuration VS1011eC{
    provides interface MP3;
}
implementation{
    components VS1011eP;
    components HplVS1011eC;
    components MainC;
    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTB, (uint16_t)&DDRB, (uint16_t)&PINB) as PortB;
    
    MP3 = VS1011eP;
    VS1011eP.HplVS1011e -> HplVS1011eC;
    VS1011eP.Boot -> MainC.Boot;
    VS1011eP.CharPort -> PortB.GeneralIOPort;
}