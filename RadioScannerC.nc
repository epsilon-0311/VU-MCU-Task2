
#include <string.h>
#include <avr/pgmspace.h>

#define SCROLL_PERIOD_MS 1500

#define RADIO_SPACING_kHz 100
#define BAND_BOTTOM 87500L

typedef struct __rds_info
{
    char radio_text[65];
    char radio_station[9];
    uint8_t current_day;
    uint8_t current_month;
    uint16_t current_year;
    uint8_t current_hour;
    uint8_t current_minute;
} rds_info_t;

module RadioScannerC{
    uses interface PS2;
    uses interface Boot;
    uses interface BufferedLcd;
    uses interface FMClick;
    uses interface Read<uint16_t> as ReadVolume;
    uses interface Glcd;
    uses interface Timer<TMilli> as Timer;

    uses interface GeneralIOPort as debug_out_2;
}
implementation {

    uint8_t current_radio_text_index;
    uint16_t current_channel;

    char new_char;

    rds_info_t rds_info;

    char const PROGMEM date_time_format[] = "%2d.%2d.%4u %02d:%02d";
    char const PROGMEM station_format[] = "%6lukHz:";
    char const PROGMEM empty_line[] = "                   ";
    char const PROGMEM empty_half_line[] = "          ";

    event void Boot.booted(){
        call PS2.init();
        call BufferedLcd.clear();
        call BufferedLcd.forceRefresh();
        call FMClick.init();
        call Glcd.fill(0x00);
        call Timer.startPeriodic(1000);
        current_radio_text_index=0;

        atomic
        {
            rds_info.radio_text[0]='\0';
        }
    }

    void task update_radio_time_task ()
    {
        uint8_t length = strlen_P(date_time_format);
        char format[length+1];
        char date_string[16+1];
        (void) strcpy_P(format, date_time_format);
        atomic
        {
            sprintf(date_string, format, rds_info.current_day, rds_info.current_month, rds_info.current_year, rds_info.current_hour, rds_info.current_minute);
        }

        call Glcd.drawText(date_string,0,10);
    }

    void task update_channel_task()
    {
        char display_string[20];
        char display_string_2[20];

        uint32_t radio_frequency = RADIO_SPACING_kHz;
        (void) strcpy_P(display_string, station_format);

        atomic
        {
            radio_frequency *= (uint32_t) current_channel;
        }

        radio_frequency += (uint32_t) BAND_BOTTOM;

        sprintf(display_string_2, display_string, radio_frequency);

        call Glcd.drawText(display_string_2,0,20);

    }

    void task update_radio_station_task ()
    {
        char station_string[8+1];

        atomic
        {
            (void)strcpy(station_string, rds_info.radio_station);
        }

        if(station_string[0]=='\0')
        {
            call Glcd.drawTextPgm(empty_half_line,64,20);
        }
        else
        {
            call Glcd.drawText(station_string,64,20);
        }
    }

    void task update_radio_text_task ()
    {
        char radio_text[20];
        atomic
        {
            (void)strncpy(radio_text, &(rds_info.radio_text[current_radio_text_index]), 19);
        }

        radio_text[19] = '\0';
        if(strlen(radio_text)<19 || radio_text[0] == '\0')
        {
            call Glcd.drawTextPgm(empty_line,0,30);
            current_radio_text_index=0;
        }
        else
        {
            current_radio_text_index++;
        }
        call Glcd.drawText(radio_text,0,30);
    }

    void task received_char_task()
    {
        call FMClick.seek(TRUE);
    }

    async event void PS2.receivedChar(uint8_t chr){
        atomic
        {
            new_char = chr;
        }
        post received_char_task();
    }

    event void ReadVolume.readDone(error_t err, uint16_t val)
    {

    }

    event void FMClick.initDone(error_t res)
    {

    }

    async event void FMClick.tuneComplete(uint16_t channel)
    {
        atomic
        {
            current_channel = channel;
            rds_info.radio_station[0] = '\0';
            rds_info.radio_text[0] = '\0';
        }

        post update_radio_station_task();
        post update_radio_text_task();
        post update_channel_task();
    }

    async event void FMClick.rdsReceived(RDSType type, char *buf)
    {
        if(type == PS)
        {
            uint8_t index = (uint8_t)buf[0];
            atomic
            {
                strcpy (&(rds_info.radio_station[index]),&(buf[1]));
            }
            post update_radio_station_task();
        }
        else if(type == RT)
        {
            atomic
            {
                strcpy (rds_info.radio_text,buf);
            }
        }
        else if(type == TIME)
        {
            uint8_t temp = (uint8_t)buf[3];

            atomic
            {
                rds_info.current_day = (uint8_t)buf[0];
                rds_info.current_month = (uint8_t)buf[1];

                rds_info.current_year  = (uint8_t)(buf[2]);
                rds_info.current_year <<= 8;
                rds_info.current_year |= temp;

                rds_info.current_hour = (uint8_t)buf[4];
                rds_info.current_minute = (uint8_t)buf[5];
            }
            post update_radio_time_task();
        }
    }

    event void Timer.fired()
    {
        post update_radio_text_task();
    }
}
