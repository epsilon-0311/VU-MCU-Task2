
#include <string.h>
#include <avr/pgmspace.h>

#define SCROLL_PERIOD_MS 1500
#define VOLUME_SAMPLE_PERIOD_MS 100
#define VOLUME_SAMPLE_ARRAY_SIZE 5

#define RADIO_SPACING_kHz 100
#define BAND_BOTTOM_kHz 87500L
#define BAND_BOTTOM_100kHz 875L

#define SCAN_LIST_SIZE 32
#define SCAN_PAGE_SIZE 10

#define CHARS_IN_LINE 19

#define RADIO_TIME_LINE 10
#define RADIO_STATION_LINE 20
#define RADIO_STATION_SPACER 64
#define RADIO_TEXT_LINE 30
#define HELP_TEXT_LINE 60

#define RADIO_TEXT_LENGTH 64
#define RADIO_STATION_LENGTH 8

#define FAVORITE_LIST_LENGTH 9

typedef struct __rds_info
{
    char radio_text[RADIO_TEXT_LENGTH+1];
    char radio_station[RADIO_STATION_LENGTH+1];
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
    uses interface Database;
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
    uint8_t current_page;

    char new_char;
    bool display_help;
    bool display_free;
    bool display_list;

    bool input_favorite;
    uint16_t favorite_list[FAVORITE_LIST_LENGTH+1];

    rds_info_t rds_info;

    char const PROGMEM date_time_format[] = "%2d.%2d.%4u %02d:%02d";
    char const PROGMEM station_format[] = "%3u.%1u MHz:";
    char const PROGMEM empty_line[] = "                   ";
    char const PROGMEM empty_half_line[] = "          ";
    char const PROGMEM h_for_help[] = "h to toggle help";
    char const PROGMEM help_string[] =  "n/p switch channel\n+/- tune\nl   toggle list\ns   scan\nf   add favorite\nt   add note";
    char const PROGMEM volume_text[] = "Volume:%2u";
    char const PROGMEM list_entry_format[] = "%1u:%3u.%1u  | %1u:%3u.%1u \n";
    char const PROGMEM list_half_entry_format[] = "%1u:%3u.%1u\n";
    char const PROGMEM list_change_page[] = "+/- to change page\n[0-9] tune channel";

    task void display_list_task();

    event void Boot.booted(){
        call PS2.init();
        call BufferedLcd.clear();
        call BufferedLcd.forceRefresh();
        call FMClick.init();
        call Glcd.fill(0x00);
        call Scroll_Timer.startPeriodic(SCROLL_PERIOD_MS);
        call Volume_Timer.startPeriodic(VOLUME_SAMPLE_PERIOD_MS);
        call Database.getChannelList(0);

        current_radio_text_index=0;

        atomic
        {
            display_free = TRUE;
            rds_info.radio_text[0]='\0';
            memset(favorite_list,0,FAVORITE_LIST_LENGTH);
        }
    }

    void task update_radio_time_task ()
    {
        uint8_t length = strlen_P(date_time_format);
        char format[length+1];
        char date_string[length+1];

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

        radio_frequency += (uint32_t) BAND_BOTTOM_kHz;
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

        if(display_list)
        {
            if(current_char == '+')
            {
                uint8_t current_index = SCAN_PAGE_SIZE;
                current_page++;
                current_index*=current_page;

                if(current_index >= SCAN_LIST_SIZE ||
                     scan_list[current_index] ==0)
                {
                    current_page =0;
                }

                post display_list_task();
            }
            else if(current_char == '-')
            {
                if(current_page==0)
                {

                    current_page = SCAN_LIST_SIZE/SCAN_PAGE_SIZE -1;

                    for(current_page = SCAN_LIST_SIZE/SCAN_PAGE_SIZE -1;
                        current_page < SCAN_LIST_SIZE/SCAN_PAGE_SIZE; current_page--)
                    {
                        uint8_t current_index= current_page*SCAN_PAGE_SIZE;

                        if(scan_list[current_index] != 0)
                        {
                            break;
                        }
                    }

                    if(current_page >= SCAN_LIST_SIZE/SCAN_PAGE_SIZE)
                    {
                        current_page=0;
                    }
                }
                else
                {
                    current_page--;
                }
                post display_list_task();
            }
            else if ( current_char >= '0' && current_char<='9')
            {
                uint16_t channel;
                uint8_t index = current_page*SCAN_PAGE_SIZE;
                index += ((uint8_t)current_char -0x30);
                channel = scan_list[index];

                atomic
                {
                    display_free = TRUE;
                }
                display_list = FALSE;

                call FMClick.tune(channel);
                call Glcd.fill(0x00);
                call Glcd.drawTextPgm(h_for_help,0,HELP_TEXT_LINE);
            }
            else if(current_char == 'l')
            {
                atomic
                {
                    display_free = TRUE;
                }
                display_list = FALSE;
                call Glcd.fill(0x00);
                post update_channel_task();
                post update_radio_station_task();
                post update_radio_time_task();
                call Glcd.drawTextPgm(h_for_help,0,HELP_TEXT_LINE);
            }
        }
        else if(input_favorite)
        {
            if ( current_char >= '1' && current_char<='9')
            {
                uint8_t fav_pos = ((uint8_t)current_char -'0'), i;
                uint16_t channel;
                bool found =FALSE;
                channelInfo ch_info, *ch_pointer;

                ch_pointer = &ch_info;
                ch_info.frequency = 0;

                atomic
                {
                    channel = current_channel;
                }

                for(i=0; i< SCAN_LIST_SIZE;i++)
                {
                    if(scan_list[i] == channel)
                    {
                        found=TRUE;
                        break;
                    }
                }

                ch_info.quickDial = fav_pos;

                if(found)
                {
                    call Database.saveChannel(i, ch_pointer);
                }
                else
                {
                    call Database.saveChannel(0xFF, ch_pointer);
                }

                favorite_list[fav_pos] = channel;

                input_favorite=FALSE;
            }
        }
        else if(current_char == 'h' || current_char == 'H')
        {

            atomic
            {
                display_help = !display_help;
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
                call Glcd.drawTextPgm(h_for_help,0,HELP_TEXT_LINE);
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
        }
        else if(current_char == '-')
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

            memset(scan_list,0,SCAN_LIST_SIZE);

            call Database.purgeChannelList();

        }
        else if(current_char == 'l' || current_char == 'L')
        {
            post display_list_task();
        }
        else if (current_char == 'f' || current_char == 'F')
        {
            input_favorite=TRUE;
        }
        else if ( current_char >= '1' && current_char<='9')
        {
            uint8_t fav_pos = ((uint8_t)current_char -'0');
            call FMClick.tune(favorite_list[fav_pos]);
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
        uint8_t offset;
        char entry_format[35];
        char list_output[CHARS_IN_LINE*SCAN_PAGE_SIZE+1]; // +1 Nullterminator
        list_output[0] = '\0'; // set first char to null Nullterminator -> easier use of strcat

        atomic
        {
            display_free = FALSE;
            display_help = FALSE;
        }

        if(!display_list)
        {
            current_page = 0;
        }

        (void) strcpy_P(entry_format, list_entry_format);

        offset = SCAN_PAGE_SIZE*current_page;
        display_list = TRUE;
        call Glcd.fill(0x00);

        for(i=0; (i < SCAN_PAGE_SIZE )&& i+offset < SCAN_LIST_SIZE; i+=2)
        {
            char display_string[20];

            uint32_t radio_frequency = RADIO_SPACING_kHz;
            uint16_t channel = scan_list[i+offset];
            uint16_t kHz_1,kHz_2;
            uint8_t MHz_1, MHz_2;

            if(channel==0)
            {
                break;
            }

            radio_frequency *= channel;

            radio_frequency += BAND_BOTTOM_kHz;
            kHz_1 = radio_frequency%1000;
            kHz_1 /= 100;
            MHz_1 = radio_frequency/1000;

            channel = scan_list[i+offset+1];

            if(channel==0)
            {
                char half_entry_format[17];

                (void) strcpy_P(half_entry_format, list_half_entry_format);
                sprintf(display_string, half_entry_format, i, MHz_1, kHz_1);
                strcat(list_output, display_string);
                break;
            }
            else
            {
                radio_frequency = RADIO_SPACING_kHz;
                radio_frequency *= channel;
                radio_frequency += BAND_BOTTOM_kHz;
                kHz_2 = radio_frequency%1000;
                kHz_2 /= 100;
                MHz_2 = radio_frequency/1000;

                sprintf(display_string, entry_format, i, MHz_1, kHz_1, i+1, MHz_2, kHz_2);
                strcat(list_output, display_string);
            }
        }

        call Glcd.drawText(list_output,0,10);
        call Glcd.drawTextPgm(list_change_page,0,50);
    }

    void task extend_scan_list_task()
    {
        uint16_t channel;
        bool scan_running_temp;
        atomic
        {
            channel = current_channel;
            scan_running_temp = scan_running;
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

        if(scan_running_temp)
        {
            if(call FMClick.seek(TRUE) != SUCCESS)
            {
                post extend_scan_list_task();
            }
            else if(channel != 0 )
            {
                if(scan_index == 0 ||
                    (scan_index > 0 && channel != scan_list[scan_index-1]))
                {

                    channelInfo ch_info;
                    ch_info.frequency = BAND_BOTTOM_100kHz + channel;
                    call Database.saveChannel(0xFF, &ch_info);

                    scan_list[scan_index] = channel;
                    atomic
                    {
                        scan_index++;
                    }
                }
            }
        }
        else
        {
            scan_list[scan_index] = channel;
        }
    }

    void task check_in_database_task()
    {
        uint8_t i;
        uint16_t channel;

        atomic
        {
            channel = current_channel;
        }

        for(i=0; i< SCAN_LIST_SIZE;i++)
        {
            if(scan_list[i] == channel)
            {
                call Database.getChannel(i);
                break;
            }
        }
    }

    void task update_station_database()
    {
        uint16_t channel;
        uint8_t i;
        atomic
        {
            channel = current_channel;
        }

        for(i=0; i< SCAN_LIST_SIZE;i++)
        {
            if(scan_list[i] == channel)
            {
                channelInfo ch_info, *ch_pointer;
                char temp[9];
                ch_pointer = &ch_info;
                ch_info.name = temp;
                ch_info.quickDial = 0xFF;
                atomic
                {
                    (void)strcpy(ch_info.name, rds_info.radio_station);
                }

                ch_info.frequency = channel+BAND_BOTTOM_100kHz;

                call Database.saveChannel(i, ch_pointer);

                break;
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
            memset(rds_info.radio_station,'\0',RADIO_STATION_LENGTH);
            memset(rds_info.radio_text,'\0',RADIO_TEXT_LENGTH);
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
                post extend_scan_list_task();
            }
        }
        else if(display_free)
        {
            post update_radio_station_task();
            post update_radio_text_task();
            post update_channel_task();
        }

        if(!scan_running)
        {
            post check_in_database_task();
        }
    }

    async event void FMClick.rdsReceived(RDSType type, char *buf)
    {
        if(type == PS)
        {

            uint8_t diff;

            atomic
            {
                diff = strcmp(rds_info.radio_station, buf);
            }

            if(diff)
            {
                atomic
                {
                    strcpy (rds_info.radio_station, buf);
                }

                if(display_free)
                {
                    post update_radio_station_task();
                }

                post update_station_database();
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


	event void Database.receivedChannelEntry(uint8_t id, channelInfo channel)
    {
        uint16_t new_channel = channel.frequency;
        uint16_t current_channel_temp;
        new_channel-=BAND_BOTTOM_100kHz;

        atomic
        {
            current_channel_temp = current_channel;
        }

        if(current_channel_temp == new_channel)
        {
            atomic
            {
                strcpy (rds_info.radio_station, channel.name);
            }
            post update_radio_station_task();
        }

        if(channel.quickDial >0 && channel.quickDial<10)
        {
            favorite_list[channel.quickDial] = new_channel;
        }

        atomic
        {
            scan_index = id;
            current_channel=new_channel;
        }

        post extend_scan_list_task();
    }

	event void Database.savedChannel(uint8_t id, uint8_t result)
    {

    }

}
