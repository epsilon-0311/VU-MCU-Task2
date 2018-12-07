#include "Atm1280Adc.h"

module VolumeAdcP{
    uses interface Boot;
    uses interface GeneralIO as PortF0;
}

implementation{

    event void Boot.booted(){
        call PortF0.makeInput();
    }
}
