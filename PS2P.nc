
#include <avr/pgmspace.h>

#define PS2P_SCANTABLE_LENGHT 68

module PS2P{
    uses interface GeneralIO as Clock;
    uses interface GeneralIO as Data;
    uses interface HplAtmegaPinChange;
    provides interface PS2;
}

implementation{

    uint16_t status =0; // data got from keyboard
    uint8_t counter =0;
    bool ignore_next=FALSE;
    bool shifted=FALSE;
    bool control_key=FALSE;

    command void PS2.init(){

        uint8_t mask = call HplAtmegaPinChange.getMask();
        mask |= (1<< PCINT23);
        call HplAtmegaPinChange.setMask(mask);

        call HplAtmegaPinChange.enable();

        call Clock.makeInput();
        call Data.makeInput();
    }

    async event void HplAtmegaPinChange.fired(){
        bool clockValue = call Clock.get();

        if(clockValue==0)
        {
            bool charData = call Data.get();

            status = (status >> 1) | (charData << 10);
            counter = (counter+1)%11;

            if(counter ==0){
                uint8_t statusTmp = (status >> 1) & 0xFF;

                if(statusTmp == 0x59 || statusTmp == 0x12) // shift pressed
                {
                  if(ignore_next)
                  {
                      shifted=FALSE;
                      ignore_next = FALSE;
                  }
                  else
                  {
                      shifted=TRUE;
                  }
                }
                else if(statusTmp == 0xE0) // Following key will be control key
                {
                    control_key=TRUE;
                }
                else if(ignore_next){ // ignoring released key
                    ignore_next = FALSE;
                    control_key=FALSE; // control key was released
                }
                else if(statusTmp == 0xF0){ // 0xF0 scan code for key released
                    ignore_next = TRUE;
                }else{

                    if(control_key)
                    {
                        if(statusTmp == 0x71) // delete pressed
                        {
                            signal PS2.receivedChar(127);
                        }
                    }
                    else
                    {
                        for(uint8_t i=0; i<PS2P_SCANTABLE_LENGHT)
                        {
                              uint8_t scan_code;
                              char char_code;

                              if(shifted) //shift is pressed
                              {
                                  scan_code = pgm_read_byte(&(shifted[i][0]));
                                  char_code = pgm_read_byte(&(shifted[i][1]));
                              }
                              else
                              {
                                  scan_code = pgm_read_byte(&(unshifted[i][0]));
                                  char_code = pgm_read_byte(&(unshifted[i][1]));
                              }

                              if(scan_code == statusTmp)
                              {
                                  signal PS2.receivedChar(char_code);
                                  break;
                              }
                          }
                    }
                }
                status=0;
            }
        }
    }
}
