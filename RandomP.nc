module RandomP{
    uses interface Read<uint16_t>;
    uses interface Timer<TMilli> as Timer;
    provides interface Random;
    provides interface ParameterInit<uint32_t>;
}

implementation{
    
    uint16_t LFSR=0; 
    
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
        
    }

    /** 
     * Produces a 32-bit pseudorandom number. 
     * @return Returns low 16 bits of the pseudorandom number.
     */
    async command uint16_t Random.rand16(){
        
    }
    
    event void Timer.fired() {
        call Read.read();        
    }
    
    event void Read.readDone( error_t result, uint16_t val ){
        
        if(result == SUCCESS){
            LFSR = (LFSR << 1) +(val &1);
        }
        
    }
}