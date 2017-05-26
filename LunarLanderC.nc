#include "scancodes.h"
#include <string.h>

#define PS2CharArraySize 67

module LunarLanderC{
  uses interface PS2;
  uses interface GeneralIOPort as CharPort;
  uses interface Boot;
  uses interface BufferedLcd;
}
implementation {

   bool shiftPressed = FALSE;
   char outputString[64] ="";
   uint8_t lastChar;
   
   event void Boot.booted(){
      call CharPort.makeOutput(0xFF);
      call PS2.init();
      call BufferedLcd.clear();
      call BufferedLcd.forceRefresh();
   }
   
   task void decodeChar(){
      uint8_t chr;
      size_t len = strlen(outputString);
      
      atomic{
	chr = lastChar;
      }
      call CharPort.write(chr);
      if(chr == 0x12){
	shiftPressed = !shiftPressed;
	//call CharPort.toggle(0xFF);
	return;
      }
      
      if(shiftPressed){
	uint8_t i=0;
	call CharPort.write(chr);
	
	for(i=0; i< PS2CharArraySize; i++){
	  if(chr == pgm_read_byte_near(&(shifted[i][0]))){
	    outputString[len] = pgm_read_byte_near(&shifted[i][1]);
	    return;
	  }	  //pgm_read_byte_near(shifted + i)
	}

      }else{
	uint8_t i=0;

	for(i=0; i< PS2CharArraySize; i++){
	  if(chr == pgm_read_byte_near(&(unshifted[i][0]))){
	    outputString[len] = pgm_read_byte_near(&(unshifted[i][1]));
	  }
	}
	
      }
      
      outputString[len+1] = '\0';
      call BufferedLcd.clear();
      call BufferedLcd.forceRefresh();
      call BufferedLcd.write(outputString);
      call BufferedLcd.forceRefresh();
   }
   
   async event void PS2.receivedChar(uint8_t chr){   
      
      atomic{
	lastChar = chr;
      }
      post decodeChar();
   }
}