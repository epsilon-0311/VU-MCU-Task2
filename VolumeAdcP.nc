#include "Atm1280Adc.h"

module VolumeAdcP{
    provides interface Atm1280AdcConfig;
}

implementation{
    
    /**
    * Obtain channel.
    * @return The A/D channel to use. Must be one of the ATM1280_ADC_SNGL_xxx
    *   or ATM1280_ADC_DIFF_xxx values from Atm128Adc.h.
    */
    async command uint8_t Atm1280AdcConfig.getChannel(){
        return ATM1280_ADC_SNGL_ADC2;
    }

    /**
    * Obtain reference voltage
    * @return The reference voltage to use. Must be one of the 
    *   ATM1280_ADC_VREF_xxx values from Atm1280Adc.h.
    */
    async command uint8_t Atm1280AdcConfig.getRefVoltage(){
        return ATM1280_ADC_VREF_OFF;
    }

    /**
    * Obtain prescaler value.
    * @return The prescaler value to use. Must be one of the 
    *   ATM1280_ADC_PRESCALE_xxx values from Atm1280Adc.h.
    */
    async command uint8_t Atm1280AdcConfig.getPrescaler(){
        return ATM1280_ADC_PRESCALE_2;
    }
}