
configuration VolumeAdcC{
    provides interface Read<uint16_t> as readVolume;
}

implementation{
    components new AdcReadClientC() as volumeADC;
    components VolumeAdcConfigP;
    components HplAtm1280GeneralIOC;

    readVolume = volumeADC.Read;

    volumeADC.ResourceConfigure -> VolumeAdcConfigP;
    volumeADC.Atm1280AdcConfig -> VolumeAdcConfigP;

    VolumeAdcConfigP.ADCPort -> HplAtm1280GeneralIOC.PortF0;

}
