#include "Atm1280Adc.h"

module VolumeAdcP{
    uses interface Boot;
    uses interface GeneralIO as PortF2;
}

implementation{

    event void Boot.booted(){
        PortF2.makeInput();
        
    }
}