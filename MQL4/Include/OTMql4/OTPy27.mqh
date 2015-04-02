// -*-mode: c++; fill-column: 75; tab-width: 8; coding: utf-8-dos -*-
//+------------------------------------------------------------------+
//|                                                         py27.mqh |
//|                                                     Bernd Kreuss |
//|                                             mailto:7ibt@arcor.de |
//|                                                                  |
//|                                                                  |
//|               Python Integration For Metatrader 4                |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Bernd Kreuss and Open Trading"
#property link      "https://github.com/OpenTrading/"

#import "kernel32.dll"
    int lstrlenA(int);
    void RtlMoveMemory(uchar & arr[], int, int);
    int LocalFree(int); // May need to be changed depending on how the DLL allocates memory
#import


/* 
Be careful of using any of these imported funtions directly for strings:
they expect uchar[] arrays, not unicode strings.
*/

#import "OTMql4/py27.dll" // dll version 1.3.0.x (for Python 2.7.x)

/**
* Initialize the Python environmant. This will start a new
* thread which will initialize Python and enter a sleep() loop.
* Dont call this directly, call PyInit() instead. (see below)
*/
void PyInitialize();

/**
* Return True if PyInitialize() has already been called
*/
bool PyIsInitialized();

void PyErrPrint();

/**
* Decrease the reference counter of a Python object by one and free the
* object if the counter reaches zero. You may only call this for objects
* that you OWN yourself, not for BORROWED references.
*/
void PyDecRef(int p_object);

/**
* Increase the reference counter by one
*/
void PyIncRef(int p_object);

/**
* Execute an arbitrary piece of python code
*/
/*old void PyExecute(string uSource); */
void PyExecute(uchar &uSource[]);


/**
* Evaluate a python expression and return your NEW OWN
* reference to the result. For example if foo.bar.baz is a list
* and you want a reference to it so you can directy loop through
* its members then just call PyEvaluate("foo.bar.baz") and use 
* the return value as a handle for the PyLookupList() function.
* You can also use this handle for PyListAppend() because it is
* *not* a copy but rather a reference to the original list.
* 
* After you are done with using the handle returned by PyEvaluate()
* you MUST call PyDecRef() to signal Python that you are now done 
* with this object, this will restore the reference counter to
* the value it had before or free it completely if the object
* was created by the code you evaled (return value of a function 
* or the result of a calculation which python will no longer 
* need after you read it)
*/
// new reference, PyDecRef() after using!
/*old int PyEvaluate(string uSource); */
int PyEvaluate(uchar &uSource[]);

/**
* return a BORROWED reference to the __main__ dict
*/
int PyMainDict();

/**
* return a BORROWED reference to the item in the dict
* specified by name.
*/
/*oldint PyLookupDict(int p_dict, string name);*/
int PyLookupDict(int p_dict, uchar &name[]);

/**
* return a BORROWED reference to the item in the list
* specified by index.
*/
int PyLookupList(int p_list, int index);

/**
* return the value of the object as int
* (if it is a numeric object)
*/
int PyGetInt(int ptr_int);

/**
* return the value of the object as a double
* (if it is a numeric object)
*/
double PyGetDouble(int p_double);

/**
* return the value of the object as a string
* (only if it actually is a string object)
*/
/*old: string PyGetString(int p_string);*/
int PyGetString(int p_string);

/**
* create a new integer obect. You will OWN a reference, 
* so take care of the reference counter
*/  
int PyNewInt(int value);

/**
* create a new double (actually a python float) object. 
* You will OWN a reference, so take care of the reference counter
*/  
int PyNewDouble(double value);

/**
* create a new string obect. You will OWN a reference, 
* so take care of the reference counter
*/  
/*old: int PyNewString(string &value);
FixMe: this is a pointer to a string:
how do we do a pointer to a uchar[] pointer?
*/
int PyNewString(uchar &value[]);


/**
* append the item to the list. This function will NOT steal
* the reference, it will create its own, so ownership
* will not change, so if it was your OWN and NOT a
* borrowed reference you must decref after you are done
*/
void PyListAppend(int p_list, int p_item);

/**
* return the size of the list object
*/
int PyListSize(int p_list);

#import

/* 
Wrappers around the imported funtions for strings:
they expect uchar[] arrays, not unicode strings.
*/
void vPyExecuteUnicode (string uSource) {
    uchar sCharData[];
    StringToCharArray(uSource, sCharData);
    PyExecute(sCharData);
}

int iPyEvaluateUnicode (string uSource) {
    int iRetval;
    uchar sCharData[];
    StringToCharArray(uSource, sCharData);
    iRetval = PyEvaluate(sCharData);
    return(iRetval);
}

/* FixMe: this is a pointer to a string:
    how do we do a pointer to a uchar[] pointer? */
int iPyNewStringUnicode(string &uSource) {
    int iRetval;
    uchar sCharData[];
    StringToCharArray(uSource, sCharData);
    iRetval = PyNewString(sCharData);
    return(iRetval);
}

int PyLookupDictUnicode(int p_dict, string uName) {
    int iRetval;
    uchar sCharData[];
    StringToCharArray(uName, sCharData);
    iRetval = PyLookupDict(p_dict, sCharData);
    return(iRetval);
}

string uPyGetUnicodeString(int p_string) {
    int iPointer, iMessLen;
    string uMessage;
    uchar sCharArray[];
    
    iPointer = PyGetString(p_string);
    // Get the length of the string 
    iMessLen = lstrlenA(iPointer);   

    // if message length is 0, leave.  
    if (iMessLen < 1) {
    	return("");
    }
 
    // Create a uchar[] array whose size is the string length (plus null terminator)
    ArrayResize(sCharArray, iMessLen);
    
    // Use the Win32 API to copy the string from the block returned by the DLL
    // into the uchar[] array   
    RtlMoveMemory(sCharArray, iPointer, iMessLen);
    // Convert the uchar[] array to a string
    uMessage = CharArrayToString(sCharArray);
    return(uMessage);
}

void PyExec (string uSource) {
    vPyExecuteUnicode(uSource);
}


/*
* below are some higher level abstractions, here you dont have to
* care about reference counting when using the functions, you will
* not be exposed to handles of python objects
*/


/*
* initialize the Python environment. This should be called
* from your init() function. It is safe to call it a second
* time, subsequent calls will just be ignored.
*/

void PyInit(string sStdOut) {
    string sRetval, sArg;
    double fPythonUsers;
    double fDebugLevel;
    
    if (!PyIsInitialized()) {
    Print("PyInit: Starting OTPy27.mqh in " +  TerminalPath());
    // Thread specific??
    if (GlobalVariableCheck("fPythonUsers") == true) {
      GlobalVariableDel("fPythonUsers");
    }
    PyInitialize();    
    Print("PyInit: called PyInitialize ");

    sArg="import os, sys, logging, traceback";
    vPyExecuteUnicode(sArg);
    sArg="sys.last_type=''";
    vPyExecuteUnicode(sArg);
    sArg="sys.last_value=''";
    vPyExecuteUnicode(sArg);
    // 
    vPyExecuteUnicode("os.chdir(os.path.join(r'" + TerminalPath() + "'))");
    // NOT sArg="sys.path.insert(0, os.getcwd())";
    sArg="sys.path.insert(0, os.path.join(r'" + TerminalPath() + "', 'MQL4', 'Python'))";
    vPyExecuteUnicode(sArg);
    /* touch __init__.py */
    
    /* make sure OTMql427.py is there */
    sArg="import OTMql427";
    vPyExecuteUnicode(sArg);
      
    GlobalVariableTemp("fPythonUsers");
    fPythonUsers = 0.0;
    } else {
    fPythonUsers=GlobalVariableGet("fPythonUsers");
    Print("PyInit: Incrementing fPythonUsers from: " + fPythonUsers);
    fDebugLevel=GlobalVariableGet("fDebugLevel");
    }

    if (fPythonUsers < 0.1) {
      sRetval = PyEvalString("OTMql427.ePyInit('" + sStdOut + "')");
      if (sRetval != "") {
	Print("ERROR: failed OTMql427.ePyInit - " + sRetval + "");
      } else {
	Print("INFO: Python stdout file: " + sStdOut);
	//was PyEvalString("os.path.join(os.getcwd(), sys.stdout.name)"));
	sArg="sys.stdout.flush()";
	vPyExecuteUnicode(sArg);
      }
      fPythonUsers = 1.0;
    } else {
      fPythonUsers += 1.0;
    }

    GlobalVariableSet("fPythonUsers", fPythonUsers);
    
    /* not Tmp */
    if (GlobalVariableCheck("fDebugLevel") == false) {
      /* 1= Error, 2 = Warn, 3 = Info, 4 = Debug, 5 = Trace */
      fDebugLevel=2.0;
      GlobalVariableSet("fDebugLevel", fDebugLevel);
    }
}

// empty the stdout file (where the redirected print output and errors go)
void PyOutEmpty() {
    string sArg;
    sArg="__outfile__.seek(0, os.SEEK_SET)";
    vPyExecuteUnicode(sArg);
    sArg="__outfile__.truncate(0)";
    vPyExecuteUnicode(sArg);
}

// You MUST do something to clear the error condition
// or the system will crash, as documented in the Python manual.
void PyPrintAndClearLastError() {
    // PyErrPrint();
    PyExec("sys.exc_clear()");

    string uSource="hasattr(sys, 'last_type') and str(sys.last_value) or ''";
    int p_res = iPyEvaluateUnicode(uSource);
    if (p_res <= 0) {
      Print("ERROR: PyPrintAndClearLastError - evaluating: " + uSource);
      PyExec("sys.exc_clear()");
      return;
    }
    string res = uPyGetUnicodeString(p_res);
    PyDecRef(p_res);

    Print("ERROR: " + res);
}

/*
* Evaluate a python expression that will evaluate to a string
* and return its value
*/
string sPySafeEval(string uSource){
    // In the caller you should have something like:
    //if (StringFind(res, "ERROR:", 0) == 0) {
    //  Print("Error in Python evaluating: " + uSource + "\n" + res);
    //  <do something as a result of the failure
    //}
    string sRetval="";
    string sSrc;
    sSrc="OTMql427.sPySafeEval('''"+uSource+"''')";

    int p_res = iPyEvaluateUnicode(sSrc);
    if (p_res <= 0) {
    Print("ERROR: PyEval - evaluating: " + uSource);
    PyPrintAndClearLastError();
    return ("");
    }
    sRetval = uPyGetUnicodeString(p_res);
    PyDecRef(p_res);
    
    return(sRetval);
}

/**
* Evaluate a python expression that will evaluate to an integer 
* and return its value
*/
int PyEvalInt(string uSource){
    int p_res = iPyEvaluateUnicode(uSource);
    if (p_res <= 0) {
    Print("ERROR: PyEvalInt - evaluating: " + uSource);
    PyExec("sys.exc_clear()");
    return (0);
    }
    int res = PyGetInt(p_res);
    PyDecRef(p_res);
    return(res);
}

/**
* Evaluate a python expression that will evaluate to a double 
* and return its value
*/
double PyEvalDouble(string uSource){
    int p_res = iPyEvaluateUnicode(uSource);
    if (p_res <= 0) {
    Print("ERROR: PyEvalDouble - evaluating: " + uSource);
    PyExec("sys.exc_clear()");
    return (0.0);
    }
    double res = PyGetDouble(p_res);
    PyDecRef(p_res);
    return(res);
}

/**
* Evaluate a python expression that will evaluate to a string 
* and return its value
*/
string PyEvalString(string uSource){
    int p_res = iPyEvaluateUnicode(uSource);
    if (p_res <= 0) {
      Print("ERROR: PyEvalString - evaluating: " + uSource);
      PyExec("sys.exc_clear()");
      //PyPrintAndClearLastError();
      return ("");
    }
    string res = uPyGetUnicodeString(p_res);
    PyDecRef(p_res);
    return(res);
}

/**
* append the array of int to the python list given by its name.
* the list must already exist. The same could be achieved
* by putting vPyExecuteUnicode() calls with generated python code
* into a loop but this would invoke parser and compiler for
* every new list item, directly accessing the python objects
* like it is done here is far more effective.
*/
int PyListAppendInt(string list_name, int &array[]){
    int list,item,len,i;
    list = iPyEvaluateUnicode(list_name);
    len = ArraySize(array);
    for (i=0; i<len; i++){
      item = PyNewInt(array[i]);
      PyListAppend(list, item);
      PyDecRef(item);
    }
    len = PyListSize(list);
    PyDecRef(list);
    return(len);
}

/**
* append the array of double to the python list given by its name.
* the list must already exist.
*/
int PyListAppendDouble(string list_name, double &array[]){
    int list,item,len,i;
    list = iPyEvaluateUnicode(list_name);
    len = ArraySize(array);
    for (i=0; i<len; i++){
      item = PyNewDouble(array[i]);
      PyListAppend(list, item);
      PyDecRef(item);
    }
    len = PyListSize(list);
    PyDecRef(list);
    return(len);
}

/**
* append the array of string to the python list given by its name.
* the list must already exist.
*/
int PyListAppendString(string list_name, string &array[]){
    int list,item,len,i;
    list = iPyEvaluateUnicode(list_name);
    len = ArraySize(array);
    for (i=0; i<len; i++){
      item = iPyNewStringUnicode(array[i]);
      PyListAppend(list, item);
      PyDecRef(item);
    }
    len = PyListSize(list);
    PyDecRef(list);
    return(len);
}



/* 
Some notes:
*************


* One Interpreter 
    ===============

    All expert advisors and indicators share the same 
Python interpreter with the same global namespace, so you should 
separate them by encapsulating all in classes and instantiate and 
store them with all their state in variables named after the symbol 
(or maybe even symbol + timeframe).
*/

/*
* Init 
    ====
    
    Put your Python classes into Python modules, the import path 
is <metatrader>\MQL4\Experts, the same folder where your EAs mql code  
is located, so a simple vPyExecuteUnicode("import yourmodule"); in your 
init() will import the file yourmodule.py from this folder. Then 
instantiate an instance of your main class with something like 
    vPyExecuteUnicode(Symbol() + Period() + " = yourmodule.yourclass()"); 
This way each instance of your EA can keep track of its own 
Python counterpart by accessing it via this global variable.

    Your init() function may look similar to this:
    
int init(){
    // initialize Python
    PyInit();
    
    // import my module
    vPyExecuteUnicode("import mymodule");
    
    // instantiate some objects 
    vPyExecuteUnicode("myFoo_" + Symbol() + Period() + " = mymodule.Foo()");
    vPyExecuteUnicode("myBar_" + Symbol() + Period() + " = mymodule.Bar()");
    
    return(0);
}
*/

/*
* Deinit 
    ======
    
    Use the deinit() function of the EA or Indicator to destroy 
these instances, be sure to terminate all threads they may have 
started, make sure you can terminate them fast within less than a 
second because Metatrader has a timeout here, wait inside python 
in a tight loop with time.sleep() until they are terminated before 
returning to prevent Metatrader from proceding with its deinit
while your threads are stll not all ended!

    Your deinit() function may look like this:
    
int deinit(){
    // tell my objects they should commit suicide by
    // calling their self destruction method
    vPyExecuteUnicode("myFoo_" + Symbol() + Period() + ".stopAndDestroy()");
    vPyExecuteUnicode("myBar_" + Symbol() + Period() + ".stopAndDestroy()");
    
    return(0);
}
*/
/*
* Global unload hook
    ==================
    
    If the last EA that used Python has been removed the Python 
interpreter itself will be terminated and unloaded. 
    
    You can register cleanup functions (do it per imported module, not 
per instance!) with the atexit module, it will be called after the 
last EAs deinit(), again as above make it wait for all cleaning 
action to be finished before returning, these are the last clock 
cycles that will be spent inside Python because at this time there 
is only one system thread left and if this function returns the 
python interpreter will be frozen and then immediately unloaded.

*/


void PyDeInit(){
    double fPythonUsers;

    fPythonUsers=GlobalVariableGet("fPythonUsers");
    // FixMe: this is not showing up in the log
    Print("INFO PyDeInit: Decrementing fPythonUsers from: " + fPythonUsers);
    fPythonUsers -= 1.0;

    if (PyIsInitialized() && fPythonUsers < 0.1) {
      PyExec("OTMql427.vPyDeInit()");
      fPythonUsers=0.0;
    }

    if (fPythonUsers < 0.1) {
    bool bRetval=GlobalVariableDel("fPythonUsers");
    int iError=GetLastError();
    if (!bRetval) {
      Print("ERROR PyDeInit: deleting global variable fPythonUsers" +  iError);
    }
    bRetval=GlobalVariableDel("fDebugLevel");
    iError=GetLastError();
    if (!bRetval) {
      Print("ERROR PyDeInit: deleting fDebugLevel" +  iError);
    }
    } else {
    GlobalVariableSet("fPythonUsers", fPythonUsers);
    }
}