// -*-mode: c++; fill-column: 75; tab-width: 8; coding: utf-8-dos -*-

#property copyright "Copyright 2013 OpenTrading"
#property link      "https://github.com/OpenTrading/"
#property strict

#define INDICATOR_NAME          "PyTestNullEA"

#include <OTMql4/OTPy27.mqh>

extern string sStdOutFile="_test_null_stdout.txt";

int OnInit() {
  string sArg, sRetval;
  PyInit(sStdOutFile);
  Print("Called PyInit");
  /* too long to fit a log line */
  sArg="str(sys.path[0])";
  sRetval = PyEvalString(sArg);
  Print("sys.path = "+sRetval);
  return (0);
}
int iTick=0;

void OnTick () {
  iTick+=1;
  Print("iTick="+iTick);
}

void OnDeinit(const int iReason) {
    //? if (iReason == INIT_FAILED) { return ; }
    PyDeInit();
}
