#include "scancodes.h"
#include <string.h>
#include "LunarLander.h"


module LunarLanderC{
    uses interface PS2;
    uses interface GeneralIOPort as CharPort;
    uses interface Boot;
    uses interface BufferedLcd;
    uses interface Score;
    uses interface Read<uint16_t> as ReadVolume;
    uses interface ParameterInit<uint32_t> as initRandom;
    uses interface Glcd as GLCD;
    uses interface TouchScreen;
    uses interface TerrainGenerator as TG;
    
    //DEBUG
    uses interface Timer<TMilli> as DebugTimer;
    uses interface Random;
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
      call initRandom.init(1);
      call TG.startTerrainGenerator();
      
      
      
      call GLCD.fill(0x00);
      call DebugTimer.startPeriodic(1000);
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
//       call BufferedLcd.clear();
//       call BufferedLcd.forceRefresh();
//       call BufferedLcd.write(player);
//       call BufferedLcd.forceRefresh();
   }
   
   async event void PS2.receivedChar(uint8_t chr){   
      
      atomic{
	currentChar = chr;
      }
      post decodeChar();
   }
   
    event void ReadVolume.readDone(error_t err, uint16_t val) {
        
        if (err == SUCCESS) {            
//             char buffer[sizeof(uint16_t) * 4 + 1];
//             sprintf(buffer, "%d", val);
//             
//             call BufferedLcd.clear();
//             call BufferedLcd.forceRefresh();
//             call BufferedLcd.write(buffer);
//             call BufferedLcd.forceRefresh();
        }
    }
    
    event void TouchScreen.coordinatesReady(void){
    }
    
    event void TG.terrainGenerated(uint8_t *terrainSeed){
        
        uint8_t seed_counter =0;
        uint8_t x=0;
        for(seed_counter=0; seed_counter < TERRAIN_POINTS; seed_counter++){
            uint8_t x_part=0;
            uint8_t slope = (terrainSeed[seed_counter +1] - terrainSeed[seed_counter])/(16);
            
            for(x_part =0; x_part < TERRAIN_POINTS-1; x_part++){
                          
                          
//                 if(slope ==0 || x ==0){
//                     call GLCD.drawLine(x,63,x, 64-terrainSeed[seed_counter]);
//                 }else if(slope>0){
//                     call GLCD.drawLine(x,63,x, 64-(terrainSeed[seed_counter]+x_part*slope));
//                 }else if(slope <0){
//                     call GLCD.drawLine(x,63,x, 64+(terrainSeed[seed_counter] +x_part*slope));
//                 }

                uint8_t y =63-((terrainSeed[seed_counter] +(x_part*slope)));
                
                if(y <0){
                    call GLCD.drawLine(x,63,x, 0);
                }else if(y < 63) {
                    call GLCD.drawLine(x,63,x, y);
                }
                
                
                x++;
                if(x >= 128){
                    break;
                }
            }
            if(x >= 128){
                break;
            }
            //call GLCD.drawLine(x,63,x, 64-terrainSeed[seed_counter +1]);
            //x++;        
            
            
        }
        
    }
    
    
    //DEBUG
    event void DebugTimer.fired() {
        //call ReadVolume.read();  
        char buffer[sizeof(uint16_t) * 4 + 1];
        sprintf(buffer, "%d", call Random.rand16());
        call BufferedLcd.clear();
        call BufferedLcd.forceRefresh();
        call BufferedLcd.write(buffer);
        call BufferedLcd.forceRefresh();
    }
}