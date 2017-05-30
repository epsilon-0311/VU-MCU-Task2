#include "Atm1280Adc.h"

module RandomAdcP{
    uses interface Boot;
    uses interface GeneralIO as PortK0;
    uses interface GeneralIO as PortK1;
}

implementation{

    event void Boot.booted(){
        call PortK0.makeInput();
        call PortK1.makeInput();
    }
}