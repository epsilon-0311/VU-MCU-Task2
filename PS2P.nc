
#include <avr/pgmspace.h>
#include "scancodes.h"

#define PS2P_SCANTABLE_LENGHT 68
#define PS2P_LEFT_SHIFT 0x12
#define PS2P_RIGHT_SHIFT 0x59
#define PS2P_BACKSPACE 0x66
#define PS2P_KEY_RELEASED 0xF0 // 0xF0 scan code for key released


module PS2P{
    uses interface GeneralIO as Clock;
    uses interface GeneralIO as Data;
    uses interface HplAtmegaPinChange;
    uses interface Timer<TMilli> as Timeout_Timer;
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

        if(statusTmp == PS2P_RIGHT_SHIFT || statusTmp == PS2P_LEFT_SHIFT) // shift pressed
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
        else if(statusTmp == PS2P_KEY_RELEASED){
            ignore_next = TRUE;
        }
        else
        {

            if(statusTmp == PS2P_BACKSPACE) // backspace
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
        // releasing flow control
        call Clock.set();
    }

    task void start_timer_task()
    {
        call Timeout_Timer.startOneShot(5);
    }

    task void stop_timer_task()
    {
        call Timeout_Timer.stop();
    }

    async event void HplAtmegaPinChange.fired(){
        bool clockValue = call Clock.get();

        if(clockValue==0)
        {
            bool charData = call Data.get();

            status |= (charData << counter);
            counter = (counter+1)%11;

            if(counter ==0){
                // activating flow control
                call Clock.clr();
                post decrypt_char_task();
                post stop_timer_task();
            }
            else if(counter == 1)
            {
                post start_timer_task();
            }
        }
    }

    event void Timeout_Timer.fired()
    {
        // transmission timed out
        atomic
        {
            counter = 0;
            status = 0;
        }
    }
}
