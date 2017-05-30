
configuration VolumeAdcC{
    provides interface Read<uint16_t> as readVolume;
}

implementation{ 
    components MainC;
    components new AdcReadClientC() as volumeADC;
    components VolumeAdcConfigC;
    components VolumeAdcP;
    components HplAtm1280GeneralIOC;
    
    readVolume = volumeADC.Read;
    
    volumeADC.ResourceConfigure -> VolumeAdcConfigC;
    volumeADC.Atm1280AdcConfig -> VolumeAdcConfigC;
    
    VolumeAdcP.Boot -> MainC.Boot;
    VolumeAdcP.PortF2 -> HplAtm1280GeneralIOC.PortF2;
    
}