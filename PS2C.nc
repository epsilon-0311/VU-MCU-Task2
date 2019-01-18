configuration PS2C{
    provides interface PS2;
}
implementation{

    components PS2P;
    components HplAtmegaPinChange2C;
    components HplAtm1280GeneralIOC;
    components new TimerMilliC() as Timeout_Timer;

    PS2 = PS2P;

    PS2P.HplAtmegaPinChange -> HplAtmegaPinChange2C;
    PS2P.Clock -> HplAtm1280GeneralIOC.PortK7;
    PS2P.Data -> HplAtm1280GeneralIOC.PortK6;
    PS2P.Timeout_Timer -> Timeout_Timer;
    
}
