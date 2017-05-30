configuration RandomC{
    provides interface Random;
    provides interface ParameterInit<uint32_t> as ParamInit;
}

implementation{ 
    components RandomAdcC;
    components RandomP;
    components new TimerMilliC() as Timer;
    
    Random = RandomP;
    ParamInit = RandomP;
    
    RandomP.Read -> RandomAdcC;
    RandomP.Timer -> Timer;
}