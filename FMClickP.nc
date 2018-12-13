
#include "FMClick.h"

#define device_address 0x10
#define register_POWERCFG 0x02
#define register_CHANNEL 0x03
#define register_SYSCONFIG1 0x04
#define register_SYSCONFIG2 0x05
#define register_SYSCONFIG3 0x06


module FMClickP{
    uses interface I2CPacket<TI2CBasicAddr> as I2C;
    uses interface Resource as I2C_Resource;
    uses interface GeneralIO as Interrupt_Pin;
    uses interface HplAtm128Interrupt as External_Interrupt;

    provides interface FMClick;
}

implementation
{

    sys_conf_1_t    reg_system_configuration_1;
    sys_conf_2_t    reg_system_configuration_2;
    sys_conf_3_t    reg_system_configuration_3;
    channel_t       reg_channel;
    power_conf_t    reg_power_configuration;

    command void FMClick.init(void)
    {
        error_t check;

        check = call I2C_Resource.request();
        if(check != SUCCESS)
        {
          printf("Radio failed");
        }

        call External_Interrupt.edge(FALSE);
        call External_Interrupt.enable();

        // set initial value for registers
        // system configuration register 1
        reg_system_configuration_1.data_bytes[0]=0;
        reg_system_configuration_1.data_bytes[1]=0;
        reg_system_configuration_1.GPIO2=1;
        reg_system_configuration_1.DE=1;


        // system configuration register 2
        reg_system_configuration_2.data_bytes[0]=0;
        reg_system_configuration_2.data_bytes[1]=0;
        reg_system_configuration_2.SPACE=1;

        // system configuration register 3
        reg_system_configuration_3.data_bytes[0]=0;
        reg_system_configuration_3.data_bytes[1]=0;

        // channel register
        reg_channel.data_bytes[0]=0;
        reg_channel.data_bytes[1]=0;

        // power configuration register
        reg_power_configuration.data_bytes[0]=0;
        reg_power_configuration.data_bytes[1]=0;
    }

    command error_t FMClick.tune(uint16_t channel)
    {

        uint8_t data[3];

        reg_channel.CHANNEL = channel;

        data[0] = register_CHANNEL;
        data[1] = reg_channel.data_bytes[0];
        data[2] = reg_channel.data_bytes[1];

        call I2C.write(I2C_START, device_address , 3, data);
        return 0;
        return 0;
    }

    command error_t FMClick.seek(bool up)
    {
        uint8_t data[3];

        reg_power_configuration.SEEK = 1;
        reg_power_configuration.SEEKUP = up;

        data[0] = register_POWERCFG;
        data[1] = reg_power_configuration.data_bytes[0];
        data[2] = reg_power_configuration.data_bytes[1];

        call I2C.write(I2C_START, device_address , 3, data);
        return 0;
    }

    command uint16_t FMClick.getChannel(void)
    {
        return reg_channel.CHANNEL;
    }

    command error_t FMClick.setVolume(uint8_t volume)
    {
        uint8_t data[3];

        reg_system_configuration_2.VOLUME = volume;

        data[0] = register_SYSCONFIG2;
        data[1] = reg_system_configuration_2.data_bytes[0];
        data[2] = reg_system_configuration_2.data_bytes[1];

        call I2C.write(I2C_START, device_address , 3, data);
        return 0;
    }

    command error_t FMClick.receiveRDS(bool enable)
    {
        uint8_t data[3];

        reg_system_configuration_1.RDS = enable;

        data[0] = register_SYSCONFIG1;
        data[1] = reg_system_configuration_1.data_bytes[0];
        data[2] = reg_system_configuration_1.data_bytes[1];

        call I2C.write(I2C_START, device_address , 3, data);
        return 0;
    }

    event void I2C_Resource.granted()
    {

    }

    async event void I2C.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data)
    {

    }

    async event void I2C.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data)
    {

    }

    async event void External_Interrupt.fired()
    {

    }
}
