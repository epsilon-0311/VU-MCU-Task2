
#include "FMClick.h"

#define device_address 0x10
#define register_POWERCFG 0x02
#define register_CHANNEL 0x03
#define register_SYSCONFIG1 0x04
#define register_SYSCONFIG2 0x05
#define register_SYSCONFIG3 0x06
#define register_TEST1 0x07
#define register_STATUS_RSSI 0x0A

module FMClickP{
    uses interface I2CPacket<TI2CBasicAddr> as I2C;
    uses interface Resource as I2C_Resource;
    uses interface GeneralIO as Interrupt_Pin;
    uses interface GeneralIO as Reset_Pin;
    uses interface GeneralIO as I2C_SDA;
    uses interface HplAtm128Interrupt as External_Interrupt;
    uses interface Timer<TMilli> as Timer;

    uses interface GeneralIOPort as debug_out;

    provides interface FMClick;
}

implementation
{
    void task get_data_from_chip_task();
    void task write_conf_to_chip_task();
    void task send_initial_conf_task();
    void task rds_task();

    conf_registers_t conf_registers;
    data_registers_t data_registers;

    FMClick_init_state_t init_state;
    FMClick_operation_t current_operation;

    uint8_t buffer[32];

    bool i2c_in_use;

    bool debug_read;

    command void FMClick.init(void)
    {
        error_t check;
        call debug_out.makeOutput(0xFF);

        call Interrupt_Pin.makeInput();
        call Reset_Pin.makeOutput();
        call I2C_SDA.makeOutput();

        call Interrupt_Pin.set();
        call I2C_SDA.clr(); // SDA musst be low befor rising edge of RST
        call Reset_Pin.clr();

        atomic
        {
            current_operation = FM_CLICK_IDLE;
            i2c_in_use=FALSE;
            current_operation = FM_CLICK_IDLE;
        }

        check = call I2C_Resource.request();
        if(check != SUCCESS)
        {
          printf("Radio failed");
        }

        call External_Interrupt.edge(FALSE);
        call External_Interrupt.enable();

    }

    command error_t FMClick.tune(uint16_t channel)
    {
        atomic
        {

            if(current_operation != FM_CLICK_IDLE)
            {
                return FAIL;
            }
            else
            {
                current_operation = FM_CLICK_TUNE;
            }

            conf_registers.channel.CHANNEL_L = channel&0xFF;
            conf_registers.channel.CHANNEL_H = (channel >> 8) & 0x03;
            conf_registers.channel.TUNE = 1;
        }

        post write_conf_to_chip_task();

        return SUCCESS;

    }

    command error_t FMClick.seek(bool up)
    {
        atomic
        {
            if(current_operation != FM_CLICK_IDLE)
            {
                return FAIL;
            }
            else
            {
                current_operation = FM_CLICK_SEEK;
            }

            conf_registers.power_conf.SEEK = 1;
            conf_registers.power_conf.SEEKUP = up;

            post write_conf_to_chip_task();
        }

        return SUCCESS;
    }

    command uint16_t FMClick.getChannel(void)
    {

        uint16_t channel = conf_registers.channel.CHANNEL_H;
        channel <<= 8;
        channel |= conf_registers.channel.CHANNEL_L;

        return channel;
    }

    command error_t FMClick.setVolume(uint8_t volume)
    {
        if(current_operation != FM_CLICK_IDLE)
        {
            return FAIL;
        }

        conf_registers.system_configuration_2.VOLUME = volume;
        post write_conf_to_chip_task();

        return SUCCESS;
    }

    command error_t FMClick.receiveRDS(bool enable)
    {
        if(current_operation != FM_CLICK_IDLE)
        {
            return FAIL;
        }

        conf_registers.system_configuration_1.RDS = enable;

        post write_conf_to_chip_task();
        return SUCCESS;
    }

    // send config
    void task write_conf_to_chip_task()
    {
        bool i2c_in_use_temp;

        atomic
        {
            i2c_in_use_temp=i2c_in_use;
        }

        if(!i2c_in_use_temp)
        {
            atomic
            {
                i2c_in_use=TRUE;
            }
            // 11 bytes are enough, low byte of test1 shouldn't be touched
            call I2C.write(I2C_START | I2C_STOP, device_address ,10, conf_registers.data_bytes);

        }
        else
        {
            post write_conf_to_chip_task();
        }
    }

    void task send_initial_conf_task()
    {
        bool i2c_in_use_temp;

        atomic
        {
            i2c_in_use_temp=i2c_in_use;
        }

        if(!i2c_in_use_temp)
        {
            atomic
            {
                i2c_in_use=TRUE;
            }
            // 11 bytes are enough, low byte of test1 shouldn't be touched
            call I2C.write(I2C_START, device_address ,12, conf_registers.data_bytes);

        }
        else
        {
            post write_conf_to_chip_task();
        }
    }

    // send initial config
    void task get_data_from_chip_task()
    {
        error_t check;
        //read the status and rds data registers
        check = call I2C.read(I2C_START | I2C_STOP , device_address, 12, buffer);	//NACK should be sent
        if(check != SUCCESS)
        {
  	         post get_data_from_chip_task();
        }
    }

    void task get_registers_task()
    {
        error_t check;

        //read all register
        check = call I2C.read(I2C_START | I2C_STOP , device_address, 32, buffer);	//NACK should be sent
        if(check != SUCCESS)
        {
             post get_registers_task();
        }
    }

    void task rds_task()
    {

    }

    event void I2C_Resource.granted()
    {
        call Timer.startOneShot(1);
    }

    async event void I2C.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data)
    {

        FMClick_init_state_t init_state_temp;
        FMClick_operation_t current_operation_temp;

        atomic
        {
            init_state_temp = init_state;
            current_operation_temp = current_operation;
            i2c_in_use=FALSE;
        }

        if(init_state_temp == FM_CLICK_SET_OSC || init_state_temp == FM_CLICK_WAIT_POWER_UP)
        {
            call Timer.startOneShot(1);
        }
        else if(current_operation_temp == FM_CLICK_WAIT_WRITE_FINISH)
        {
            atomic
            {
                current_operation = FM_CLICK_IDLE;
            }
        }
    }

    async event void I2C.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data)
    {
        FMClick_operation_t current_operation_temp;
        FMClick_init_state_t init_state_temp;

        atomic
        {
            current_operation_temp = current_operation;
            init_state_temp = init_state;
            i2c_in_use=FALSE;
        }

        if( init_state_temp == FM_CLICK_READ_REGISTERS)
        {

            uint8_t i =0;
            uint8_t offset = 16;

            for(i=0; i<12; i++)
            {
                conf_registers.data_bytes[i] = data[i+offset];
            }

            atomic
            {
                init_state = FM_CLICK_SET_OSC;
            }

            conf_registers.test1.XOSCEN = 1;

            post send_initial_conf_task();
        }
        else if(length==12)
        {
            uint8_t i =0;

            for(i=0; i<12; i++)
            {
                data_registers.data_bytes[i] = data[i];
            }

            switch(current_operation_temp)
            {
                case FM_CLICK_IDLE: // nothing to do
                case FM_CLICK_WAIT_WRITE_FINISH:
                    break;
                case FM_CLICK_SEEK:
                    if(data_registers.rssi.STC)
                    {

                        conf_registers.channel.CHANNEL_H = data_registers.read_channel.CHANNEL_H;
                        conf_registers.channel.CHANNEL_L = data_registers.read_channel.CHANNEL_L;

                        conf_registers.power_conf.SEEK=0;

                        post write_conf_to_chip_task();

                        atomic
                        {
                            current_operation = FM_CLICK_WAIT_WRITE_FINISH;
                        }
                    }
                    break;
                case FM_CLICK_TUNE:
                    if(data_registers.rssi.STC)
                    {
                        conf_registers.channel.TUNE=0;
                        post write_conf_to_chip_task();

                        atomic
                        {
                            current_operation = FM_CLICK_WAIT_WRITE_FINISH;
                        }
                    }
                    break;
            }

            if(data_registers.rssi.RDSR)
            {
                post rds_task();
            }
        }

    }

    // there is new data to retrieve
    async event void External_Interrupt.fired()
    {
        FMClick_operation_t current_operation_temp;

        atomic
        {
            current_operation_temp = current_operation;
        }

        if(current_operation_temp != FM_CLICK_IDLE || conf_registers.system_configuration_1.RDS)
        {
            post get_data_from_chip_task();
        }
    }

    event void Timer.fired()
    {
        FMClick_init_state_t init_state_temp;

        atomic
        {
            init_state_temp = init_state;
        }

        switch(init_state_temp)
        {
            case FM_CLICK_RST_LOW:
                call Reset_Pin.set();
                init_state_temp=FM_CLICK_RST_HIGH;
                call Timer.startOneShot(1);
                break;
        	case FM_CLICK_RST_HIGH:
                init_state_temp= FM_CLICK_READ_REGISTERS;
                post get_registers_task();

                break;
            case FM_CLICK_READ_REGISTERS:

                break;
            case FM_CLICK_SET_OSC:

                init_state_temp=FM_CLICK_WAIT_POWER_UP;
                atomic
                {
                    // power configuration register
                    conf_registers.power_conf.ENABLE=1;
                    conf_registers.power_conf.DISABLE=0;
                    conf_registers.power_conf.DMUTE=1;
                }

                post write_conf_to_chip_task();

                break;
            case FM_CLICK_WAIT_POWER_UP:
                init_state_temp=FM_CLICK_INIT_DONE;
                call Timer.startOneShot(110);
                break;
            case FM_CLICK_INIT_DONE:
                atomic
                {
                    conf_registers.power_conf.SKMODE=0;

                    conf_registers.system_configuration_1.GPIO2=1; // enable interrupt pin
                    conf_registers.system_configuration_1.DE=1; // set De-emphasis for Europe
                    conf_registers.system_configuration_1.RDSIEN = 1; // end RDS interrupt
                    conf_registers.system_configuration_1.STCIEN = 1; // enable Tune/Seek interrupt

                    conf_registers.system_configuration_2.SPACE  = 1; // set spacing for Europe

                    // configuration for seeking channels, see AN248
                    // http://read.pudn.com/downloads159/doc/710424/AN284Rev0_1.pdf
                    conf_registers.system_configuration_2.SEEKTH = 0x19;
                    conf_registers.system_configuration_3.SKSNR = 0x4;
                    conf_registers.system_configuration_3.SKCNT = 0x8;

                    // implementation temp 
                    conf_registers.system_configuration_2.VOLUME = 0xF;
                    conf_registers.system_configuration_1.RDS = 1; // enable RDS


                }
                post write_conf_to_chip_task();
                break;
        }

        atomic
        {
            init_state = init_state_temp;
        }
    }
}
