# Autodesk IoT Discovery Kit Testing Factory Code

Factory Test Code for AD IoT Discovery Kits

## Tests

The factory code runs through the following tests. 

After each test an LED blinks, green if test pass, red if test fails. 

When tests have all run the yellow LED turns on. If all tests have passed the green LED also turns on and a label is printed. If any test failed the red LED turns on and no label is printed.  

### Test 1 LEDs

Each LED is turned on then off.  *Note* The code always marks this test as passing.

1st: Red
2nd: Yellow
3rd: Green 

### Test 2 Wiznet Echo

This test requires an echo server (RasPi) and cat5 a crossover cable. Everything must be connected before the test starts. The test: 

* Opens a connection and receiver
* Sends the test string
* Checks response from RasPi for the test string
* Closes the connection

### Test 3 USB FTDI

This test requires a USB FTDI device (FTDI232). The test works best if the USB device is plugged in before the test starts. The test: 

* Initializes USB host and FTDI driver
* If a device is plugged in the onConnected FTDI callback triggers a test pass

### Test 4 RS485 Modbus

This test requires a PLC Click to be connected via modbus RS485 bus. The test:

* Reads a register
* Writes to that register with new value
* Reads that register again and checks for new value

### Test 5 ADC Channel 6

This test reads Channel 6 on the ADC. The test:

* Reads channel 6 - the expected value is 0
* Checks that the reading is within a &plusmn;0.2 range

### Test 6 ADC Channel 7

This test reads Channel 7 on the ADC. The test:

* Reads channel 7 - the expected value is 2.5
* Checks that the reading is within a &plusmn;0.2 range

### Test 7 Grove i2c

This test requires a HTS221 Temperature Humidity grove sensor to be attached to the i2c grove. This test:

* Reads the HTS221 WHO_AM_I register 
* Checks for the expected value

### Test 8 Analog Grove

This test requires a grove connector cable to loop between the two analog grove ports. This test:

* Configures grove 1 pins as inputs and grove 2 pins as outputs
* Sets output 1 high and output 2 low
* Reads the grove inputs to check for shorts between the pins

