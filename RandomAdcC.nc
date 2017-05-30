
configuration RandomAdcC{
    provides interface Read<uint16_t>;
}

implementation{ 
    components new AdcReadClientC() as ADC;
    components RandomAdcConfigC;
    components MainC;
    components VolumeAdcP;
    components HplAtm1280GeneralIOC;
    
    Read = ADC;
    
    ADC.ResourceConfigure -> RandomAdcConfigC;
    ADC.Atm1280AdcConfig -> RandomAdcConfigC;
    
    VolumeAdcP.Boot -> MainC.Boot;
    VolumeAdcP.PortK0 -> HplAtm1280GeneralIOC.PortK0;
    VolumeAdcP.PortK1 -> HplAtm1280GeneralIOC.PortK1;
}