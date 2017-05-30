#include "Atm1280Adc.h"

module VolumeAdcP{
    uses interface Boot;
    uses interface GeneralIO as PortK0;
    uses interface GeneralIO as PortK1;
}

implementation{

    event void Boot.booted(){
        PortK0.makeInput();
        PortK1.makeInput();
    }
}