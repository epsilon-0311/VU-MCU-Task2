
#include <string.h>
#include <avr/pgmspace.h>

#define SCROLL_PERIOD_MS 1500
#define VOLUME_SAMPLE_PERIOD_MS 100
#define VOLUME_SAMPLE_ARRAY_SIZE 5

#define RADIO_SPACING_kHz 100
#define BAND_TOP_100kHz 1080
#define BAND_BOTTOM_100kHz 875

#define SCAN_LIST_SIZE 32
#define SCAN_PAGE_SIZE 10

#define CHARS_IN_LINE 19

#define SCANNING_TEXT_LINE 10

#define RADIO_TIME_LINE 10
#define RADIO_STATION_LINE 20
#define RADIO_STATION_SPACER 64
#define RADIO_TEXT_LINE 30
#define RADIO_NOTE_LINE 40
#define HELP_TEXT_LINE 60

#define ADD_NOTE_LINE 10
#define ADD_NOTE_PRESS_ENTER_LINE 20
#define INPUT_NOTE_LINE 30

#define FREQUENCY_LINE 10
#define INPUT_FREQUENCY_PRESS_ENTER_LINE 30
#define INPUTE_FREQUENCY_LINE 40
#define INPUT_FRQUENCY_ERROR_LINE 50

#define RADIO_TEXT_LENGTH 64
#define RADIO_STATION_LENGTH 8
#define RADIO_NOTE_LENGTH 40
#define FREQUENCY_INPUT_LENGTH 5

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

typedef enum __display_state
{
    DISPLAY_FREE,
    DISPLAY_HELP,
    DISPLAY_LIST,
    INPUT_FAVORITE,
    INPUT_NOTE,
    INPUT_FREQUENCY,
    SCANNING,
} DisplayState_t;

module RadioScannerC{
    uses interface PS2;
    uses interface Boot;
    uses interface BufferedLcd;
    uses interface FMClick;
    uses interface Init as FMClick_init;
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

    uint16_t favorite_list[FAVORITE_LIST_LENGTH+1];

    char note[RADIO_NOTE_LENGTH+1];
    uint8_t current_note_index;

    char frequency_string[FREQUENCY_INPUT_LENGTH];

    DisplayState_t current_display_state;
    rds_info_t rds_info;

    char const PROGMEM date_time_format[] = "%2d.%2d.%4u %02d:%02d";
    char const PROGMEM station_format[] = "%3u.%1u MHz:";
    char const PROGMEM empty_line[] = "                   ";
    char const PROGMEM empty_half_line[] = "          ";
    char const PROGMEM h_for_help[] = "h to toggle help";
    char const PROGMEM help_string[] =  "n/p switch channel\n+/- step\nt   tune to channel\nl   toggle list\ns   scan\nf   add favorite\na   add note";
    char const PROGMEM volume_text[] = "Volume:%2u";
    char const PROGMEM list_entry_format[] = "%1u:%3u.%1u  | %1u:%3u.%1u \n";
    char const PROGMEM list_half_entry_format[] = "%1u:%3u.%1u\n";
    char const PROGMEM list_change_page[] = "+/- to change page\n[0-9] tune channel";
    char const PROGMEM add_note_text[] = "Add Note";
    char const PROGMEM input_frequency_text[] = "Input Frequency\nExample: 88.6 105.3";
    char const PROGMEM press_enter_text[] = "Press enter to save";
    char const PROGMEM format_not_satisfied[] = "Input format wrong";
    char const PROGMEM out_of_range[] = "Input out of range";
    char const PROGMEM scanning_channels[] = "Scanning Channels";


    task void display_list_task();
    task void input_note_task();
    task void input_frquency_task();
    task void update_station_database();

    void update_displays(void);
    bool handle_display_states(char current_char);
    void handle_display_list(char current_char);
    void handle_input_favorite(char current_char);
    void handle_input_note(char current_char);
    void handle_input_frequency(char current_char);
    void handle_help(void);
    void handle_new_note(void);
    void handle_new_frequency(void);

    event void Boot.booted(){
        call PS2.init();
        call BufferedLcd.clear();
        call BufferedLcd.forceRefresh();
        call FMClick_init.init();
        call Glcd.fill(0x00);
        call Scroll_Timer.startPeriodic(SCROLL_PERIOD_MS);
        call Volume_Timer.startPeriodic(VOLUME_SAMPLE_PERIOD_MS);
        call Database.getChannelList(0);

        current_radio_text_index=0;

        atomic
        {
            current_display_state = DISPLAY_FREE;
            rds_info.radio_text[0]='\0';
            memset(favorite_list,0,FAVORITE_LIST_LENGTH);
        }

        update_displays();
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

        call Glcd.drawText(date_string,0,RADIO_TIME_LINE);
    }

    void task update_channel_task()
    {
        char display_string[20];
        char display_string_2[20];

        uint16_t radio_frequency = BAND_BOTTOM_100kHz;
        uint16_t kHz;
        uint8_t MHz;

        (void) strcpy_P(display_string, station_format);

        atomic
        {
            radio_frequency += current_channel;
        }

        kHz = radio_frequency%10;
        MHz = radio_frequency/10;

        sprintf(display_string_2, display_string, MHz, kHz);

        call Glcd.drawText(display_string_2,0,RADIO_STATION_LINE);

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
            call Glcd.drawTextPgm(empty_half_line,64,RADIO_STATION_LINE);
        }
        else
        {
            call Glcd.drawText(station_string,64,RADIO_STATION_LINE);
        }
    }

    void task update_radio_text_task ()
    {
        char radio_text[CHARS_IN_LINE+1];
        atomic
        {
            (void)strncpy(radio_text, &(rds_info.radio_text[current_radio_text_index]), 19);
        }

        radio_text[19] = '\0';
        if(strlen(radio_text)<19 || radio_text[0] == '\0')
        {
            call Glcd.drawTextPgm(empty_line,0,RADIO_TEXT_LINE);
            current_radio_text_index=0;
        }
        else
        {
            current_radio_text_index++;
        }
        call Glcd.drawText(radio_text,0,RADIO_TEXT_LINE);
    }

    void task update_note_task ()
    {
        char note_output[CHARS_IN_LINE+1];
        atomic
        {
            (void)strncpy(note_output, &(note[current_note_index]), 19);
        }

        note_output[CHARS_IN_LINE] = '\0';
        if(strlen(note_output)<19 || note_output[0] == '\0')
        {
            call Glcd.drawTextPgm(empty_line,0,RADIO_NOTE_LINE);
            current_note_index=0;
        }
        else
        {
            current_note_index++;
        }

        call Glcd.drawText(note_output,0,RADIO_NOTE_LINE);
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

        if(handle_display_states(current_char))
        {
            return;
        }
        else if(current_char == 'h' || current_char == 'H')
        {
            handle_help();
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
                current_display_state = SCANNING;
            }

            memset(scan_list,0,SCAN_LIST_SIZE);
            call Glcd.fill(0x00);
            call Glcd.drawTextPgm(scanning_channels, 0, SCANNING_TEXT_LINE);
            call Database.purgeChannelList();
        }
        else if(current_char == 'l' || current_char == 'L')
        {
            post display_list_task();
        }
        else if (current_char == 'f' || current_char == 'F')
        {
            atomic
            {
                current_display_state = INPUT_FAVORITE;
            }
        }
        else if ( current_char >= '1' && current_char<='9')
        {
            // tune to favorite station
            uint8_t fav_pos = ((uint8_t)current_char -'0');
            call FMClick.tune(favorite_list[fav_pos]);
        }
        else if(current_char == 'a' || current_char == 'A')
        {
            handle_new_note();
        }
        else if(current_char == 't' || current_char == 'T')
        {
            handle_new_frequency();
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

        if(current_display_state != DISPLAY_LIST)
        {
            current_page = 0;
        }

        (void) strcpy_P(entry_format, list_entry_format);

        offset = SCAN_PAGE_SIZE*current_page;

        atomic
        {
            current_display_state = DISPLAY_LIST;
        }

        call Glcd.fill(0x00);

        for(i=0; (i < SCAN_PAGE_SIZE )&& i+offset < SCAN_LIST_SIZE; i+=2)
        {
            char display_string[20];

            uint32_t radio_frequency = BAND_BOTTOM_100kHz;
            uint16_t channel = scan_list[i+offset];
            uint16_t kHz_1,kHz_2;
            uint8_t MHz_1, MHz_2;

            if(channel==0)
            {
                break;
            }

            radio_frequency += channel;
            kHz_1 = radio_frequency%10;
            MHz_1 = radio_frequency/10;

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
                radio_frequency = BAND_BOTTOM_100kHz;
                radio_frequency += channel;
                kHz_2 = radio_frequency%10;
                MHz_2 = radio_frequency/10;

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
                char temp[RADIO_STATION_LENGTH+1];
                char note_temp[RADIO_NOTE_LENGTH+1];
                ch_pointer = &ch_info;
                ch_info.name = temp;
                ch_info.notes = note_temp;
                ch_info.quickDial = 0xFF;
                atomic
                {
                    (void)strcpy(ch_info.name, rds_info.radio_station);
                }

                ch_info.frequency = channel+BAND_BOTTOM_100kHz;

                strcpy(ch_info.notes, note);

                call Database.saveChannel(i, ch_pointer);

                break;
            }
        }
    }

    task void input_note_task()
    {
        static uint8_t length_last = 0;

        uint8_t length = strlen(note);

        if(length <=CHARS_IN_LINE)
        {
            if(length < length_last)
            {
                note[length] = ' ';
            }

            call Glcd.drawText(note,0,INPUT_NOTE_LINE);

            if(length < length_last)
            {
                note[length] = '\0';
            }
        }
        else
        {
            char temp[CHARS_IN_LINE+1];

            length -= CHARS_IN_LINE;
            (void)strncpy(temp, &(note[length]), 19);
            call Glcd.drawText(temp,0,INPUT_NOTE_LINE);
        }
        length_last = strlen(note);
    }

    task void input_frquency_task()
    {
        static uint8_t length_last = 0;

        uint8_t length = strlen(frequency_string);

        if(length < length_last)
        {
            frequency_string[length] = ' ';
        }

        call Glcd.drawText(frequency_string,0,INPUTE_FREQUENCY_LINE);

        if(length < length_last)
        {
            frequency_string[length] = '\0';
        }

        length_last = strlen(frequency_string);
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
        call FMClick.seek(TRUE);
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
            memset(note, '\0', RADIO_NOTE_LENGTH);
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
        else if(current_display_state == DISPLAY_FREE)
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

                if(current_display_state == DISPLAY_FREE)
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

            if(current_display_state == DISPLAY_FREE)
            {
                post update_radio_time_task();
            }
        }
    }

    event void Scroll_Timer.fired()
    {
        if(current_display_state == DISPLAY_FREE)
        {
            post update_radio_text_task();
            post update_note_task();
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
                strcpy (note, channel.notes);
            }

            if(current_display_state == DISPLAY_FREE)
            {
                post update_note_task();
                post update_radio_station_task();
            }
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

    void update_displays(void)
    {
        post update_channel_task();
        post update_radio_station_task();
        post update_radio_text_task();
        post update_radio_time_task();
        post update_note_task();
        
    }

    bool handle_display_states(char current_char)
    {
        bool display_state_handled = current_display_state != DISPLAY_FREE;
       
        if(current_display_state == DISPLAY_LIST)
        {
            handle_display_list(current_char);
        }
        else if(current_display_state == INPUT_FAVORITE)
        {   
            handle_input_favorite(current_char);
        }
        else if(current_display_state == INPUT_NOTE)
        {
            handle_input_note(current_char);
        }
        else if(current_display_state == INPUT_FREQUENCY)
        {
            handle_input_frequency(current_char);
        }

        return display_state_handled;
    }

    void handle_display_list(char current_char)
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
                current_display_state = DISPLAY_FREE;
            }

            call FMClick.tune(channel);
            call Glcd.fill(0x00);
            call Glcd.drawTextPgm(h_for_help,0,HELP_TEXT_LINE);
            update_displays();
        }
        else if(current_char == 'l')
        {
            atomic
            {
                current_display_state = DISPLAY_FREE;
            }

            call Glcd.fill(0x00);
            update_displays();
            call Glcd.drawTextPgm(h_for_help,0,HELP_TEXT_LINE);
        }
    }

    void handle_input_favorite(char current_char)
    {
        // 0 adds channel to db
        // 1-9 adds channel to favorites
        if ( current_char >= '0' && current_char<='9')
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

            if(fav_pos > 0)
            {
                favorite_list[fav_pos] = channel;
            }

            atomic
            {
                current_display_state = DISPLAY_FREE;
            }
        }
    }

    void handle_input_note(char current_char)
    {
        if(current_char == '\n')
        {
            atomic
            {
                current_display_state = DISPLAY_FREE;
            }

            call Glcd.fill(0x00);

            update_displays();

            post update_station_database();

        }
        else if(current_char >= ' ' && current_char < 127) // 127 == delete char
        {
            uint8_t length = strlen(note);
            if(length < RADIO_NOTE_LENGTH)
            {
                note[length] = current_char;
                note[length+1] = '\0';
                post input_note_task();
            }
        }
        else if(current_char == 127) // == delete char
        {
            uint8_t length = strlen(note);

            if(length > 0)
            {
                note[length-1] = '\0';
                post input_note_task();
            }
        }
    }

    void handle_input_frequency(char current_char)
    {
        if(current_char == '\n')
        {
            bool seperator_found =FALSE;
            bool format_wrong = FALSE;
            bool added_100khz = FALSE;

            uint8_t i;
            uint16_t channel=0;

            for(i=0; i< strlen(frequency_string); i++)
            {
                char curr = frequency_string[i];

                if(curr >= '0' && curr <= '9')
                {
                    if(!seperator_found)
                    {
                        channel *= 10;
                    }
                    else
                    {
                        if(added_100khz)
                        {
                            format_wrong = TRUE;
                            break;
                        }
                        added_100khz = TRUE;
                    }
                    channel += (uint8_t) curr - '0';
                }
                else if(curr =='.')
                {
                    if(seperator_found)
                    {
                        format_wrong = TRUE;
                        break;
                    }
                    else
                    {
                        seperator_found=TRUE;
                    }
                }
                else
                {
                    format_wrong = TRUE;
                    break;
                }
            }

            if(format_wrong)
            {
                call Glcd.drawTextPgm(format_not_satisfied,0,INPUT_FRQUENCY_ERROR_LINE);
                return;
            }

            if(! seperator_found)
            {
                channel *= 10;
            }

            if(channel < BAND_BOTTOM_100kHz || channel > BAND_TOP_100kHz)
            {
                call Glcd.drawTextPgm(out_of_range,0,INPUT_FRQUENCY_ERROR_LINE);
                return;
            }

            channel -= BAND_BOTTOM_100kHz;

            atomic
            {
                current_display_state = DISPLAY_FREE;
            }

            call Glcd.fill(0x00);
            update_displays();
            call FMClick.tune(channel);
        }
        else if((current_char >= '0' && current_char <='9') || current_char == '.') // 127 == delete char
        {
            uint8_t length = strlen(frequency_string);
            if(length < FREQUENCY_INPUT_LENGTH)
            {
                frequency_string[length] = current_char;
                frequency_string[length+1] = '\0';

                post input_frquency_task();
            }
        }
        else if(current_char == 127) // == delete char
        {
            uint8_t length = strlen(note);

            if(length > 0)
            {
                note[length-1] = '\0';
                post input_frquency_task();
            }
        }
    }

    void handle_help(void)
    {
        call Glcd.fill(0x00);

        if(current_display_state != DISPLAY_HELP)
        {
            atomic
            {
                current_display_state = DISPLAY_HELP;
            }
            post display_help_task();
        }
        else
        {
            atomic
            {
                current_display_state = DISPLAY_FREE;
            }

            current_radio_text_index = 0;
            update_displays();

            call Glcd.drawTextPgm(h_for_help,0,HELP_TEXT_LINE);
        }
    }

    void handle_new_note(void)
    {
        atomic
        {
            current_display_state = INPUT_NOTE;
        }

        call Glcd.fill(0x00);
        call Glcd.drawTextPgm(add_note_text,0,ADD_NOTE_LINE);
        call Glcd.drawTextPgm(press_enter_text,0,ADD_NOTE_PRESS_ENTER_LINE);

        post input_note_task();
    }

    void handle_new_frequency(void)
    {
        atomic
        {
            current_display_state = INPUT_FREQUENCY;
        }

        call Glcd.fill(0x00);
        call Glcd.drawTextPgm(input_frequency_text,0,FREQUENCY_LINE);
        call Glcd.drawTextPgm(press_enter_text,0,INPUT_FREQUENCY_PRESS_ENTER_LINE);

        post input_frquency_task();
    }
}
