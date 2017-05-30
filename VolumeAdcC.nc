
configuration VolumeAdcC{
    provides interface Read<uint16_t>;
}

implementation{ 
    components new AdcReadClientC() as ADC;
    components VolumeAdcConfigC;
    components MainC;
    components VolumeAdcP;
    components HplAtm1280GeneralIOC;
    
    Read = ADC;
    
    ADC.ResourceConfigure -> VolumeAdcConfigC;
    ADC.Atm1280AdcConfig -> VolumeAdcConfigC;
    
    VolumeAdcP.Boot -> MainC.Boot;
    VolumeAdcP.PortF2 -> HplAtm1280GeneralIOC.PortF2;
    
}