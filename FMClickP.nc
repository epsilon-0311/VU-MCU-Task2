
#include <avr/pgmspace.h>
#include "FMClick.h"

module FMClickP{
    uses interface I2CPacket<TI2CBasicAddr> as I2C;
    uses interface Resource as I2C_Resource;
    uses interface GeneralIO as Interrupt_Pin;
    uses interface GeneralIO as Reset_Pin;
    uses interface GeneralIO as I2C_SDA;
    uses interface HplAtm128Interrupt as External_Interrupt;
    uses interface Timer<TMilli> as Timer;

    uses interface GeneralIOPort as rds_debug;

    provides interface FMClick;
    provides interface Init;
}

implementation
{
    void task init_task();
    void task get_data_from_chip_task();
    void task write_conf_to_chip_task();
    void task send_initial_conf_task();
    void task rds_task();
    void task request_ressource_task();
    void task reset_rds_task();

    void handle_last_operation(FMClick_operation_t operation);
    void decode_radio_text(void);
    void handle_radio_text_type_a(char *buffer, data_registers_t data_registers_temp, uint8_t index);
    void handle_radio_text_type_b(char *buffer, data_registers_t data_registers_temp, uint8_t index);
    void decode_datetime(void);
    error_t decode_date(char *buffer, data_registers_t data_registers_temp);
    error_t decode_time(char *buffer, data_registers_t data_registers_temp);
    
    conf_registers_t conf_registers;
    data_registers_t data_registers;

    FMClick_init_state_t init_state;
    FMClick_operation_t current_operation;

    uint8_t i2c_buffer[32];

    bool i2c_in_use;
    bool rds_pending;
    uint8_t const PROGMEM days_of_month[] = {31,28,31,30,31,30,31,31,30,31,30,31};
    char rds_radio_text[RDS_TEXT_LENGTH_A+1]; // +1 for nul char
    uint8_t current_rds_text_index;
    bool current_rds_text_type;
    char rds_radio_station[RDS_STATION_LENGTH+1]; // +1 for nul char
    uint8_t current_rds_station_index;

    command error_t Init.init(void)
    {
        call rds_debug.makeOutput(0xFF);

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

        call Timer.startOneShot(1);

        call External_Interrupt.edge(FALSE);
        call External_Interrupt.enable();

        return SUCCESS;
    }

    command error_t FMClick.tune(uint16_t channel)
    {
        FMClick_init_state_t init_state_temp;
        FMClick_operation_t current_operation_temp;

        atomic
        {
            init_state_temp = init_state;
            current_operation_temp = current_operation;
        }

        if(init_state_temp != FM_CLICK_READY ||
           current_operation_temp != FM_CLICK_IDLE)
        {
            return FAIL;
        }

        atomic
        {

            current_operation = FM_CLICK_TUNE_START;
            
            conf_registers.channel.CHANNEL_L = channel&0xFF;
            conf_registers.channel.CHANNEL_H = (channel >> 8) & 0x03;
            conf_registers.channel.TUNE = 1;
        }

        post request_ressource_task();
        return SUCCESS;

    }

    command error_t FMClick.seek(bool up)
    {
        FMClick_init_state_t init_state_temp;
        FMClick_operation_t current_operation_temp;

        atomic
        {
            init_state_temp = init_state;
            current_operation_temp = current_operation;
        }

        if(init_state_temp != FM_CLICK_READY ||
           current_operation_temp != FM_CLICK_IDLE)
        {

            return FAIL;
        }

        atomic
        {
            current_operation = FM_CLICK_SEEK_START;
            
            conf_registers.power_conf.SEEK = 1;
            conf_registers.power_conf.SEEKUP = up;
        }
        
        post request_ressource_task();

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
        FMClick_init_state_t init_state_temp;
        FMClick_operation_t current_operation_temp;

        atomic
        {
            init_state_temp = init_state;
            current_operation_temp = current_operation;
        }

        if(init_state_temp != FM_CLICK_READY ||
           current_operation_temp != FM_CLICK_IDLE)
        {
            return FAIL;
        }

        atomic
        {
            current_operation = FM_CLICK_VOLUME;
            conf_registers.system_configuration_2.VOLUME = volume;
        }

        post request_ressource_task();

        return SUCCESS;
    }

    command error_t FMClick.receiveRDS(bool enable)
    {
        FMClick_init_state_t init_state_temp;
        FMClick_operation_t current_operation_temp;

        atomic
        {
            init_state_temp = init_state;
            current_operation_temp = current_operation;
        }

        if(init_state_temp != FM_CLICK_READY ||
           current_operation_temp != FM_CLICK_IDLE)
        {
            return FAIL;
        }

        atomic
        {
            current_operation = FM_CLICK_RDS;
            conf_registers.system_configuration_1.RDS = enable;
        }

        post request_ressource_task();

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
            
            // 11 bytes are enough, low byte of test1 shouldn't be touched
            check = call I2C.write(I2C_START | I2C_STOP, DEVICE_ADDRESS ,10, conf_registers.data_bytes);
            if(check != SUCCESS)
            {
                 post write_conf_to_chip_task();
            }
            else
            {
                atomic
                {
                    i2c_in_use=TRUE;
                }
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
            
            // 11 bytes are enough, low byte of test1 shouldn't be touched
            check = call I2C.write(I2C_START, DEVICE_ADDRESS ,12, conf_registers.data_bytes);
            if(check != SUCCESS)
            {
                 post write_conf_to_chip_task();
            }
            else
            {
                atomic
                {
                    i2c_in_use=TRUE;
                }
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
            check = call I2C.read(I2C_START | I2C_STOP , DEVICE_ADDRESS, 12, i2c_buffer);	//NACK should be sent
            if(check != SUCCESS)
            {
      	         post get_data_from_chip_task();
            }
            else
            {
                atomic
                {
                    i2c_in_use = TRUE;
                }
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
            check = call I2C.read(I2C_START | I2C_STOP , DEVICE_ADDRESS, 32, i2c_buffer);	//NACK should be sent
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

        call rds_debug.toggle(0x01);

        if(!(data_registers_temp.rssi.RDSS &&
             data_registers_temp.read_channel.BLERB <= RDS_ALLOWED_ERRORS &&
             data_registers_temp.read_channel.BLERC <= RDS_ALLOWED_ERRORS &&
             data_registers_temp.read_channel.BLERD <= RDS_ALLOWED_ERRORS)
        )
        {
            // not sufficient synced
            return;
        }


        group_type = (data_registers_temp.rdsb.data_bytes[0] >> 4);

        switch (group_type)
        {
            case RDS_TYPE_TUNING:
                rds = PS;
                call rds_debug.toggle(0x02);
                break;
            case RDS_TYPE_RADIO_TEXT:
                rds = RT;
                call rds_debug.toggle(0x04);
                break;
            case RDS_TYPE_TIME:
                if( ! (data_registers_temp.rdsb.data & 0x0800))
                {
                    rds = TIME;
                    call rds_debug.toggle(0x08);
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
            decode_datetime();
        }
        else if(rds == RT)
        {
            decode_radio_text();
        }
        else
        {
            uint8_t index = (data_registers_temp.rdsb.data_bytes[1] ) & 0x03;

            index <<=1;

            rds_radio_station[index] = data_registers_temp.rdsd.data_bytes[0]&0x7F;
            rds_radio_station[index+1] = data_registers_temp.rdsd.data_bytes[1]&0x7F;

            if(index == 6)
            {
                rds_radio_station[8]='\0';
                signal FMClick.rdsReceived(rds, rds_radio_station);
            }
        }

    }

    void task request_ressource_task()
    {
        if(call I2C_Resource.request() != SUCCESS)
        {
            post request_ressource_task();
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

                post request_ressource_task();
                
                
                break;
            case FM_CLICK_READ_REGISTERS:

                atomic
                {
                    conf_registers.test1.XOSCEN = 1;
                }

                init_state_temp = FM_CLICK_SET_OSC;
                
                post request_ressource_task();
                    
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

                post request_ressource_task();

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

                post request_ressource_task();
                break;

            case FM_CLICK_SEND_DEFAULT_CONF:
                init_state_temp = FM_CLICK_READY;
                break;
            case FM_CLICK_READY:
                break;
        }

        atomic
        {
            init_state = init_state_temp;
        }

        if(init_state_temp == FM_CLICK_READY)
        {
            signal FMClick.initDone(SUCCESS);
        }
    }

    void task seek_tune_timer_task()
    {
        call Timer.startOneShot(40);
    }

    event void I2C_Resource.granted()
    {

        FMClick_init_state_t init_state_temp;
        FMClick_operation_t current_operation_temp;

        atomic
        {
            init_state_temp = init_state;
            current_operation_temp = current_operation;
        }

        if(init_state_temp == FM_CLICK_READ_REGISTERS)
        {
            post get_registers_task();
        }
        else if(init_state_temp == FM_CLICK_SET_OSC)
        {
            post send_initial_conf_task();
        }
        else if(init_state_temp == FM_CLICK_WAIT_POWER_UP ||
                init_state_temp == FM_CLICK_SEND_DEFAULT_CONF ||
                current_operation_temp == FM_CLICK_TUNE_START||
                current_operation_temp == FM_CLICK_SEEK_START||
                current_operation_temp == FM_CLICK_VOLUME||
                current_operation_temp == FM_CLICK_RDS)
        {
            post write_conf_to_chip_task();
        }
        else if(current_operation_temp == FM_CLICK_WAIT_FOR_CLEAR ||
                current_operation_temp == FM_CLICK_SEEK_WAIT ||
                current_operation_temp == FM_CLICK_TUNE_WAIT ||
                current_operation_temp == FM_CLICK_GET_RDS)
        {
            post get_data_from_chip_task();
        }
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
            call I2C_Resource.release();
        }
        else if(current_operation_temp == FM_CLICK_VOLUME || 
                current_operation_temp == FM_CLICK_RDS)
        {
            // request data from chip if rds data are pending
            if(rds_pending)
            {
                atomic
                {
                    current_operation = FM_CLICK_GET_RDS;
                }
                post get_data_from_chip_task();
            }
            else
            {
                atomic
                {
                    current_operation = FM_CLICK_IDLE;
                }

                call I2C_Resource.release();
            }
           
        }
        else if(current_operation_temp == FM_CLICK_WAIT_WRITE_FINISH)
        {
            atomic
            {
                current_operation = FM_CLICK_WAIT_FOR_CLEAR;
                post get_data_from_chip_task();
            }
        }
        else if(current_operation_temp == FM_CLICK_SEEK_START)
        {
            atomic
            {
                current_operation = FM_CLICK_SEEK_WAIT;
            }

            if(rds_pending)
            {
                post get_data_from_chip_task();
            }
            else
            {
                call I2C_Resource.release();
            }
        }
        else if(current_operation_temp == FM_CLICK_TUNE_START)
        {
            atomic
            {
                current_operation = FM_CLICK_TUNE_WAIT;
            }

            if(rds_pending)
            {
                post get_data_from_chip_task();
            }
            else
            {
                call I2C_Resource.release();
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
            uint8_t offset = 16;

            memcpy(conf_registers.data_bytes, &(data[offset]), 12);

            post init_task();
            call I2C_Resource.release();
        }
        else if(length==12)
        {

            memcpy(data_registers.data_bytes, data, 12);

            handle_last_operation(current_operation_temp);

            if(data_registers.rssi.RDSR)
            {
                rds_pending = FALSE;
                post rds_task();
            }   

            if (current_operation_temp == FM_CLICK_GET_RDS)
            {
                call I2C_Resource.release();
                atomic
                {
                    current_operation = FM_CLICK_IDLE;
                }
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

        if(current_operation_temp == FM_CLICK_TUNE_WAIT || 
           current_operation_temp == FM_CLICK_SEEK_WAIT )
        {
            post request_ressource_task();
        }
        else if(conf_registers.system_configuration_1.RDS)
        {
            rds_pending = TRUE;

            if(current_operation_temp == FM_CLICK_IDLE)
            {
                atomic
                {
                    current_operation = FM_CLICK_GET_RDS;
                }
                
                post request_ressource_task();
            }
        }
    }

    event void Timer.fired()
    {
        FMClick_operation_t operation;
        atomic
        {
            operation = current_operation;
        }

        if(operation == FM_CLICK_WAIT_FOR_CLEAR)
        {
            post request_ressource_task();
        }
        else
        {
            post init_task();
        }
    }

    void handle_last_operation(FMClick_operation_t operation)
    {
        
        switch(operation)
            {
                
                case FM_CLICK_SEEK_WAIT:
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
                        
                        if(!data_registers.rssi.SF_BL)
                        {
                            channel = conf_registers.channel.CHANNEL_H;
                            channel <<= 8;
                            channel |= conf_registers.channel.CHANNEL_L;

                            signal FMClick.tuneComplete(channel);
                        }        
                        post reset_rds_task();
                    }
                    else
                    {
                        post get_data_from_chip_task();
                    }
                    
                    break;
                case FM_CLICK_TUNE_WAIT:
                    
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
                        post reset_rds_task();
                    }
                    else
                    {
                        post get_data_from_chip_task();
                    }
                    break;
                case FM_CLICK_WAIT_FOR_CLEAR:
                    
                    if(data_registers.rssi.STC)
                    {
                        post seek_tune_timer_task();
                        call I2C_Resource.release();
                    }
                    else
                    {
                        atomic
                        {
                            current_operation = FM_CLICK_IDLE;
                        }
                        call I2C_Resource.release();
                    }
                    break;
                default:
                    break;
            }
    }

    void task reset_rds_task()
    {
        rds_radio_text[0]='\0';
        current_rds_text_index=0;
        rds_radio_station[0] = '\0';
        current_rds_station_index = 0;
    }

    void decode_radio_text(void)
    {
        uint8_t index;
        char temp_buf[5];
        data_registers_t data_registers_temp;

        atomic
        {
            data_registers_temp =  data_registers;
        }

        index = data_registers_temp.rdsb.data_bytes[1] & 0x0F;

        if((data_registers_temp.rdsb.data_bytes[1] & 0x10 )&& !current_rds_text_type)
        {
            current_rds_text_type=TRUE;
            current_rds_text_index =0;
            memset(rds_radio_text, '\0', RDS_TEXT_LENGTH_A);
        }
        else if((data_registers_temp.rdsb.data_bytes[1] & 0x10) == 0 && current_rds_text_type)
        {
            current_rds_text_type=FALSE;
            current_rds_text_index =0;
            memset(rds_radio_text, '\0', RDS_TEXT_LENGTH_A);
        }

        if(current_rds_text_index == 0)
        {
            memset(rds_radio_text, '\0', RDS_TEXT_LENGTH_A);
        }

        if( data_registers_temp.rdsb.data_bytes[0] & 0x08)
        {
            index<<=1;
            if(index != current_rds_text_index)
            {
                current_rds_text_index=0;
                return;
            }
            handle_radio_text_type_b(temp_buf, data_registers_temp, index);
        }
        else
        {
            index <<= 2;
            if(index != current_rds_text_index)
            {
                current_rds_text_index=0;
                return;
            }
            handle_radio_text_type_a(temp_buf, data_registers_temp, index);
        }

        strcat(rds_radio_text, temp_buf);

        if(current_rds_text_index == 0 && strlen(rds_radio_text) > 0)
        {
            signal FMClick.rdsReceived(RT, rds_radio_text);
        }
    }

    void handle_radio_text_type_a(char *buffer, data_registers_t data_registers_temp, uint8_t index)
    {
        uint8_t i;

        buffer[0] = (char)(data_registers_temp.rdsc.data_bytes[0] &0x7F);
        buffer[1] = (char)(data_registers_temp.rdsc.data_bytes[1] &0x7F);
        buffer[2] = (char)(data_registers_temp.rdsd.data_bytes[0] &0x7F);
        buffer[3] = (char)(data_registers_temp.rdsd.data_bytes[1] &0x7F);
        buffer[4] = '\0';

        for(i=0; i<4; i++)
        {
            if(buffer[i] == '\r')
            {
                buffer[i] = '\0';
                current_rds_text_index = 0;
                return;
            }
        }

        if(current_rds_text_index + 4 >= RDS_TEXT_LENGTH_A)
        {
            current_rds_text_index=0;
        }
        else
        {
            current_rds_text_index+=4;
        }
    }

    void handle_radio_text_type_b(char *buffer, data_registers_t data_registers_temp, uint8_t index)
    {
        uint8_t i;

        buffer[0] = (char)(data_registers_temp.rdsc.data_bytes[0] &0x7F);
        buffer[1] = (char)(data_registers_temp.rdsc.data_bytes[1] &0x7F);
        buffer[2] = '\0';

        for(i=0; i<2; i++)
        {
            if(buffer[i] == '\r')
            {
                buffer[i] = '\0';
                current_rds_text_index = 0;
                return;
            }
        }

        if(current_rds_text_index +2 >= RDS_TEXT_LENGTH_B)
        {
            current_rds_text_index=0;
        }
        else
        {
            current_rds_text_index+=2;
        }
    }

    void decode_datetime(void)
    {   
        data_registers_t data_registers_temp;
        char rds_buffer[6];

        atomic
        {
            data_registers_temp =  data_registers;
        }
                
        if(decode_time(&(rds_buffer[4]), data_registers_temp) != SUCCESS)
        {
            return;
        }

        if(decode_date(rds_buffer, data_registers_temp) != SUCCESS)
        {
            return;
        }
    
        signal FMClick.rdsReceived(TIME, rds_buffer);
    }

    error_t decode_time(char *buffer, data_registers_t data_registers_temp)
    {
        int8_t current_hour = data_registers_temp.rdsc.data_bytes[1] & 0x1;
        int8_t current_minute = data_registers_temp.rdsd.data_bytes[0] & 0xF;
        uint8_t time_offset = data_registers_temp.rdsd.data_bytes[1] & 0x1F;
        uint8_t temp = data_registers_temp.rdsd.data_bytes[0];

        static uint8_t last_minute =0;
        static uint8_t last_hour = 0;

        error_t return_value = SUCCESS;
        

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

        // initial state
        if(last_minute == 0 && last_hour == 0)
        {
            buffer[0] = current_hour;
            buffer[1] = current_minute;
        }
        else if(current_hour > MAX_HOUR || current_minute > MAX_MINUTES)
        {
            return_value =  FAIL;
        }
        else if((current_hour - last_hour >= TOLERANCE_HOURS ||
                current_minute - last_minute >= TOLERANCE_MINUTES) &&
                current_minute > 0
        )
        {
            return_value =  FAIL;
        }
        else
        {
            buffer[0] = current_hour;
            buffer[1] = current_minute;
        }

        last_minute = current_minute;
        last_hour   = current_hour;

        return return_value;
    }

    error_t decode_date(char *buffer, data_registers_t data_registers_temp)
    {
        uint32_t MJD = (data_registers_temp.rdsb.data_bytes[1] ) & 0x03; // Modified Julanian day

        uint16_t current_year = START_YEAR;
        uint8_t current_month =0;
        uint8_t current_day =0;
        bool is_leap_year = FALSE;
        uint8_t counter=NEXT_LEAP_YEAR;
        static uint16_t last_year =0;
        static uint8_t last_month =0;
        static uint8_t last_day = 0;

        error_t return_value = SUCCESS;

        MJD <<=8;
        MJD |= data_registers_temp.rdsc.data_bytes[0] ;
        MJD <<=8;
        MJD |= data_registers_temp.rdsc.data_bytes[1] ;
        MJD >>=1; // Now we have a 17 bit date format

        if(MJD < MJD_1ST_JANUARY_2019) // check if inpu is valid
        {
            return FAIL;
        }
        MJD -= MJD_1ST_JANUARY_2019; // normalize to 1st january of 2018

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

        if(last_year == 0 && last_month == 0 && last_day ==0)
        {
            // initial state
            buffer[0] = current_day;
            buffer[1] = current_month;
            buffer[2] = (current_year >> 8);
            buffer[3] = (current_year & 0xFF);

        }
        else if(current_month >= MONTHS_IN_YEAR || current_day > MAX_DAYS_IN_MONTH)
        {
            return_value = FAIL;
        }
        else if((current_year - last_year > TOLERANCE_YEARS ||
                current_month - last_month > TOLERANCE_MONTHS ||
                current_day - last_day > TOLERANCE_DAYS) &&
                current_day > 0
        )
        {
            return_value = FAIL;
        }
        else
        {
            buffer[0] = current_day;
            buffer[1] = current_month;
            buffer[2] = (current_year >> 8);
            buffer[3] = (current_year & 0xFF);
        }
        
        last_year = current_year;
        last_month= current_month;
        last_day  = current_day;

        return return_value;
    }
}
