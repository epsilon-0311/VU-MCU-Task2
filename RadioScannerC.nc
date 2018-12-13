
#include <string.h>

module RadioScannerC{
    uses interface PS2;
    uses interface Boot;
    uses interface BufferedLcd;
    uses interface FMClick;
    uses interface Read<uint16_t> as ReadVolume;
}
implementation {

    uint8_t current_line = 0;
    uint8_t char_pos =0;

    char new_char;

    event void Boot.booted(){
        call PS2.init();
        call BufferedLcd.clear();
        call BufferedLcd.forceRefresh();
        call FMClick.init();

        current_line = 0;
        char_pos = 0;
    }

    void task display_char ()
    {
        char chr[2];
        chr[1]='\0';
        atomic
        {
            chr[0] = new_char;
        }

        if(chr[0] == 127)
        {
            chr[0]= ' ';
            char_pos--;
            if(char_pos < 16)
            {
                call BufferedLcd.goTo(current_line, char_pos);
                call BufferedLcd.write(chr);
                call BufferedLcd.goTo(current_line, char_pos);
            }
            else
            {
                char_pos =0;
            }
        }
        else if(chr[0] == '\n')
        {
            char_pos =0;
            current_line++;
            current_line%=2;
            call BufferedLcd.goTo(current_line, char_pos);
        }
        else
        {

            call BufferedLcd.write(chr);
            char_pos++;
            if(char_pos > 16)
            {
                current_line++;
                current_line%=2;
            }
            char_pos%=16;
        }
        call BufferedLcd.forceRefresh();
    }

    async event void PS2.receivedChar(uint8_t chr){
        atomic
        {
            new_char = chr;
        }
        post display_char();
    }

    event void ReadVolume.readDone(error_t err, uint16_t val) {

    }
    
    event void FMClick.initDone(error_t res)
    {

    }

    async event void FMClick.tuneComplete(uint16_t channel)
    {

    }

    async event void FMClick.rdsReceived(RDSType type, char *buf)
    {

    }
}
