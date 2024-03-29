#ifndef UDP_CONFIG_H
#define UDP_CONFIG_H

#define CUSTOM_IP_SETTINGS

#define UDP_PORT	50000UL
// note the ',' (instead of the usual '.') between numbers
#define DESTINATION	192,168,42,1

// the following settings are only applied if CUSTOM_IP_SETTINGS is defined
// note the ',' (instead of the usual '.') between numbers
#define IP		192,168,42,2
#define NETMASK	255,255,255,0
#define GATEWAY	192,168,42,1

// Memory Pool Settings
#define MAX_MSG_LEN	128
#define MSG_POOL_SIZE 16

typedef struct udp_msg {
	uint8_t data[MAX_MSG_LEN];
} udp_msg_t;

#endif
