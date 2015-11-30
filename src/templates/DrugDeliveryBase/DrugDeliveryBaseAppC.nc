/**
 * This code is used for testing the miniature MCR board for a Drug delivery capsule
 *
 * @author Addisu Taddese
 * @date March 17 2015
 */

#include "DrugDelivery.h"

configuration DrugDeliveryBaseAppC {
}
implementation {

  components DrugDeliveryBaseC as App, MainC;
  components SerialPrintfC;
  App.Boot -> MainC.Boot;
  components PlatformSerialC as UartC;

  components new TimerMilliC() as Timer0;
  App.BeatTimer -> Timer0;
  components LedsC;
  App.Leds -> LedsC;
  App.UartStream -> UartC;

  components ActiveMessageC;
  App.RadioControl -> ActiveMessageC;
  App.Packet -> ActiveMessageC;

  components new AMSenderC(AM_RADIOSTATUSMSG);
  App.AMSend -> AMSenderC;
  components new AMReceiverC(AM_RADIOSTATUSMSG);
  App.Receive -> AMReceiverC;

}
