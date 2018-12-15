
#include <avr/pgmspace.h>
#include "scancodes.h"

#define PS2P_SCANTABLE_LENGHT 68

module PS2P{
    uses interface GeneralIO as Clock;
    uses interface GeneralIO as Data;
    uses interface HplAtmegaPinChange;
    provides interface PS2;
}

implementation{
    void task decrypt_char_task();

    uint16_t status =0; // data got from keyboard
    uint8_t counter =0;
    bool ignore_next=FALSE;
    bool shift_pressed=FALSE;
    bool control_key=FALSE;

    command void PS2.init(){

        uint8_t mask = call HplAtmegaPinChange.getMask();
        mask |= (1<< PCINT23);
        call HplAtmegaPinChange.setMask(mask);

        call HplAtmegaPinChange.enable();

        call Clock.makeInput();
        call Data.makeInput();
    }

    void task decrypt_char_task()
    {
        uint8_t statusTmp;

        atomic
        {
            statusTmp = (status >> 1) & 0xFF;
            status=0;
        }

        if(statusTmp == 0x59 || statusTmp == 0x12) // shift pressed
        {
          if(ignore_next)
          {
              shift_pressed=FALSE;
              ignore_next = FALSE;
          }
          else
          {
              shift_pressed=TRUE;
          }
        }
        else if(ignore_next){ // ignoring released key
            ignore_next = FALSE;
        }
        else if(statusTmp == 0xF0){ // 0xF0 scan code for key released
            ignore_next = TRUE;
        }else{

            if(statusTmp == 0x66)
            {
                signal PS2.receivedChar(127);
            }
            else
            {
                uint8_t i=0;
                for(i=0; i<PS2P_SCANTABLE_LENGHT; i++)
                {
                      uint8_t scan_code;

                      if(shift_pressed) //shift is pressed
                      {
                          scan_code = pgm_read_byte(&(shifted[i][0]));
                      }
                      else
                      {
                          scan_code = pgm_read_byte(&(unshifted[i][0]));
                      }

                      if(scan_code == statusTmp)
                      {

                          if(shift_pressed)
                          {
                              uint8_t char_code = pgm_read_byte(&(shifted[i][1]));
                              signal PS2.receivedChar(char_code);
                          }
                          else
                          {
                              uint8_t char_code = pgm_read_byte(&(unshifted[i][1]));
                              signal PS2.receivedChar(char_code);
                          }

                          break;
                      }
                  }
            }
        }
    }

    async event void HplAtmegaPinChange.fired(){
        bool clockValue = call Clock.get();

        if(clockValue==0)
        {
            bool charData = call Data.get();

            status = (status >> 1) | (charData << 10);
            counter = (counter+1)%11;

            if(counter ==0){
                post decrypt_char_task();
            }
        }
    }
}
