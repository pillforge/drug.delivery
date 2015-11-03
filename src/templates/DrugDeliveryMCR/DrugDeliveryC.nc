#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "DrugDelivery.h"

module DrugDeliveryC {
  uses {

    interface Boot;
    interface Timer<TMilli> as BeatTimer;
    interface Leds;

    interface SplitControl as RadioControl;
    interface Packet;
    interface AMSend;
    interface Receive;

    interface Actuate<uint8_t> as M0;
  }
}

/*
 *  Led 0 blinks every second
 *  Led 1 blinks when it receives a message from Base
 */

implementation {

  message_t packet;
  uint8_t to_send_addr = 1;
  uint8_t status = 120;
  uint8_t data1 = 99;
  uint32_t data2 = 99999;
  uint32_t data3 = 99999;
  task void sendStatus();
  task void handleStatus();

  event void Boot.booted() {
    printf("MCR booted: DrugDeliveryC\n");
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err == SUCCESS) {
      printf("MCR radio started\n");
      printf("Waiting for the initial scheduling to arrive\n..sending 120 status code\n");
      call BeatTimer.startPeriodic(1000);
    } else {
      call RadioControl.start();
    }
  }

  event void BeatTimer.fired() {
    call Leds.led0Toggle();
    if (status == 120 || status <= 100) {
      post sendStatus();
    }
  }

  task void sendStatus() {
    RadioStatusMsg *rsm = (RadioStatusMsg *) call Packet.getPayload(&packet, sizeof(RadioStatusMsg));
    rsm->status = status;
    rsm->data1 = data1;
    call AMSend.send(to_send_addr, &packet, sizeof(RadioStatusMsg));
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    RadioStatusMsg *rsm = (RadioStatusMsg *) payload;
    call Leds.led1Toggle();
    status = rsm->status;
    data1 = rsm->data1;
    data2 = rsm->data2;
    data3 = rsm->data3;
    printf("Status: %d\n", status);
    post handleStatus();
    return bufPtr;
  }

  task void handleStatus() {
    switch (status) {
      case 121:
        printf("Schedule receive start\n");
        status = 122;
        post sendStatus();
        break;
      case 123:
        printf("Received a schedule: #%u %u mins %u%\n", data1, data2, data3);
        printf("only data 3 %u\n", data3);
        post sendStatus();
        break;
      case 124:
        printf("Schedule wholly received\n");
        status = 100;
        post sendStatus();
        break;
      default:
        printf("Undefined status code: %d\n", status);
        break;
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {}

  event void RadioControl.stopDone(error_t err) {}

}
