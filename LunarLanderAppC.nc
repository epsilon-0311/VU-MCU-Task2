#include <debug.h>
configuration LunarLanderAppC {

}

implementation {
    components LunarLanderC as LL;
    components PS2C;
    
    LL.PS2 -> PS2C;
}
