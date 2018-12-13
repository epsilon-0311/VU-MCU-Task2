
#include <avr/io.h>

typedef union __sys_conf_1_t
{
    struct
    {
        uint8_t RDSIEN : 1;
        uint8_t STCIEN : 1;
        const uint8_t Reserved_1 : 1;
        uint8_t RDS : 1;
        uint8_t DE : 1;
        uint8_t AGCD : 1;
        const uint8_t Reserved_2 : 2;
        uint8_t BLNDADJ : 2;
        uint8_t GPIO3 : 2;
        uint8_t GPIO2 : 2;
        uint8_t GPIO1 : 2;
    };
    uint8_t data_bytes[2];
} sys_conf_1_t;

typedef union __sys_conf_2_t
{
    struct
    {
        uint8_t SEEKTH : 8;
        uint8_t BAND : 2;
        uint8_t SPACE : 2;
        uint8_t VOLUME : 4;
    };
    uint8_t data_bytes[2];
} sys_conf_2_t;

typedef union __sys_conf_3
{
    struct
    {
        uint8_t SMUTER : 2;
        uint8_t SMUTEA : 2;
        const uint8_t Reserved_1 : 3;
        uint8_t VOLEXT : 1;
        uint8_t SKSNR : 4;
        uint8_t SKCNT : 4;
    };
    uint8_t data_bytes[2];
} sys_conf_3_t;

typedef union __channel
{
    struct
    {
        uint8_t TUNE : 1;
        const uint8_t Reserved_1 : 5;
        uint16_t CHANNEL : 10;
    };
    uint8_t data_bytes[2];
} channel_t;

typedef union __power_conf
{
    struct
    {
        uint8_t DSMUTE : 1;
        uint8_t DMUTE : 1;
        uint8_t MONO : 1;
        const uint8_t Reserved_1 : 1;
        uint8_t RDSM : 1;
        uint8_t SKMODE : 1;
        uint8_t SEEKUP : 1;
        uint8_t SEEK : 1;
        const uint8_t Reserved_2 : 1;
        uint8_t DISABLE : 1;
        const uint8_t Reserved_3 : 5;
        uint8_t ENABLE : 1;
    };
    uint8_t data_bytes[2];
} power_conf_t;
