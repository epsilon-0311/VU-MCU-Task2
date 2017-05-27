#include "ip.h"
#include "printf.h"
#include "udp_config.h"

module ScoreP{
    uses interface Boot;
    uses interface UdpSend as UdpSend;
    uses interface UdpReceive as UdpReceive;
    uses interface SplitControl as Control;
    uses interface IpControl;
    uses interface Queue<udp_msg_t *> as MsgQueue;
    uses interface Queue<uint16_t> as LenQueue;
    uses interface Pool<udp_msg_t> as MsgPool;
    
    provides interface Score;
}
implementation {
    task void echoTask();
    void enqueueMsg(uint8_t* data, uint16_t len);

    bool sendBusy = FALSE;
	
    event void Boot.booted() {
    in_addr_t *ip;
    char buffer[17];

#ifdef CUSTOM_IP_SETTINGS
    in_addr_t cip = { .bytes {IP}};
    in_addr_t cnm = { .bytes {NETMASK}};
    in_addr_t cgw = { .bytes {GATEWAY}};

    call IpControl.setIp(&cip);
    call IpControl.setNetmask(&cnm);
    call IpControl.setGateway(&cgw);
#endif
    ip = call IpControl.getIp();

    call Control.start();
	}
    event void Control.stopDone(error_t error) {

    }

    event void Control.startDone(error_t error) {

    }

    event void UdpSend.sendDone(error_t error) {

            sendBusy = FALSE;

            call MsgPool.put(call MsgQueue.dequeue());       // "free" memory
            call LenQueue.dequeue();

            if (! call MsgQueue.empty()) {    // anything else to send
                    post echoTask();
            }
    }

    void enqueueMsg(uint8_t* data, uint16_t len) {
            udp_msg_t* queueData = call MsgPool.get(); // allocate memory
            memcpy(queueData->data, data, len);

            call MsgQueue.enqueue(queueData);
            call LenQueue.enqueue(len);
    }

    task void echoTask() {
            static in_addr_t destination = { .bytes {DESTINATION}};

            if (call MsgQueue.empty()) {
                    return;
            } else if (! sendBusy) {
                    udp_msg_t* outData = call MsgQueue.head();
                    uint16_t outLen = call LenQueue.head();
                    printf("%s", outData->data);
                    if (call UdpSend.send(&destination, UDP_PORT, outData->data, outLen) == SUCCESS) {
                            sendBusy = TRUE;
                    }
            }
    }

    event void UdpReceive.received(in_addr_t *srcIp, uint16_t srcPort, uint8_t *data, uint16_t len) {
            if (len > MAX_MSG_LEN) {
                    len = MAX_MSG_LEN;
            }

            data[len] = 0;

            enqueueMsg(data, len);

            post echoTask();
    }


    /**
      * Signal the scoreboard that a new game has started
      * @param The name of the player
      */
    command void Score.startGame(char* name){
        static uint8_t string[] = "Welcome\n";
        static uint16_t len = sizeof(*name);

        enqueueMsg(string, len);

        post echoTask();
    }
    /**
      * Send a new score to the scoreboard
      * @param The new score
      */
    command void Score.sendScore(uint32_t score){
        static uint8_t string[11] = "";
        static uint16_t len =0;
        sprintf(string, "%d", score);
        
        len = sizeof(string);

        enqueueMsg(string, len);

        post echoTask();
    }
    
    /**
      * Signal the scoreboard that the game has ended
      * @param The final score
      */
    command void Score.gameOver(uint32_t score){
        static uint8_t string[11] = "";
        static uint16_t len =0;
        sprintf(string, "%d", score);
        
        len = sizeof(string);

        enqueueMsg(string, len);

        post echoTask();
    }
    

}