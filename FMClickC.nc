
configuration FMClickC{
    provides interface FMClick;
}
implementation{

    components FMClickP;
    components new Atm128I2CMasterC() as I2C;
    components HplAtm1280GeneralIOC;
    components HplAtm128InterruptC;
    components new TimerMilliC() as Timer;

    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTA, (uint16_t)&DDRA, (uint16_t)&PINA) as PortA;

    FMClick = FMClickP;

    FMClickP.I2C -> I2C.I2CPacket;
    FMClickP.I2C_Resource -> I2C.Resource;
    FMClickP.Interrupt_Pin -> HplAtm1280GeneralIOC.PortD3;
    FMClickP.Reset_Pin -> HplAtm1280GeneralIOC.PortD4;
    FMClickP.I2C_SDA -> HplAtm1280GeneralIOC.PortD1;
    FMClickP.External_Interrupt ->HplAtm128InterruptC.Int3;
    FMClickP.debug_out -> PortA;
    FMClickP.Timer ->Timer;
}
