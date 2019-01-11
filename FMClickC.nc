
configuration FMClickC{
    provides interface FMClick;
    provides interface Init;
}
implementation{

    components FMClickP;
    components new Atm128I2CMasterC() as I2C;
    components HplAtm1280GeneralIOC;
    components HplAtm128InterruptC;
    components new TimerMilliC() as Timer;

    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTH, (uint16_t)&DDRH, (uint16_t)&PINH) as Port1;
    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTJ, (uint16_t)&DDRJ, (uint16_t)&PINJ) as Port2;
    components new HplAtm1280GeneralIOFastPortP((uint16_t)&PORTL, (uint16_t)&DDRL, (uint16_t)&PINL) as Port3;

    FMClick = FMClickP;
    Init = FMClickP;

    FMClickP.I2C -> I2C.I2CPacket;
    FMClickP.I2C_Resource -> I2C.Resource;
    FMClickP.Interrupt_Pin -> HplAtm1280GeneralIOC.PortD3;
    FMClickP.Reset_Pin -> HplAtm1280GeneralIOC.PortD4;
    FMClickP.I2C_SDA -> HplAtm1280GeneralIOC.PortD1;
    FMClickP.External_Interrupt -> HplAtm128InterruptC.Int3;
    FMClickP.Timer ->Timer;

    FMClickP.debug_out -> Port1;
    FMClickP.debug_out_2 -> Port2;
    FMClickP.debug_out_3 -> Port3;
}
