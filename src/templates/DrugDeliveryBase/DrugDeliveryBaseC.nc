#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "DrugDelivery.h"
#include "schedule_data.h"

module DrugDeliveryBaseC {
  uses {

    interface Boot;
    interface Timer<TMilli> as BeatTimer;
    interface Leds;

    interface SplitControl as RadioControl;
    interface Packet;
    interface AMSend;
    interface Receive;
    interface UartStream;

  }
}

/*
 *  Led 0 blinks every second
 *  Led 1 blinks when it receives a message from MCR
 */

implementation {

  message_t packet;
  uint8_t to_send_addr = 2;
  uint8_t status = 255;
  uint8_t data1 = 99;
  uint32_t data2 = 99999;
  uint32_t data3 = 99999;
  uint8_t sending_schedule = 0;

  uint8_t size_schedule_data = 0;
  uint32_t schedule_data[][2] = schedule_data_macro;

  char serial_trig_letter = 'r';

  task void handleStatus();
  task void sendStatus();
  task void resetScheduler();

  event void Boot.booted() {
    printf("Base booted: DrugDeliveryBaseC\n");
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err == SUCCESS) {
      printf("Base radio started.\n");
      call BeatTimer.startPeriodic(1000);
      call UartStream.enableReceiveInterrupt();
    } else {
      call RadioControl.start();
    }
  }

  event void BeatTimer.fired() {
    call Leds.led0Toggle();
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    RadioStatusMsg *rsm = (RadioStatusMsg *) payload;
    call Leds.led1Toggle();
    status = rsm->status;
    data1 = rsm->data1;
    data2 = rsm->data2;
    data3 = rsm->data3;
    printf("Status: %d, data1: %d data2: %lu data3: %lu\n", status, data1, data2, data3);
    post handleStatus();
    return bufPtr;
  }

  task void handleStatus() {
    switch (status) {
      case 120:
        printf("Communication is initiatied\n");
        if(!sending_schedule) {
          status = 121;
          size_schedule_data = sizeof(schedule_data)/sizeof(schedule_data[0]);
          data1 = size_schedule_data;
          data2 = viscosity_a;
          data3 = viscosity_b;
          post sendStatus();
        }
        break;
      case 122:
        printf("Starting sending the schedule\n");
        if (size_schedule_data > 0) {
          status = 123;
          data1 = 0;
          data2 = schedule_data[0][0];
          data3 = schedule_data[0][1];
          post sendStatus();
        }
        break;
      case 123:
        printf("Acknowledgment received\n");
        if (data1 >= size_schedule_data-1) {
          status = 124;
        } else {
          data1++;
          data2 = schedule_data[data1][0];
          data3 = schedule_data[data1][1];
        }
        post sendStatus();
        break;
      default:
        printf("Undefined status code: %d\n", status);
        call UartStream.enableReceiveInterrupt();
        break;
    }
  }

  task void sendStatus() {
    RadioStatusMsg *rsm = (RadioStatusMsg *) call Packet.getPayload(&packet, sizeof(RadioStatusMsg));
    rsm->status = status;
    rsm->data1 = data1;
    rsm->data2 = data2;
    rsm->data3 = data3;
    call AMSend.send(to_send_addr, &packet, sizeof(RadioStatusMsg));
  }

  task void resetScheduler() {
    status = 120;
    post handleStatus();
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {}

  event void RadioControl.stopDone(error_t err) {}

  async event void UartStream.receivedByte(uint8_t byte) {
    if (byte == serial_trig_letter) {
      printf("Resetting scheduler n");
      call UartStream.disableReceiveInterrupt();
      post resetScheduler();
    } else 
      printf("Send %c to reset scheduler\n", serial_trig_letter);
  }

  async event void UartStream.sendDone(uint8_t*, uint16_t, error_t) {
  }

  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t error) {
  }
}
