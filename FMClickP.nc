
#include <avr/pgmspace.h>
#include "FMClick.h"

#define DEVICE_ADDRESS 0x10

#define RDS_TYPE_TUNING 0x0
#define RDS_TYPE_RADIO_TEXT 0x2
#define RDS_TYPE_TIME 0x4

#define RDS_STATION_LENGTH 8
#define RDS_STATION_
#define RDS_TEXT_LENGTH_A 64
#define RDS_TEXT_LENGTH_B 32

#define START_YEAR 2018
#define MJD_1ST_JANUARY_2018 58119u
#define LEAP_YEAR_DISTANCE 4
#define NEXT_LEAP_YEAR 2
#define DAYS_IN_YEAR 365
#define DAYS_IN_LEAP_YEAR 366
#define MONTHS_IN_YEAR 12
#define LEAP_MONTH 1 // starting at 0
#define LEAP_MONTH_DAYS 29

#define TIME_OFFSET_MINUTES 30
#define MAX_MINUTES 59
#define MAX_HOUR 23

module FMClickP{
    uses interface I2CPacket<TI2CBasicAddr> as I2C;
    uses interface Resource as I2C_Resource;
    uses interface GeneralIO as Interrupt_Pin;
    uses interface GeneralIO as Reset_Pin;
    uses interface GeneralIO as I2C_SDA;
    uses interface HplAtm128Interrupt as External_Interrupt;
    uses interface Timer<TMilli> as Timer;

    uses interface GeneralIOPort as debug_out;
    uses interface GeneralIOPort as debug_out_2;
    uses interface GeneralIOPort as debug_out_3;

    provides interface FMClick;
}

implementation
{
    void task init_task();
    void task get_data_from_chip_task();
    void task write_conf_to_chip_task();
    void task send_initial_conf_task();
    void task rds_task();

    conf_registers_t conf_registers;
    data_registers_t data_registers;

    FMClick_init_state_t init_state;
    FMClick_operation_t current_operation;

    uint8_t buffer[32];
    uint8_t sync_state;

    bool i2c_in_use;
    bool debug_read;
    uint8_t const PROGMEM days_of_month[] = {31,28,31,30,31,30,31,31,30,31,30,31};
    char rds_radio_text[RDS_TEXT_LENGTH_A+1]; // +1 for nul char
    uint8_t current_rds_text_index;
    bool current_rds_text_type;
    char rds_radio_station[RDS_STATION_LENGTH+1]; // +1 for nul char
    uint8_t current_rds_station_index;

    command void FMClick.init(void)
    {
        error_t check;
        call debug_out.makeOutput(0xFF);
        call debug_out_2.makeOutput(0xFF);
        call debug_out_3.makeOutput(0xFF);

        call Interrupt_Pin.makeInput();
        call Reset_Pin.makeOutput();
        call I2C_SDA.makeOutput();

        call Interrupt_Pin.set();
        call I2C_SDA.clr(); // SDA musst be low befor rising edge of RST
        call Reset_Pin.clr();

        atomic
        {
            init_state = FM_CLICK_RST_LOW;
            i2c_in_use=FALSE;
            current_operation = FM_CLICK_IDLE;
        }
        current_rds_text_index=0;
        current_rds_station_index=0;
        current_rds_text_type=FALSE;
        rds_radio_station[0] = '\0';
        rds_radio_text[0] = '\0';

        check = call I2C_Resource.request();
        if(check != SUCCESS)
        {
          printf("Radio failed");
        }

        sync_state = 0;

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
        FMClick_operation_t current_operation_temp;

        atomic
        {
            current_operation_temp = current_operation;
        }

        if(current_operation_temp != FM_CLICK_IDLE)
        {
            return FAIL;
        }

        atomic
        {
            conf_registers.system_configuration_2.VOLUME = volume;
        }

        post write_conf_to_chip_task();

        return SUCCESS;
    }

    command error_t FMClick.receiveRDS(bool enable)
    {
        FMClick_operation_t current_operation_temp;

        atomic
        {
            current_operation_temp = current_operation;
        }

        if(current_operation_temp != FM_CLICK_IDLE)
        {
            return FAIL;
        }

        atomic
        {
            conf_registers.system_configuration_1.RDS = enable;
        }

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
            error_t check;
            atomic
            {
                i2c_in_use=TRUE;
            }
            // 11 bytes are enough, low byte of test1 shouldn't be touched
            check = call I2C.write(I2C_START | I2C_STOP, DEVICE_ADDRESS ,10, conf_registers.data_bytes);
            if(check != SUCCESS)
            {
                 post write_conf_to_chip_task();
            }
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
            error_t check;
            atomic
            {
                i2c_in_use=TRUE;
            }
            // 11 bytes are enough, low byte of test1 shouldn't be touched
            check = call I2C.write(I2C_START, DEVICE_ADDRESS ,12, conf_registers.data_bytes);
            if(check != SUCCESS)
            {
                 post write_conf_to_chip_task();
            }
        }
        else
        {
            post write_conf_to_chip_task();
        }
    }

    // send initial config
    void task get_data_from_chip_task()
    {
        bool i2c_in_use_temp;

        atomic
        {
            i2c_in_use_temp=i2c_in_use;
        }

        if(!i2c_in_use_temp)
        {
            error_t check;
            //read the status and rds data registers
            check = call I2C.read(I2C_START | I2C_STOP , DEVICE_ADDRESS, 12, buffer);	//NACK should be sent
            if(check != SUCCESS)
            {
      	         post get_data_from_chip_task();
            }
        }
        else
        {
            post get_data_from_chip_task();
        }
    }

    void task get_registers_task()
    {

        bool i2c_in_use_temp;

        atomic
        {
            i2c_in_use_temp=i2c_in_use;
        }

        if(!i2c_in_use_temp)
        {
            error_t check;

            //read all register
            check = call I2C.read(I2C_START | I2C_STOP , DEVICE_ADDRESS, 32, buffer);	//NACK should be sent
            if(check != SUCCESS)
            {
                 post get_registers_task();
            }
        }
        else
        {
            post get_data_from_chip_task();
        }
    }

    void task rds_task()
    {
        RDSType rds;
        uint8_t group_type;
        data_registers_t data_registers_temp;

        atomic
        {
            data_registers_temp =  data_registers;
        }

        call debug_out.toggle(0x01);

        if(data_registers_temp.rssi.RDSS &&
            data_registers_temp.read_channel.BLERB <= 2 &&
            data_registers_temp.read_channel.BLERC <= 2 &&
            data_registers_temp.read_channel.BLERD <= 2)
        {
            /* if(sync_state <= 3)
            {
                sync_state++;
                return;
            } */
        }
        else
        {
            sync_state =0;
            return;
        }


        group_type = (data_registers_temp.rdsb.data_bytes[0] >> 4);

        switch (group_type)
        {
            case RDS_TYPE_TUNING:
                rds = PS;
                call debug_out.toggle(0x02);
                break;
            case RDS_TYPE_RADIO_TEXT:
                rds = RT;
                call debug_out.toggle(0x04);
                break;
            case RDS_TYPE_TIME:
                if( ! (data_registers_temp.rdsb.data & 0x0800))
                {
                    rds = TIME;
                    call debug_out.toggle(0x08);
                }
                else
                {
                    return;
                }
                break;
            default:
                return;
        }

        if(rds==TIME)
        {
            uint32_t MJD = (data_registers_temp.rdsb.data_bytes[1] ) & 0x03; // Modified Julanian day

            uint16_t current_year = START_YEAR;
            uint8_t current_month =0;
            uint8_t current_day =0;
            bool is_leap_year = FALSE;
            uint8_t counter=NEXT_LEAP_YEAR;
            int8_t current_hour = data_registers_temp.rdsc.data_bytes[1] & 0x1;
            int8_t current_minute = data_registers_temp.rdsd.data_bytes[0] & 0xF;
            uint8_t time_offset = data_registers_temp.rdsd.data_bytes[1] & 0x1F;
            uint8_t temp = data_registers_temp.rdsd.data_bytes[0];

            char rds_buffer[6];

            temp >>= 4;

            current_hour <<= 4;
            current_hour |= (temp & 0x0F);

            temp = data_registers_temp.rdsd.data_bytes[1];
            temp >>=6;

            current_minute <<= 2;
            current_minute |= (temp & 0x3);

            if(data_registers_temp.rdsd.data_bytes[1] & 0x20)
            {
                if(time_offset & 0x01)
                {
                    current_minute -= TIME_OFFSET_MINUTES;
                    if(current_minute <0)
                    {
                        current_minute = MAX_MINUTES+current_minute;
                    }

                    current_hour--;
                    if(current_hour <0)
                    {
                        current_hour = MAX_HOUR;
                    }
                }
                time_offset >>=1;

                current_hour -= time_offset;

                if(current_hour <0)
                {
                    current_hour = MAX_HOUR+current_hour;
                }
            }
            else
            {
                if(time_offset & 0x01)
                {
                    current_minute += TIME_OFFSET_MINUTES;

                    if(current_minute > MAX_MINUTES)
                    {
                        current_minute = current_minute - MAX_MINUTES;
                    }

                    current_hour++;
                    if(current_hour > MAX_HOUR)
                    {
                        current_hour = 0;
                    }
                }

                time_offset >>=1;

                current_hour += time_offset;

                if(current_hour > MAX_HOUR)
                {
                    current_hour = current_hour-MAX_HOUR;
                }
            }

            MJD <<=8;
            MJD |= data_registers_temp.rdsc.data_bytes[0] ;
            MJD <<=8;
            MJD |= data_registers_temp.rdsc.data_bytes[1] ;
            MJD >>=1; // Now we have a 17 bit date format

            if(MJD < MJD_1ST_JANUARY_2018) // check if inpu is valid
            {
                return;
            }
            MJD -= MJD_1ST_JANUARY_2018; // normalize to 1st january of 2018

            while( MJD >= DAYS_IN_YEAR)
            {
                counter++;

                counter %= LEAP_YEAR_DISTANCE;

                if(counter==0) // check if current year is a leap year
                {
                    MJD-=DAYS_IN_YEAR;
                    is_leap_year = TRUE;
                }
                else if(is_leap_year) // check if last year was a leap year
                {
                    MJD-=DAYS_IN_LEAP_YEAR;
                    is_leap_year = FALSE;
                }
                else
                {
                    MJD-=DAYS_IN_YEAR;
                    is_leap_year = FALSE;
                }
                current_year++;
            }

            for(counter=0; counter < MONTHS_IN_YEAR;counter++)
            {
                uint8_t days = pgm_read_byte(&(days_of_month[counter]));
                if(is_leap_year && counter == LEAP_MONTH)
                {
                    if(MJD >= LEAP_MONTH_DAYS)
                    {
                        MJD -= LEAP_MONTH_DAYS;
                    }
                    else
                    {
                        current_month=counter+1;
                        current_day = MJD+1;
                        break;
                    }
                }
                else if(MJD > days)
                {
                    MJD -= days;
                }
                else
                {
                    current_month=counter+1;
                    current_day = MJD+1;
                    break;
                }
            }

            rds_buffer[0] = current_day;
            rds_buffer[1] = current_month;
            rds_buffer[2] = (current_year >> 8);
            rds_buffer[3] = (current_year & 0xFF);
            rds_buffer[4] = current_hour;
            rds_buffer[5] = current_minute;

            signal FMClick.rdsReceived(rds, rds_buffer);

        }
        else if(rds == RT)
        {

            uint8_t index = data_registers_temp.rdsb.data_bytes[1] & 0x0F;
            char temp_buf[5];

            if((data_registers_temp.rdsb.data_bytes[1] & 0x10 )&& !current_rds_text_type)
            {
                current_rds_text_type=TRUE;
                current_rds_text_index =0;
                rds_radio_text[0]='\0';
            }
            else if((data_registers_temp.rdsb.data_bytes[1] & 0x10) == 0 && current_rds_text_type)
            {
                current_rds_text_type=FALSE;
                current_rds_text_index =0;
                rds_radio_text[0]='\0';
            }

            if(current_rds_text_index == 0)
            {
                rds_radio_text[0] = '\0';
            }

            if( data_registers_temp.rdsb.data_bytes[0] & 0x08)
            {
                index <<= 1;
                temp_buf[0] = (char)(data_registers_temp.rdsc.data_bytes[0] &0x7F);
                temp_buf[1] = (char)(data_registers_temp.rdsc.data_bytes[1] &0x7F);
                temp_buf[2] = '\0';

                if(index != current_rds_text_index)
                {
                    current_rds_text_index=0;
                    return;
                }

                if(temp_buf[0] == '\r')
                {
                    temp_buf[0] = '\0';
                    current_rds_text_index = 0;
                }
                else if(temp_buf[1] == '\r')
                {
                    temp_buf[1] = '\0';
                    current_rds_text_index = 0;
                }
                else if(current_rds_text_index +2 >= RDS_TEXT_LENGTH_B)
                {
                    current_rds_text_index=0;
                }
                else
                {
                    current_rds_text_index+=2;
                }

            }
            else
            {
                index<<=2;
                temp_buf[0] = (char)(data_registers_temp.rdsc.data_bytes[0] &0x7F);
                temp_buf[1] = (char)(data_registers_temp.rdsc.data_bytes[1] &0x7F);
                temp_buf[2] = (char)(data_registers_temp.rdsd.data_bytes[0] &0x7F);
                temp_buf[3] = (char)(data_registers_temp.rdsd.data_bytes[1] &0x7F);
                temp_buf[4] = '\0';

                if(index != current_rds_text_index)
                {
                    current_rds_text_index=0;
                    return;
                }

                if(temp_buf[0] == '\r')
                {
                    temp_buf[0] = '\0';
                    current_rds_text_index = 0;
                }
                else if(temp_buf[1] == '\r')
                {
                    temp_buf[1] = '\0';
                    current_rds_text_index = 0;
                }
                else if(temp_buf[2] == '\r')
                {
                    temp_buf[2] = '\0';
                    current_rds_text_index = 0;
                }
                else if(temp_buf[3] == '\r')
                {
                    temp_buf[3] = '\0';
                    current_rds_text_index = 0;
                }
                else if(current_rds_text_index + 4 >= RDS_TEXT_LENGTH_A)
                {
                    current_rds_text_index=0;
                }
                else
                {
                    current_rds_text_index+=4;
                }
            }

            strcat(rds_radio_text, temp_buf);

            if(current_rds_text_index == 0 && rds_radio_text[0] != '\0')
            {
                signal FMClick.rdsReceived(rds, rds_radio_text);
            }
        }
        else
        {
            char rds_buffer[4];

            uint8_t index = (data_registers_temp.rdsb.data_bytes[1] ) & 0x03;

            rds_buffer[0] = index<<1;
            rds_buffer[1] = data_registers_temp.rdsd.data_bytes[0]&0x7F;
            rds_buffer[2] = data_registers_temp.rdsd.data_bytes[1]&0x7F;
            rds_buffer[3] = '\0';

            if(rds_buffer[1] < 0x20 || rds_buffer[2] < 0x20 )
            {
                return;
            }

            signal FMClick.rdsReceived(rds, rds_buffer);
        }

    }

    void task init_task()
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
                atomic
                {
                    conf_registers.test1.XOSCEN = 1;
                }

                init_state_temp = FM_CLICK_SET_OSC;
                post send_initial_conf_task();
                break;

            case FM_CLICK_SET_OSC:
                init_state_temp = FM_CLICK_WAIT_OSC;
                call Timer.startOneShot(500);
                break;
            case FM_CLICK_WAIT_OSC:

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
                call Timer.startOneShot(115);
                break;
            case FM_CLICK_INIT_DONE:
                init_state_temp=FM_CLICK_SEND_DEFAULT_CONF;
                atomic
                {
                    conf_registers.power_conf.SKMODE=0;
                    conf_registers.power_conf.RDSM=1;

                    conf_registers.system_configuration_1.GPIO2=1; // enable interrupt pin
                    conf_registers.system_configuration_1.DE=1; // set De-emphasis for Europe
                    conf_registers.system_configuration_1.RDSIEN = 1; // end RDS interrupt
                    conf_registers.system_configuration_1.STCIEN = 1; // enable Tune/Seek interrupt

                    conf_registers.system_configuration_2.SPACE  = 1; // set spacing for Europe

                    // configuration for seeking channels, see AN284
                    // http://read.pudn.com/downloads159/doc/710424/AN284Rev0_1.pdf
                    conf_registers.system_configuration_2.SEEKTH = 0x19;
                    conf_registers.system_configuration_3.SKSNR = 0x4;
                    conf_registers.system_configuration_3.SKCNT = 0x8;
                }
                post write_conf_to_chip_task();
                break;

            case FM_CLICK_SEND_DEFAULT_CONF:
                signal FMClick.initDone(SUCCESS);
                init_state_temp = FM_CLICK_READY;
                break;
            case FM_CLICK_READY:
                break;
        }

        atomic
        {
            init_state = init_state_temp;
        }
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

        if(init_state_temp == FM_CLICK_SET_OSC
            || init_state_temp == FM_CLICK_WAIT_POWER_UP
            || init_state_temp == FM_CLICK_SEND_DEFAULT_CONF)
        {
            post init_task();
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

            post init_task();
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
                        uint16_t channel;

                        conf_registers.channel.CHANNEL_H = data_registers.read_channel.CHANNEL_H;
                        conf_registers.channel.CHANNEL_L = data_registers.read_channel.CHANNEL_L;

                        conf_registers.power_conf.SEEK=0;

                        post write_conf_to_chip_task();

                        atomic
                        {
                            current_operation = FM_CLICK_WAIT_WRITE_FINISH;
                        }
                        channel = conf_registers.channel.CHANNEL_H;
                        channel <<= 8;
                        channel |= conf_registers.channel.CHANNEL_L;

                        /* call debug_out_2.clear(0xFF);
                        call debug_out_3.clear(0xFF);
                        call debug_out_2.set(channel>>8);
                        call debug_out_3.set(channel& 0xFF); */

                        signal FMClick.tuneComplete(channel);
                    }
                    break;
                case FM_CLICK_TUNE:
                    if(data_registers.rssi.STC)
                    {
                        uint16_t channel;

                        conf_registers.channel.TUNE=0;
                        post write_conf_to_chip_task();

                        atomic
                        {
                            current_operation = FM_CLICK_WAIT_WRITE_FINISH;
                        }

                        channel = conf_registers.channel.CHANNEL_H;
                        channel <<= 8;
                        channel |= conf_registers.channel.CHANNEL_L;

                        signal FMClick.tuneComplete(channel);
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
        post init_task();
    }
}
