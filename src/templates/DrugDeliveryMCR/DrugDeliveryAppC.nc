/**
 * This code is used for testing the miniature MCR board for a Drug Delivery capsule
 *
 * @auther Addisu Taddese
 * @date March 17 2015
 */

#include "DrugDelivery.h"

configuration DrugDeliveryAppC {
}
implementation {

  components DrugDeliveryC as App, MainC;
  components SerialPrintfC;
  App.Boot -> MainC.Boot;

  components new TimerMilliC() as Timer0;
  App.BeatTimer -> Timer0;
  components LedsC;
  App.Leds -> LedsC;

  components ActiveMessageC;
  App.RadioControl -> ActiveMessageC;
  App.Packet -> ActiveMessageC;

  components new AMSenderC(AM_RADIOSTATUSMSG);
  App.AMSend -> AMSenderC;
  components new AMReceiverC(AM_RADIOSTATUSMSG);
  App.Receive -> AMReceiverC;

  components new MotorDriverGenericC(0) as M0;
  App.M0 -> M0;

}
