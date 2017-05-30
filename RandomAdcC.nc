
configuration RandomAdcC{
    provides interface Read<uint16_t> as readRandom;
}

implementation{ 
    components new AdcReadClientC() as randADC;
    components RandomAdcConfigC;
    components MainC;
    components RandomAdcP;
    components HplAtm1280GeneralIOC;
    
    readRandom = randADC.Read;
    
    randADC.ResourceConfigure -> RandomAdcConfigC;
    randADC.Atm1280AdcConfig -> RandomAdcConfigC;
    
    RandomAdcP.Boot -> MainC.Boot;
    RandomAdcP.PortK0 -> HplAtm1280GeneralIOC.PortK0;
    RandomAdcP.PortK1 -> HplAtm1280GeneralIOC.PortK1;
}