module PS2P{
  uses interface GeneralIO as Clock;
  uses interface GeneralIO as Data;
  uses interface HplAtmegaPinChange;
  uses interface Boot;
  uses interface GeneralIOPort as CharPort;
  provides interface PS2;
}

implementation{
  
  uint16_t status =0;
  uint8_t counter =0;
  
  command void PS2.init(){
      
      uint8_t mask = call HplAtmegaPinChange.getMask();
      mask |= (1<< PCINT23);
      call HplAtmegaPinChange.setMask(mask);
      
      call HplAtmegaPinChange.enable();
      
      call Clock.makeInput();
      call Data.makeInput();
      call CharPort.makeOutput(0xFF);
      
  }
  
  event void Boot.booted(){
      call PS2.init();
  }
  
  async event void HplAtmegaPinChange.fired(){
      bool clockValue = call Clock.get();
      if(clockValue==0){
	bool charData = call Data.get();
	status = (status <<1) | charData;
	counter = (counter+1)%11;
	if(counter ==0){
	  status = (status >> 2) & 0xFF;
	  call CharPort.write(status);
	  status=0;
	}

      }
      call Data.toggle();
  }

}