#define UQ_SHARED_RESOURCE   "Shared.Resource.ADC"

configuration VolumeAdcC{
    provides interface Read<uint16_t>;
}

implementation{ 
    components new AdcReadClientC() as ADC2;
    components VolumeAdcP;
    components new RoundRobinArbiterC(UQ_SHARED_RESOURCE) as Arbiter;
    
    Read = ADC2;
    
    ADC2.Atm1280AdcConfig = VolumeAdcP;
    ADC2.ResourceConfigure = Arbiter;
    
}