
configuration VolumeAdcC{
    provides interface Read<uint16_t> as readVolume;
}

implementation{
    components MainC;
    components new AdcReadClientC() as volumeADC;
    components VolumeAdcConfigC;
    components HplAtm1280GeneralIOC;

    readVolume = volumeADC.Read;

    volumeADC.ResourceConfigure -> VolumeAdcConfigC;
    volumeADC.Atm1280AdcConfig -> VolumeAdcConfigC;

    VolumeAdcConfigC.PortF0 -> HplAtm1280GeneralIOC.PortF0;

}
