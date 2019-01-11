#include "udp_config.h"
#include "Database.h"
#include "string.h"
#include <avr/pgmspace.h>

#define MAX_ENTRIES 16
#define MAX_FAVORITES 9

module DatabaseP{
    uses interface Boot;
    uses interface UdpSend as UdpSend;
    uses interface UdpReceive as UdpReceive;
    uses interface SplitControl as Control;
    uses interface IpControl;
    uses interface Queue<udp_msg_t *> as MsgQueue;
    uses interface Queue<uint16_t> as LenQueue;
    uses interface Queue<Database_operation_t> as OpQueue;
    uses interface Pool<udp_msg_t> as MsgPool;

    uses interface GeneralIOPort as debug_out_3;
    uses interface BufferedLcd;


    provides interface Database;
}

implementation {

	void enqueueMsg(char* data);
    void enqueuePgmMsg(const char *text);
    void decode_ids(const char *text);
    void decode_radio_info(char *text);

    void task send_task();
    void task retrieve_list_data_task();

    in_addr_t destination = { .bytes {DESTINATION}};
    /* Database_operation_t current_op; */

    const char PROGMEM error_string[] = "err\r";
    const char PROGMEM ok_string[] = "ok\r";
    const char PROGMEM purgeall_string[] = "purgeall\n";
    const char PROGMEM add_format_string[] = "add\r";
    const char PROGMEM update_format_string[] = "update\r";
    const char PROGMEM list_stations_string[] = "list\r\n";
    const char PROGMEM list_favorites_string[] = "list\rqdial=1\n";
    const char PROGMEM get_entry_format_string[] = "get\rid=%u\n";
    const char PROGMEM radio_info_key_id[] = "id=";
    const char PROGMEM radio_info_key_name[] = "name=";
    const char PROGMEM radio_info_key_note[] = "note=";
    const char PROGMEM radio_info_key_frequency[] = "freq=";
    const char PROGMEM radio_info_key_qdial[] = "qdial=";


	bool sendBusy = FALSE;

    uint8_t db_index;
    uint8_t db_ids[MAX_ENTRIES];
    uint8_t db_favorite_ids[MAX_FAVORITES];

    event void Boot.booted() {

        in_addr_t cip = { .bytes {IP}};
		in_addr_t cnm = { .bytes {NETMASK}};
		in_addr_t cgw = { .bytes {GATEWAY}};

		call IpControl.setIp(&cip);
		call IpControl.setNetmask(&cnm);
		call IpControl.setGateway(&cgw);

		call Control.start();
	}

    event void Control.stopDone(error_t error)
    {

    }

    event void Control.startDone(error_t error)
    {

    }

    event void UdpSend.sendDone(error_t error)
    {
        sendBusy = FALSE;
        call MsgPool.put(call MsgQueue.dequeue());       // "free" memory
		call LenQueue.dequeue();

        if(! call MsgQueue.empty())
        {
            post send_task();
        }

    }

    event void UdpReceive.received(in_addr_t *srcIp, uint16_t srcPort, uint8_t *data, uint16_t len)
    {
        char return_data[len];
        uint16_t current_op = call OpQueue.dequeue();

        memcpy(return_data, data, len);

        if(strncmp_P(return_data, error_string, 4) == 0)
        {
            switch(current_op)
            {
                case DATABASE_ADD:
                    break;
                case DATABASE_UPDATE:
                    break;
                case DATABASE_DELETE:
                    break;
                case DATABASE_LIST:
                    break;
                case DATABASE_GET_LIST:
                    break;
                case DATABASE_LIST_FAVORITES:
                    break;
                case DATABASE_GET:
                    break;
                case DATABASE_PURGEALL:
                    enqueuePgmMsg(purgeall_string);
                    call OpQueue.enqueue(DATABASE_PURGEALL);
                    post send_task();
                    break;
            }
        }
        else if(strncmp_P(return_data, ok_string, 3) == 0)
        {

            switch(current_op)
            {
                case DATABASE_ADD:
                    break;
                case DATABASE_UPDATE:
                    break;
                case DATABASE_DELETE:
                    break;
                case DATABASE_GET_LIST:
                    decode_radio_info(return_data);

                    post retrieve_list_data_task();
                    break;
                case DATABASE_LIST:
                    decode_ids(return_data);
                    post retrieve_list_data_task();
                    break;
                case DATABASE_LIST_FAVORITES:
                    break;
                case DATABASE_GET:
                    decode_radio_info(return_data);

                    break;
                case DATABASE_PURGEALL:
                    break;
                default:
                    break;
            }
        }
    }

    void task send_task()
    {
        if(!sendBusy && ! call MsgQueue.empty())
        {
            udp_msg_t* outData = call MsgQueue.head();
            uint16_t outLen = call LenQueue.head();
            if (call UdpSend.send(&destination, UDP_PORT, outData->data, outLen) == SUCCESS) {
                sendBusy = TRUE;
            }
        }
        else if(! call MsgQueue.empty())
        {
            post send_task();
        }
    }

    void task retrieve_list_data_task()
    {
        if(db_ids[db_index] == 0xFF)
        {
            db_index=0;
            return;
        }
        else
        {
            uint8_t length = strlen_P(get_entry_format_string);
            char get_format[length];
            char get_string[length+3]; // max 3 chars longer

            strcpy_P(get_format, get_entry_format_string);
            sprintf(get_string, get_format, db_ids[db_index]);
            enqueueMsg(get_string);
            db_index++;

            call OpQueue.enqueue(DATABASE_GET_LIST);

            post send_task();
        }

    }

    /**
     * Save a new channel, or change properties of an existing one.
     * @param id The channel index from the database store, 0xFF to autoselect,
     *           must be between 0 and 15 if passed manually
     * @param channel The channel information, see channelInfo typedef
     */
    command void Database.saveChannel(uint8_t id, channelInfo *channel)
    {
        char message[MAX_MSG_LEN];
        /* char station[9];
        strcpy(station, channel->name); */

        if(id == 0xFF)
        {
            strcpy_P(message, add_format_string);
            call OpQueue.enqueue(DATABASE_ADD);
        }
        else
        {
            char id_buffer [3];

            strcpy_P(message, update_format_string);
            strcat_P(message, radio_info_key_id);

            itoa (id,id_buffer,10);
            strcat(message, id_buffer);
            strcat(message, ",");

            call OpQueue.enqueue(DATABASE_UPDATE);
        }

        if(channel->frequency >0)
        {
            char freq_buffer [5];
            strcat_P(message, radio_info_key_frequency);
            itoa (channel->frequency,freq_buffer,10);
            strcat(message, freq_buffer);
            strcat(message, ",");
        }

        if(strlen(channel->name) > 0)
        {
            uint8_t i=strlen(channel->name)-1;
            strcat_P(message, radio_info_key_name);

            for(; i<8; i++)
            {
                channel->name[i] = ' ';
            }
            channel->name[8] = '\0';

            strcat(message, channel->name);

            strcat(message, ",");
        }

        if(channel->quickDial > 0 && channel->quickDial < 10)
        {
            char qdial_buffer [2];
            strcat_P(message, radio_info_key_qdial);
            itoa (channel->quickDial,qdial_buffer,10);
            strcat(message, qdial_buffer);
            strcat(message, ",");
        }


        //has to be last entry
        if(strlen(channel->notes) > 0)
        {
            strcat_P(message, radio_info_key_note);
            strcat(message, channel->notes);
        }

        strcat(message, "\n");
        enqueueMsg(message);
        post send_task();
    }


    /**
     * Request the channel list from the database server
     * Received channels will be signaled through receivedChannelEntry
     * @param onlyFavorites tells server to send only the channels with a
     *        registered quickDial number, if not zero
     */
    command void Database.getChannelList(uint8_t onlyFavorites)
    {
        if(onlyFavorites)
        {
            enqueuePgmMsg(list_favorites_string);
            call OpQueue.enqueue(DATABASE_LIST_FAVORITES);
        }
        else
        {
            enqueuePgmMsg(list_stations_string);
            call OpQueue.enqueue(DATABASE_LIST);

        }

        post send_task();
    }

    /**
     * Request the channel list from the database server
     * Received channels will be signaled through receivedChannelEntry
     */
    command void Database.getChannel(uint8_t id)
    {
        uint8_t length = strlen_P(get_entry_format_string);
        char get_format[length];
        char get_string[length+5];

        call debug_out_3.toggle(0xFF);

        strcpy_P(get_format, get_entry_format_string);
        sprintf(get_string, get_format, id);

        enqueueMsg(get_string);
        call OpQueue.enqueue(DATABASE_GET);

        post send_task();
    }

    /**
     * Request that the Database purges all channels and their state
     * Received channels will be signaled through receivedChannelEntry
     */
    command void Database.purgeChannelList()
    {

        enqueuePgmMsg(purgeall_string);
        call OpQueue.enqueue(DATABASE_PURGEALL);

        post send_task();
    }

    void enqueueMsg(char* data) {
        uint8_t length = strlen(data);
		udp_msg_t* queueData = call MsgPool.get(); // allocate memory
		memcpy(queueData->data, data, length);

		call MsgQueue.enqueue(queueData);
		call LenQueue.enqueue(length);
	}

    void enqueuePgmMsg(const char *text) {
        uint16_t length = strlen_P(purgeall_string);
		udp_msg_t* queueData = call MsgPool.get(); // allocate memory
		memcpy_P(queueData->data, text, length);

		call MsgQueue.enqueue(queueData);
		call LenQueue.enqueue(length);
	}

    void decode_ids(const char *data)
    {
        uint8_t i=0, state=0, current_int=0;
        uint8_t len = strlen(data);
        db_index=0;

        for(i=0;i<len; i++)
        {
            if(data[i] == '\r' || data[i] == '\n')
            {
                if(state != 0)
                {
                    db_ids[db_index] = current_int;
                    db_index++;
                    break;
                }
                state = 1;

            }
            else if(data[i] == ',')
            {
                db_ids[db_index] = current_int;
                db_index++;
                current_int=0;
            }
            else if(data[i] >= '0' && data[i] <= '9')
            {
                current_int *= 10;
                current_int += (uint8_t)(data[i]-'0');
            }
        }

        db_ids[db_index] = -1;
        db_index=0;
    }

    void decode_radio_info(char *text)
    {
        char *token;
        uint8_t i, id=0;
        channelInfo ch_info;
        ch_info.frequency = 0;
        ch_info.quickDial = 0;
        token = strtok(text, "\r");
        token = strtok(NULL, "\r");
        token = strtok(token, ",");

        while(token!= NULL)
        {
            if(0 == strncmp_P(token, radio_info_key_id, strlen_P(radio_info_key_id)))
            {
                uint8_t current_int=0;
                for(i = strlen_P(radio_info_key_id); i < strlen(token); i++)
                {
                    if(token[i] >= '0' && token[i] <= '9')
                    {
                        current_int *= 10;
                        current_int += (uint8_t)(token[i]-'0');
                    }
                }
                id = current_int;
            }
            else if(0 == strncmp_P(token, radio_info_key_name, strlen_P(radio_info_key_name)))
            {
                char name[9];
                ch_info.name = name ;
                strcpy(ch_info.name, &(token[strlen_P(radio_info_key_name)]));
                ch_info.name[8]='\0';
            }
            else if(0 == strncmp_P(token, radio_info_key_note, strlen_P(radio_info_key_note)))
            {
                char note[40];
                uint8_t length;
                char *pch;

                ch_info.notes = note ;
                strncpy(ch_info.notes, &(token[strlen_P(radio_info_key_note)]), 40);
                length = strlen(ch_info.notes);

                pch=strchr(ch_info.notes,'\n');

                if(pch != NULL)
                {
                    uint8_t end = pch-ch_info.notes;
                    ch_info.notes[end]='\0';
                }
                else
                {
                    ch_info.notes[40]='\0';
                }
            }
            else if(0 == strncmp_P(token, radio_info_key_frequency, strlen_P(radio_info_key_frequency)))
            {
                uint16_t current_int=0;

                for(i = strlen_P(radio_info_key_frequency); i < strlen(token); i++)
                {
                    if(token[i] >= '0' && token[i] <= '9')
                    {
                        current_int *= 10;
                        current_int += (uint8_t)(token[i]-'0');
                    }
                }
                ch_info.frequency = current_int;
            }
            else if(0 == strncmp_P(token, radio_info_key_qdial, strlen_P(radio_info_key_qdial)))
            {
                uint8_t current_int=0;
                for(i = strlen_P(radio_info_key_qdial); i < strlen(token); i++)
                {
                    if(token[i] >= '0' && token[i] <= '9')
                    {
                        current_int = (uint8_t)(token[i]-'0');
                        break;
                    }
                }

                ch_info.quickDial = current_int;
            }

            token = strtok(NULL, ",");
        }

        signal Database.receivedChannelEntry(id, ch_info);
    }
}
