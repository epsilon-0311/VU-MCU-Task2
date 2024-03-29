
#ifndef __FM_CLICK_H__
#define __FM_CLICK_H__

#include <avr/io.h>

#define DEVICE_ADDRESS 0x10

#define RDS_TYPE_TUNING 0x0
#define RDS_TYPE_RADIO_TEXT 0x2
#define RDS_TYPE_TIME 0x4

#define RDS_ALLOWED_ERRORS 2 
// 0: No Errors allowd
// 1: 1-2 Errors, correctable
// 2: 3-5 Errors, correctable
// 3: 6+ Error, uncorrectable, dont use!!!

#define RDS_STATION_LENGTH 8
#define RDS_TEXT_LENGTH_A 64
#define RDS_TEXT_LENGTH_B 32

#define START_YEAR 2019
#define MJD_1ST_JANUARY_2019 58484u
#define LEAP_YEAR_DISTANCE 4
#define NEXT_LEAP_YEAR 1
#define DAYS_IN_YEAR 365
#define DAYS_IN_LEAP_YEAR 366
#define MONTHS_IN_YEAR 12
#define LEAP_MONTH 1 // starting at 0
#define LEAP_MONTH_DAYS 29

#define TIME_OFFSET_MINUTES 30
#define MAX_MINUTES 59
#define MAX_HOUR 23
#define MAX_DAYS_IN_MONTH 31

#define TOLERANCE_HOURS 1
#define TOLERANCE_MINUTES 10
#define TOLERANCE_YEARS 1
#define TOLERANCE_MONTHS 1
#define TOLERANCE_DAYS 1

typedef union __sys_conf_1_t
{
    struct
    {
        const uint8_t Reserved_2    : 2; // Bits 8:9
        uint8_t AGCD                : 1; // Bit 10
        uint8_t DE                  : 1; // Bit 11
        uint8_t RDS                 : 1; // Bit 12
        const uint8_t Reserved_1    : 1; // Bit 13
        uint8_t STCIEN              : 1; // Bit 14
        uint8_t RDSIEN              : 1; // Bit 15
        uint8_t GPIO1               : 2; // Bits 0:1
        uint8_t GPIO2               : 2; // Bits 2:3
        uint8_t GPIO3               : 2; // Bits 4:5
        uint8_t BLNDADJ             : 2; // Bits 6:7
    };
    uint8_t data_bytes[2];
} sys_conf_1_t;

typedef union __sys_conf_2_t
{
    struct
    {
        uint8_t SEEKTH              : 8; // Bits 8:15
        uint8_t VOLUME              : 4; // Bits 0:3
        uint8_t SPACE               : 2; // Bits 4:5
        uint8_t BAND                : 2; // Bits 6:7
    };
    uint8_t data_bytes[2];
} sys_conf_2_t;

typedef union __sys_conf_3
{
    struct
    {
        uint8_t VOLEXT              : 1; // Bit 8
        const uint8_t Reserved_1    : 3; // Bits 9:11
        uint8_t SMUTEA              : 2; // Bits 12:13
        uint8_t SMUTER              : 2; // Bits 14:15
        uint8_t SKCNT               : 4; // Bits 0:3
        uint8_t SKSNR               : 4; // Bits 4:7
    };
    uint8_t data_bytes[2];
} sys_conf_3_t;

typedef union __channel
{
    struct
    {
        // Channel split for serialization
        uint8_t CHANNEL_H           :  2; // Bits 8:9
        const uint8_t Reserved_1    :  5; // Bits 10:14
        uint8_t TUNE                :  1; // Bit 15
        uint8_t CHANNEL_L           :  8; // Bits 0:7
    };
    uint8_t data_bytes[2];
} channel_t;

typedef union __power_conf
{
    struct
    {
        uint8_t SEEK                : 1; // Bit 8
        uint8_t SEEKUP              : 1; // Bit 9
        uint8_t SKMODE              : 1; // Bit 10
        uint8_t RDSM                : 1; // Bit 11
        const uint8_t Reserved_1    : 1; // Bit 12
        uint8_t MONO                : 1; // Bit 13
        uint8_t DMUTE               : 1; // Bit 14
        uint8_t DSMUTE              : 1; // Bit 15
        uint8_t ENABLE              : 1; // Bit 0
        const uint8_t Reserved_3    : 5; // Bits 1:5
        uint8_t DISABLE             : 1; // Bit 6
        const uint8_t Reserved_2    : 1; // Bit 7
    };
    uint8_t data_bytes[2];
} power_conf_t;

typedef union __test_1
{
    struct
    {
        uint8_t Reserved_1    : 6; // Bits 8:13
        uint8_t AHIZEN        : 1; // Bit 14
        uint8_t XOSCEN        : 1; // Bit 15
        uint8_t Reserved_2    : 8; // Bits 0:7
    };
    uint8_t data_bytes[2];
} test_1_t;

typedef union __rssi_status
{
    struct
    {
        uint8_t ST      : 1; // Bit 8
        uint8_t BLERA   : 2; // Bit 9:10
        uint8_t RDSS    : 1; // Bit 11
        uint8_t AFCRL   : 1; // Bit 12
        uint8_t SF_BL   : 1; // Bit 13
        uint8_t STC     : 1; // Bit 14
        uint8_t RDSR    : 1; // Bit 15
        uint8_t RSSI    : 8; // Bits 0:7
    };
    uint8_t data_bytes[2];
} rssi_status_t;

typedef union __read_chan
{
    struct
    {
        uint8_t CHANNEL_H   : 2; // Bits 8:9
        uint8_t BLERB       : 2; // Bits 10:11
        uint8_t BLERC       : 2; // Bits 12:13
        uint8_t BLERD       : 2; // Bits 14:15
        uint8_t CHANNEL_L   : 8; // Bits 0:7
    };
    uint8_t data_bytes[2];
} read_chan_t;

typedef union __rds
{
    uint16_t data;
    uint8_t data_bytes[2];
} rds_t;

typedef union __conf_registers
{
    struct
    {
        power_conf_t power_conf;
        channel_t channel;
        sys_conf_1_t system_configuration_1;
        sys_conf_2_t system_configuration_2;
        sys_conf_3_t system_configuration_3;
        test_1_t test1;
    };
    uint8_t data_bytes[12];

} conf_registers_t;

typedef union __data_registers
{
    struct
    {
        rssi_status_t rssi;
        read_chan_t read_channel;
        rds_t rdsa;
        rds_t rdsb;
        rds_t rdsc;
        rds_t rdsd;
    };
    uint8_t data_bytes[12];

} data_registers_t;

typedef enum {
    FM_CLICK_RST_LOW,
	FM_CLICK_RST_HIGH,
    FM_CLICK_READ_REGISTERS,
    FM_CLICK_SET_OSC,
    FM_CLICK_WAIT_OSC,
    FM_CLICK_WAIT_POWER_UP,
    FM_CLICK_SEND_DEFAULT_CONF,
    FM_CLICK_INIT_DONE,
    FM_CLICK_READY,

} FMClick_init_state_t;


typedef enum
{
    FM_CLICK_IDLE               = 0,
    FM_CLICK_SEEK_START         = 1,
    FM_CLICK_SEEK_WAIT          = 2,
    FM_CLICK_TUNE_START         = 3,
    FM_CLICK_TUNE_WAIT          = 4,
    FM_CLICK_VOLUME             = 5,
    FM_CLICK_RDS                = 6,
    FM_CLICK_GET_RDS            = 7,
    FM_CLICK_WAIT_WRITE_FINISH  = 8,
    FM_CLICK_WAIT_FOR_CLEAR     = 9,
} FMClick_operation_t;


# endif