#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "math.h"
#include "DrugDelivery.h"
#include "drug_delivery_mcr.h"

module DrugDeliveryC {
  uses {

    interface Boot;
    interface Timer<TMilli> as BeatTimer;
    interface Leds;

    interface SplitControl as RadioControl;
    interface Packet;
    interface AMSend;
    interface Receive;

    interface Timer<TMilli> as ScheduleTimer;
    interface Timer<TMilli> as MotorTimer;
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

  uint32_t schedule_data[20][2];
  uint16_t time_data[101] = {0U, 600U, 800U, 1087U, 1167U, 1330U, 1569U, 1880U, 2256U, 2693U, 3185U, 3729U, 4319U, 4951U, 5621U, 6324U, 7058U, 7818U, 8600U, 9403U, 10222U, 11055U, 11898U, 12750U, 13607U, 14468U, 15330U, 16191U, 17050U, 17904U, 18751U, 19592U, 20423U, 21244U, 22054U, 22851U, 23635U, 24405U, 25160U, 25900U, 26623U, 27330U, 28021U, 28695U, 29351U, 29990U, 30612U, 31217U, 31805U, 32375U, 32929U, 33467U, 33989U, 34495U, 34986U, 35462U, 35923U, 36372U, 36806U, 37229U, 37639U, 38038U, 38427U, 38806U, 39175U, 39535U, 39888U, 40233U, 40572U, 40904U, 41231U, 41554U, 41872U, 42187U, 42498U, 42807U, 43114U, 43419U, 43723U, 44025U, 44328U, 44629U, 44930U, 45231U, 45532U, 45833U, 46133U, 46433U, 46732U, 47029U, 47326U, 47620U, 47911U, 48199U, 48482U, 48761U, 49033U, 49297U, 49553U, 49799U, 50033U};
  uint8_t release_step = 0;
  uint32_t motor_run_time = 1;
  uint32_t viscosity_a = 1;
  uint32_t viscosity_b = 0;
  float viscosity;

  task void sendStatus();
  task void handleStatus();
  task void startRelease();
  float time_point(int);
  int int_power(int, int);

  event void Boot.booted() {
    printf("MCR booted: DrugDeliveryC\n");
    call M0.write(0);
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
      printf("Alive\n");
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

  int32_t lenHelper(int32_t x) {
      if(x>=1000000000) return 10;
      if(x>=100000000) return 9;
      if(x>=10000000) return 8;
      if(x>=1000000) return 7;
      if(x>=100000) return 6;
      if(x>=10000) return 5;
      if(x>=1000) return 4;
      if(x>=100) return 3;
      if(x>=10) return 2;
      return 1;
  }

  task void handleStatus() {
    int i;
    switch (status) {
      case 121:
        printf("Schedule receive start\n");
        viscosity_a = data2;
        viscosity_b = data3;
        viscosity = (float)viscosity_a + (float)viscosity_b / (float) powf(10, lenHelper(viscosity_b));
        status = 122;
        post sendStatus();
        break;
      case 123:
        printf("Received a schedule: %d %lu  mins %lu\n", data1, data2, data3);
        schedule_data[data1][0] = data2;
        schedule_data[data1][1] = data3;
        post sendStatus();
        break;
      case 124:
        printf("Schedule wholly received\n");
        printf("%d\nFull schedule:\n", data1);
        for (i = 0; i <= data1; i++) {
          printf("%lu -%lu\n", schedule_data[i][0], schedule_data[i][1]);
        }
        status = 100;
        call BeatTimer.stop();
        call BeatTimer.startPeriodic(heartbeat);
        post sendStatus();
        post startRelease();
        break;
      default:
        printf("Undefined status code: %d\n", status);
        break;
    }
  }

  task void startRelease() {
    uint8_t total_released;
    uint8_t to_be_released;
    if (release_step <= data1) {
      printf("Waiting for %u minutes before release\n", (unsigned int)schedule_data[release_step][0]);
      total_released = 100 - status;
      to_be_released = schedule_data[release_step][1];
      motor_run_time = viscosity * 10 * (time_data[total_released + to_be_released] - time_data[total_released]);
      call ScheduleTimer.startOneShot(schedule_data[release_step][0] * 60 * 1000);
    } else {
      printf("Drug release completed\n");
    }
  }

  event void ScheduleTimer.fired() {
    printf("Running motor for %lu miliseconds\n", motor_run_time);
    call M0.write(255);
    call MotorTimer.startOneShot(motor_run_time);
  }

  event void MotorTimer.fired() {
    printf("%d/%d of schedule completed\n", release_step, data1);
    status -= schedule_data[release_step][1];
    call M0.write(0);
    release_step++;
    post startRelease();
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {}

  event void RadioControl.stopDone(error_t err) {}

}
