
#include <string.h>
#include <avr/pgmspace.h>

#define SCROLL_PERIOD_MS 1500
#define VOLUME_SAMPLE_PERIOD_MS 100
#define VOLUME_SAMPLE_ARRAY_SIZE 5

#define RADIO_SPACING_kHz 100
#define BAND_BOTTOM 87500L
#define SCAN_LIST_SIZE 32

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
    uses interface Timer<TMilli> as Scroll_Timer;
    uses interface Timer<TMilli> as Volume_Timer;

    uses interface GeneralIOPort as debug_out_2;
}
implementation {

    uint8_t current_radio_text_index;
    uint16_t current_channel;
    uint8_t volume_sample_array[VOLUME_SAMPLE_ARRAY_SIZE];
    uint8_t volume_sample_index;
    uint8_t current_volume;
    uint8_t next_volume_entry;

    bool scan_running;
    uint16_t scan_list[SCAN_LIST_SIZE];
    uint8_t scan_index;

    char new_char;
    bool display_help;
    bool display_free;

    rds_info_t rds_info;

    char const PROGMEM date_time_format[] = "%2d.%2d.%4u %02d:%02d";
    char const PROGMEM station_format[] = "%3u.%1u MHz:";
    char const PROGMEM empty_line[] = "                   ";
    char const PROGMEM empty_half_line[] = "          ";
    char const PROGMEM h_for_help[] = "press h to toggle help";
    char const PROGMEM help_string[] =  "n/p switch channel\n+/- tune\nl   display list\ns   scan";
    char const PROGMEM volume_text[] = "Volume:%2u";

    task void display_list_task();

    event void Boot.booted(){
        call PS2.init();
        call BufferedLcd.clear();
        call BufferedLcd.forceRefresh();
        call FMClick.init();
        call Glcd.fill(0x00);
        call Scroll_Timer.startPeriodic(SCROLL_PERIOD_MS);
        call Volume_Timer.startPeriodic(VOLUME_SAMPLE_PERIOD_MS);

        current_radio_text_index=0;

        atomic
        {
            display_free = TRUE;
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
        uint16_t kHz;
        uint8_t MHz;

        (void) strcpy_P(display_string, station_format);

        atomic
        {
            radio_frequency *= (uint32_t) current_channel;
        }

        radio_frequency += (uint32_t) BAND_BOTTOM;
        kHz = radio_frequency%1000;
        kHz /= 100;
        MHz = radio_frequency/1000;

        sprintf(display_string_2, display_string, MHz, kHz);

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

    void task display_help_task()
    {
        call Glcd.drawTextPgm(help_string,0,10);
    }

    void task received_char_task()
    {
        char current_char;
        atomic
        {
            current_char = new_char;
        }

        if(current_char == 'h' || current_char == 'H')
        {
            bool display_free_temp;

            atomic
            {
                display_help = !display_help;
                display_free_temp= display_free;
            }

            if(! display_free)
            {
                return;
            }

            call Glcd.fill(0x00);

            if(display_help)
            {
                atomic
                {
                    display_free=FALSE;
                }
                post display_help_task();
            }
            else
            {
                atomic
                {
                    display_free=TRUE;
                }

                current_radio_text_index = 0;
                post update_channel_task();
                post update_radio_station_task();
                post update_radio_time_task();
                post update_channel_task();
            }
        }
        else if(current_char == 'n')
        {
            call FMClick.seek(TRUE);
        }
        else if(current_char == 'p')
        {
            call FMClick.seek(FALSE);
        }
        else if(current_char == '+')
        {
            uint16_t channel;
            atomic
            {
                channel = current_channel;
            }
            channel++;
            call FMClick.tune(channel);
        }else if(current_char == '-')
        {
            uint16_t channel;
            atomic
            {
                channel = current_channel;
            }
            channel--;
            call FMClick.tune(channel);
        }
        else if(current_char == 's' || current_char == 'S')
        {
            call FMClick.tune(0);
            atomic
            {
                scan_running = TRUE;
                scan_index=0;
            }
        }else if(current_char == 's' || current_char == 'S')
        {
            call FMClick.tune(0);
            atomic
            {
                scan_running = TRUE;
                scan_index=0;
            }
        }
        else if(current_char == 'l' || current_char == 'L')
        {
            post display_list_task();
        }
    }

    void task enable_RDS_task()
    {
        if((call FMClick.receiveRDS(TRUE) )!= SUCCESS)
        {
            post enable_RDS_task();
        }
    }

    void task set_volume_task()
    {

        if(call FMClick.setVolume(current_volume) != SUCCESS)
        {
            post set_volume_task();
        }
        else
        {
            char volume_format[11];
            char volume_string[17];
            strcpy_P(volume_format, volume_text);
            sprintf(volume_string, volume_format, current_volume);
            call BufferedLcd.goTo(0,0);
            call BufferedLcd.write(volume_string);
            call BufferedLcd.forceRefresh();
        }
    }

    void task check_volume_task()
    {
        uint8_t new_volume;

        atomic
        {
            new_volume = next_volume_entry;
        }

        volume_sample_array[volume_sample_index] = new_volume;
        volume_sample_index++;

        if(volume_sample_index >= VOLUME_SAMPLE_ARRAY_SIZE)
        {
            uint8_t i, j;
            volume_sample_index=0;
            for(i =1; i < VOLUME_SAMPLE_ARRAY_SIZE-1; ++i)
            {
                for(j =0; j < VOLUME_SAMPLE_ARRAY_SIZE-1; ++j)
                {
                    if(volume_sample_array[j] > volume_sample_array[j+1])
                    {
                        uint8_t temp = volume_sample_array[j+1];
                        volume_sample_array[j+1] = volume_sample_array[j];
                        volume_sample_array[j] = temp;
                    }
                }
            }

            if(volume_sample_array[VOLUME_SAMPLE_ARRAY_SIZE/2] != current_volume)
            {
                current_volume = volume_sample_array[VOLUME_SAMPLE_ARRAY_SIZE/2];
                post set_volume_task();
            }
        }
    }

    void task display_list_task()
    {
        uint8_t i;

        atomic
        {
            display_free = FALSE;
            display_help = FALSE;
        }

        call Glcd.fill(0x00);

        for(i=0; i<6; i++)
        {
            char display_string[20];
            char display_string_2[20];

            uint32_t radio_frequency = RADIO_SPACING_kHz * scan_list[i];
            uint16_t kHz;
            uint8_t MHz;

            (void) strcpy_P(display_string, station_format);

            radio_frequency += (uint32_t) BAND_BOTTOM;
            kHz = radio_frequency%1000;
            kHz /= 100;
            MHz = radio_frequency/1000;

            sprintf(display_string_2, display_string, MHz, kHz);

            call Glcd.drawText(display_string_2,0,10 + 10*i);
        }

        for(i=0; i<6; i++)
        {
            char display_string[20];
            char display_string_2[20];

            uint32_t radio_frequency = RADIO_SPACING_kHz * scan_list[i+6];
            uint16_t kHz;
            uint8_t MHz;

            (void) strcpy_P(display_string, station_format);

            radio_frequency += (uint32_t) BAND_BOTTOM;
            kHz = radio_frequency%1000;
            kHz /= 100;
            MHz = radio_frequency/1000;

            sprintf(display_string_2, display_string, MHz, kHz);

            call Glcd.drawText(display_string_2,64,10 + 10*i);
        }

    }

    void task scan_task()
    {
        uint16_t channel;

        atomic
        {
            channel = current_channel;
        }

        if(scan_index >= SCAN_LIST_SIZE)
        {
            atomic
            {
                scan_running= FALSE;
            }
            post display_list_task();
            return;
        }

        if(call FMClick.seek(TRUE) != SUCCESS)
        {
            post scan_task();
        }
        else if(channel != 0)
        {
            scan_list[scan_index] = channel;
            atomic
            {
                scan_index++;
            }
        }
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
        if(err == SUCCESS)
        {
            atomic
            {
                next_volume_entry = val >> 6;
            }

            post check_volume_task();
        }
    }

    event void FMClick.initDone(error_t res)
    {
        post enable_RDS_task();
    }

    async event void FMClick.tuneComplete(uint16_t channel)
    {
        uint8_t index;
        uint16_t old_channel;
        atomic
        {
            old_channel = current_channel;
            current_channel = channel;
            rds_info.radio_station[0] = '\0';
            rds_info.radio_text[0] = '\0';
            index = scan_index;
        }

        if(scan_running)
        {
            if(old_channel > channel && index > 0)
            {
                post display_list_task();
                atomic
                {
                    scan_running = FALSE;
                }
            }
            else
            {
                post scan_task();
            }
        }

        if(display_free)
        {
            post update_radio_station_task();
            post update_radio_text_task();
            post update_channel_task();
        }
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
            if(display_free)
            {
                post update_radio_station_task();
            }
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
            if(display_free)
            {
                post update_radio_time_task();
            }
        }
    }

    event void Scroll_Timer.fired()
    {
        if(display_free)
        {
            post update_radio_text_task();
        }
    }

    event void Volume_Timer.fired()
    {
        call ReadVolume.read();
    }

}
