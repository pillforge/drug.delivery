#define NEW_PRINTF_SEMANTICS
#include "printf.h"
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
  uint16_t time_data[101] = {0, 600, 800, 1087, 1167, 1330, 1569, 1880, 2256, 2693, 3185, 3729, 4319, 4951, 5621, 6324, 7058, 7818, 8600, 9403, 10222, 11055, 11898, 12750, 13607, 14468, 15330, 16191, 17050, 17904, 18751, 19592, 20423, 21244, 22054, 22851, 23635, 24405, 25160, 25900, 26623, 27330, 28021, 28695, 29351, 29990, 30612, 31217, 31805, 32375, 32929, 33467, 33989, 34495, 34986, 35462, 35923, 36372, 36806, 37229, 37639, 38038, 38427, 38806, 39175, 39535, 39888, 40233, 40572, 40904, 41231, 41554, 41872, 42187, 42498, 42807, 43114, 43419, 43723, 44025, 44328, 44629, 44930, 45231, 45532, 45833, 46133, 46433, 46732, 47029, 47326, 47620, 47911, 48199, 48482, 48761, 49033, 49297, 49553, 49799, 50033};
  uint8_t release_step = 0;
  uint32_t motor_run_time = 1;
  uint32_t viscosity_a = 1;
  uint32_t viscosity_b = 0;
  double viscosity;

  task void sendStatus();
  task void handleStatus();
  task void startRelease();
  double time_point(int);
  int int_power(int, int);

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

  int lenHelper(int x) {
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
        viscosity = (double)viscosity_a + (double)viscosity_b / (double) lenHelper(viscosity_b);
        status = 122;
        post sendStatus();
        break;
      case 123:
        printf("Received a schedule: #%u %u mins %u %d%\n", data1, data2, data3);
        schedule_data[data1][0] = data2;
        schedule_data[data1][1] = data3;
        post sendStatus();
        break;
      case 124:
        printf("Schedule wholly received\n");
        printf("%d\nFull schedule:\n", data1);
        for (i = 0; i <= data1; i++) {
          printf("%u -%u- %u\n", schedule_data[i][0], schedule_data[i][1]);
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
      printf("Waiting for %u minutes before release\n", schedule_data[release_step][0]);
      total_released = 100 - status;
      to_be_released = schedule_data[release_step][1];
      motor_run_time = viscosity * 10 * time_data[total_released + to_be_released] - viscosity * 10 * time_data[total_released];
      call ScheduleTimer.startOneShot(schedule_data[release_step][0] * 60 * 1000);
    } else {
      printf("Drug release completed\n");
    }
  }

  event void ScheduleTimer.fired() {
    printf("Running motor for %u miliseconds\n", motor_run_time);
    call M0.write(255);
    call MotorTimer.startOneShot(motor_run_time);
  }

  event void MotorTimer.fired() {
    printf("%u/%u of schedule completed\n", release_step, data1);
    status -= schedule_data[release_step][1];
    call M0.write(0);
    release_step++;
    post startRelease();
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {}

  event void RadioControl.stopDone(error_t err) {}

}
