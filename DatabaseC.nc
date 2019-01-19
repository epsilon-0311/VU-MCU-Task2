#include "udp_config.h"

configuration DatabaseC{
    provides interface Database;
}
implementation
{
    components DatabaseP;
    components MainC;
    components new UdpC(UDP_PORT);
    components Enc28j60C as EthernetC;
    components LlcTransceiverC;
    components IpTransceiverC;

    components new PoolC(udp_msg_t, MSG_POOL_SIZE) as UdpMsgPool;
    components new QueueC(udp_msg_t*, MSG_POOL_SIZE) as UdpMsgQueue;
    components new QueueC(uint16_t, MSG_POOL_SIZE) as UdpLenQueue;
    components new QueueC(Database_operation_t, MSG_POOL_SIZE) as DbOpQueue;

    components BufferedLcdC;

    Database = DatabaseP;
    DatabaseP.Boot -> MainC.Boot;
    DatabaseP.UdpSend -> UdpC;
    DatabaseP.UdpReceive -> UdpC;
    DatabaseP.Control -> EthernetC;

    LlcTransceiverC.Mac -> EthernetC;
    DatabaseP.IpControl -> IpTransceiverC;

    DatabaseP.MsgPool   ->  UdpMsgPool;
    DatabaseP.LenQueue  ->  UdpLenQueue;
    DatabaseP.MsgQueue  ->  UdpMsgQueue;
    DatabaseP.OpQueue   ->  DbOpQueue;

    DatabaseP.BufferedLcd -> BufferedLcdC;
}
