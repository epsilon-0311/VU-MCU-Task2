#include "vs1011e.h"
#define MP3_INIT 1
#define MP3_NATIVE_MODE 2
#define MP3_SEND_VOLUME 4

module VS1011eP{
    uses interface HplVS1011e;
    uses interface Boot;
    uses interface GeneralIOPort as CharPort;
    provides interface MP3;
}
implementation{
    
    uint8_t mode =0;
    
    uint8_t buffer[8];
    uint8_t bufferLen=0;
    uint16_t readBuffer=0;
   
    
    event void Boot.booted(){
        buffer[0]=0x53;
        buffer[1]=0xEF;
        buffer[2]=0x6E;
        buffer[3]=0xCC;
        buffer[4]=0x00;
        buffer[5]=0x00;
        buffer[6]=0x00;
        buffer[7]=0x00;
        
        bufferLen = 8;
        call HplVS1011e.init();
        call HplVS1011e.reset();
        
        call 
        
        call MP3.sineTest(TRUE);
        call CharPort.makeOutput(0xFF);
    }
    
    /**
    * Notification that the register write completed
    *
    * @param error SUCCESS if sending completed successfully
    */
    event void HplVS1011e.writeDone( error_t error ){
        call HplVS1011e.sendData(buffer, bufferLen);
        
    }
    
    /**
    * Notification that the register read completed
    *
    * @param error SUCCESS if successfully
    * @param value A point to a data buffer where the register content will be stored
    */
    event void HplVS1011e.readDone( error_t error, uint16_t *value){
        
        mp3_reg_t mp3_register = MODE;
        mp3_mode_t mp3_modes = SM_TESTS;
        call CharPort.set(0xFF);
        call HplVS1011e.writeRegister(mp3_register, *value | 1<< mp3_modes);
    }

    /**
    * Notification that sending data completed
    *
    * @param error SUCCESS if sending completed successfully
    */
    event void HplVS1011e.sendDone( error_t error ){
        
    }
    
    /**
        * Start and stop sine test
        *
        * @param on TRUE to start - FALSE to stop
        *
        * @return SUCCESS if command was successfully sent over SPI
        */
    command error_t MP3.sineTest(bool on){
        
        if(on == TRUE){
            mp3_reg_t mp3_register = MODE;
            call HplVS1011e.readRegister(mp3_register, &readBuffer);
        }
        
    }


    /**
        * Set volume
        *
        * @param volume Volume to be set
        *
        * @return SUCCESS if command was successfully sent over SPI
        */
    command error_t MP3.setVolume(uint8_t volume){
        
    }

    /**
        * Send data
        *
        * @param data A point to a data buffer where the data is stored
        * @param len Length of the message to be sent - data must be at least as large as len
        *
        * @return SUCCESS if request was granted and sending the data started
        */
    command error_t MP3.sendData(uint8_t *data, uint8_t len){
        
    }



    /**
        * Check if VS1011e is ready to accept new data
        *
        * @return FALSE if VS1011e is busy or sending of data is in progress - otherwise TRUE
        */
    command bool MP3.isBusy(void){
        
    }
}