
configuration FMClickC{
    provides interface FMClick;
}
implementation{

    components FMClickP;
    components new Atm128I2CMasterC() as I2C;
    components HplAtm1280GeneralIOC;
    components HplAtm128InterruptC;

    FMClick = FMClickP;

    FMClickP.I2C -> I2C.I2CPacket;
    FMClickP.I2C_Resource -> I2C.Resource;
    FMClickP.Interrupt_Pin -> HplAtm1280GeneralIOC.PortD3;
    FMClickP.External_Interrupt ->HplAtm128InterruptC.Int3;
}
