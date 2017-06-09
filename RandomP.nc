module RandomP{
    uses interface Read<uint16_t>;
    uses interface Timer<TMilli> as Timer;
    provides interface Random;
    provides interface ParameterInit<uint32_t>;
}

implementation{
    
    uint16_t LFSR=1;
    
    /**
    * Shift the LFSR to the right, shifting in the LSB of the parameter. Usually
    * not called directly; use the high−level functions below.
    *
    * Returns: The bit shifted out of the LFSR.
    */
    uint8_t rand_shift(uint8_t in);

    
    /**
    * Initialize this component. Initialization should not assume that
    * any component is running: init() cannot call any commands besides
    * those that initialize other components. This command behaves
    * identically to Init.init, except that it takes a parameter.
    *
    * @param   param   the initialization parameter
    * @return          SUCCESS if initialized properly, FAIL otherwise.
    */
    command error_t ParameterInit.init(uint32_t param){
        call Timer.startPeriodic(param);
        return SUCCESS;
    }
        
    /** 
     * Produces a 32-bit pseudorandom number. 
     * @return Returns the 32-bit pseudorandom number.
     */
    async command uint32_t Random.rand32(){
        uint32_t random_value=0;
        random_value |= call Random.rand16() << 16;
        random_value |= call Random.rand16();
        return random_value;
    }

    /** 
     * Produces a 32-bit pseudorandom number. 
     * @return Returns low 16 bits of the pseudorandom number.
     */
    async command uint16_t Random.rand16(){
        uint8_t i=0;
        uint16_t random_value=0;
        
        for(i=0; i < 16; i++){
            random_value = random_value <<1;
            random_value |=rand_shift((random_value>>1)&0x01);
        }
        return random_value;
    }
    
    event void Timer.fired() {
        call Read.read();        
    }
    
    event void Read.readDone( error_t result, uint16_t val ){
        
        if(result == SUCCESS){
            rand_shift((val &0x0001));
        }
        
    }
    
    uint8_t rand_shift(uint8_t in){
        uint8_t out=0;
        
        atomic{
            asm volatile(
                "mov r16, %[input]"         "\n\t"
                "mov %[output], %A[LFSRin]" "\n\t"
                "andi %[output], 0x01"      "\n\t"
                ""                          "\n\t"
                "lsr %B[LFSRin]"            "\n\t"
                "ror %A[LFSRin]"            "\n\t"
                ""                          "\n\t"
                "andi r16, 0x01"            "\n\t"
                "swap r16"                  "\n\t"
                "lsl r16"                   "\n\t"
                "lsl r16"                   "\n\t"
                "lsl r16"                   "\n\t"
                "or  %B[LFSRin], r16"       "\n\t"
                ""                          "\n\t"
                "cpi %[output], 0x01"       "\n\t"
                "brne end"                  "\n\t"
                "ldi r16, 0x80"             "\n\t"
                "eor %B[LFSRin], r16"       "\n\t"
                "ldi r16, 0xE3"             "\n\t"
                "eor %A[LFSRin], r16"       "\n\t"
                ""                          "\n\t"
                "end:"                      "\n\t"

                : //output operand list 
                    [LFSRout] "=w" (LFSR),
                    [output] "=a" (out)
                : //input operand list
                    [LFSRin]"0" (LFSR),
                    [input] "d" (in)
                : //clobber list
                    "r16"
                    
            );
            
        }
        return out;
    }
    
}