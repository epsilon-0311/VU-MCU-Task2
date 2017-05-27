#include "udp_config.h"

configuration ScoreC{
    provides interface Score;
    
}
implementation {
  
    components MainC;
    components ScoreP;
    components new UdpC(UDP_PORT);
    components Enc28j60C as EthernetC;
    components LlcTransceiverC;
    components IpTransceiverC;
    components new PoolC(udp_msg_t, MSG_POOL_SIZE) as UdpMsgPool;
    components new QueueC(udp_msg_t*, MSG_POOL_SIZE) as UdpMsgQueue;
    components new QueueC(uint16_t, MSG_POOL_SIZE) as UdpLenQueue;
  
    Score = ScoreP;
    
    ScoreP.Boot -> MainC.Boot;
    ScoreP.UdpSend -> UdpC;
    ScoreP.UdpReceive -> UdpC;
    ScoreP.Control -> EthernetC;

    LlcTransceiverC.Mac -> EthernetC;
    ScoreP.IpControl -> IpTransceiverC;

    ScoreP.MsgPool   ->  UdpMsgPool;
    ScoreP.LenQueue  ->  UdpLenQueue;
    ScoreP.MsgQueue  ->  UdpMsgQueue;
    
}