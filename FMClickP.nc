
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
    void task get_interrupt_data();
    void task rssi_status_task();
    void task i2c_write_task();

    conf_registers_t conf_registers;
    rssi_status_t   reg_rssi_status;

    FMClick_read_state_t read_state;
    FMClick_init_state_t init_state;

    uint8_t buffer[32];

    bool i2c_in_use;

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
            read_state = FM_CLICK_INIT;
            i2c_in_use=FALSE;
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
        static uint8_t counter=0;
        counter ++;

        conf_registers.channel.CHANNEL_L = channel&0xFF;
        conf_registers.channel.CHANNEL_H = (channel >> 8) & 0x03;

        post i2c_write_task();

        return 0;

    }

    command error_t FMClick.seek(bool up)
    {
        conf_registers.power_conf.SEEK = 1;
        conf_registers.power_conf.SEEKUP = up;
        conf_registers.power_conf.SKMODE=0;
        post i2c_write_task();

        return 0;
    }

    command uint16_t FMClick.getChannel(void)
    {

        uint16_t channel = conf_registers.channel.CHANNEL_H;
        channel <<= 8;
        channel |= conf_registers.channel.CHANNEL_L;

        call debug_out.clear(0xFF);
        call debug_out.set( conf_registers.channel.CHANNEL_L);
        return channel;
    }

    command error_t FMClick.setVolume(uint8_t volume)
    {
        conf_registers.system_configuration_2.VOLUME = volume;
        post i2c_write_task();

        return 0;
    }

    command error_t FMClick.receiveRDS(bool enable)
    {

        conf_registers.system_configuration_1.RDS = enable;

        post i2c_write_task();
        return 0;
    }

    // send config
    void task i2c_write_task()
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
            post i2c_write_task();
        }
    }

    void task send_initial()
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
            post i2c_write_task();
        }
    }

    // send initial config
    void task get_interrupt_data()
    {
        error_t check;
        //read the status register
        check = call I2C.read(I2C_START | I2C_STOP , device_address, 2, buffer);	//NACK should be sent
        if(check != SUCCESS)
        {
  	         post get_interrupt_data();
        }
        else
        {
            atomic
            {
                read_state = FM_CLICK_READ_RSSI;
            }
        }
    }

    void task rssi_status_task()
    {
        uint8_t length = 0;
        error_t check;

        atomic
        {
            if(reg_rssi_status.RDSR)
            {
                length = 12;
            }
            else if(reg_rssi_status.STC)
            {
                length = 4;
            }
        }

        //read the status register
        check = call I2C.read(I2C_START | I2C_STOP , device_address, length, buffer);	//NACK should be sent
        if(check != SUCCESS)
        {
  	         post rssi_status_task();
        }
        else
        {
            atomic
            {
                read_state = FM_CLICK_READ_RSSI;
            }
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

    event void I2C_Resource.granted()
    {
        call Timer.startOneShot(1);
    }

    async event void I2C.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data)
    {

        FMClick_init_state_t init_state_temp;

        atomic
        {
            init_state_temp = init_state;
            i2c_in_use=FALSE;
        }

        if(init_state_temp == FM_CLICK_SET_OSC || init_state_temp == FM_CLICK_WAIT_POWER_UP)
        {
            call Timer.startOneShot(1);
        }
    }

    async event void I2C.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data)
    {
        FMClick_read_state_t read_state_temp;
        FMClick_init_state_t init_state_temp;

        atomic
        {
            read_state_temp = read_state;
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

            post send_initial();
        }
        else
        {
            switch(read_state_temp)
            {
                case FM_CLICK_INIT:
                    break;
                case FM_CLICK_READ_RSSI:
                    reg_rssi_status.data_bytes[0] = data[0];
                    reg_rssi_status.data_bytes[1] = data[1];
                    post rssi_status_task();
                    break;
                case FM_CLICK_READ_SEEK:
                    break;
                case FM_CLICK_READ_RDS:
                    break;
                case FM_CLICK_READ_DONE:
                    break;
            }
        }

    }

    async event void External_Interrupt.fired()
    {
        /* post get_interrupt_data(); */
        static uint8_t counter =0;
        counter++;
        call debug_out.set(counter);
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

                    conf_registers.system_configuration_1.GPIO2=1; // enable interrupt pin
                    conf_registers.system_configuration_1.DE=1; // set De-emphasis for Europe
                    conf_registers.system_configuration_1.RDSIEN = 1; // end RDS interrupt
                    conf_registers.system_configuration_1.STCIEN = 1; // enable Tune/Seek interrupt
                    conf_registers.system_configuration_2.SPACE=1; // set spacing for Europe

                    conf_registers.system_configuration_2.VOLUME = 0xF;
                }

                post i2c_write_task();

                break;
            case FM_CLICK_WAIT_POWER_UP:
                init_state_temp=FM_CLICK_INIT_DONE;
                call Timer.startOneShot(110);
                break;
            case FM_CLICK_INIT_DONE:
                break;
        }

        atomic
        {
            init_state = init_state_temp;
        }
    }
}
