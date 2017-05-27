#include "scancodes.h"
#include <string.h>

#define PS2CharArraySize 67

module LunarLanderC{
  uses interface PS2;
  uses interface GeneralIOPort as CharPort;
  uses interface Boot;
  uses interface BufferedLcd;
  uses interface Score;
}
implementation {

   bool shiftPressed = FALSE;
   char player[32] ="";
   uint8_t currentChar;
   
   event void Boot.booted(){
      call CharPort.makeOutput(0xFF);
      call PS2.init();
      call BufferedLcd.clear();
      call BufferedLcd.forceRefresh();
   }
   
   task void decodeChar(){
      uint8_t chr;
      size_t len = (strlen(player) %32);
      
      atomic{
	chr = currentChar;
      }
                
      if(chr == 0x12){
	shiftPressed = !shiftPressed;
	return;
      }
      
      if(shiftPressed){
	uint8_t i=0;
	
	for(i=0; i< PS2CharArraySize; i++){
	  if(chr == pgm_read_byte_near(&(shifted[i][0]))){
	    player[len] = pgm_read_byte_near(&shifted[i][1]);
	  }
	}

      }else{
	uint8_t i=0;

	for(i=0; i< PS2CharArraySize; i++){
	  if(chr == pgm_read_byte_near(&(unshifted[i][0]))){
	    player[len] = pgm_read_byte_near(&(unshifted[i][1]));
	  }
	}
	
      }
      
      player[len+1] = '\0';
      call BufferedLcd.clear();
      call BufferedLcd.forceRefresh();
      call BufferedLcd.write(player);
      call BufferedLcd.forceRefresh();
   }
   
   async event void PS2.receivedChar(uint8_t chr){   
      
      atomic{
	currentChar = chr;
      }
      post decodeChar();
   }
}