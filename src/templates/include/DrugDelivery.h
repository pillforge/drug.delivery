#ifndef DRUGDELIVERY_H_SWYI860V
#define DRUGDELIVERY_H_SWYI860V

typedef nx_struct RadioStatusMsg {
  nx_uint8_t status;
  nx_uint8_t data1;
  nx_uint32_t data2;
  nx_uint32_t data3;
} RadioStatusMsg;

enum {
  AM_RADIOSTATUSMSG = 7
};

#endif /* end of include guard: DRUGDELIVERY_H_SWYI860V */
