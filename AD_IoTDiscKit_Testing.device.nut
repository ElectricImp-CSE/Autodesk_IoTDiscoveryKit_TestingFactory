//line 1 "device.nut"
#require "W5500.device.nut:1.0.0"
#require "CRC16.class.nut:1.0.0"
#require "ModbusRTU.class.nut:1.0.0"
#require "ModbusMaster.class.nut:1.0.0"
#require "Modbus485Master.class.nut:1.0.0"
#require "promise.class.nut:3.0.1"

// Factory Tools Lib
#require "FactoryTools.class.nut:2.1.0"
// Factory Fixture Keyboard/Display Lib
#require "CFAx33KL.class.nut:1.1.0"
// Printer Driver
//line 1 "QL720NW.device.nut"
// Printer Driver
class QL720NW {
    static version = [0,1,0];

    _uart = null;   // A preconfigured UART
    _buffer = null; // buffer for building text

    // Commands
    static CMD_ESCP_ENABLE      = "\x1B\x69\x61\x00";
    static CMD_ESCP_INIT        = "\x1B\x40";

    static CMD_SET_ORIENTATION  = "\x1B\x69\x4C"
    static CMD_SET_TB_MARGINS   = "\x1B\x28\x63\x34\x30";
    static CMD_SET_LEFT_MARGIN  = "\x1B\x6C";
    static CMD_SET_RIGHT_MARGIN = "\x1B\x51";

    static CMD_ITALIC_START     = "\x1b\x34";
    static CMD_ITALIC_STOP      = "\x1B\x35";
    static CMD_BOLD_START       = "\x1b\x45";
    static CMD_BOLD_STOP        = "\x1B\x46";
    static CMD_UNDERLINE_START  = "\x1B\x2D\x31";
    static CMD_UNDERLINE_STOP   = "\x1B\x2D\x30";

    static CMD_SET_FONT_SIZE    = "\x1B\x58\x00";
    static CMD_SET_FONT         = "\x1B\x6B";

    static CMD_BARCODE          = "\x1B\x69"
    static CMD_2D_BARCODE       = "\x1B\x69\x71"

    static LANDSCAPE            = "\x31";
    static PORTRAIT             = "\x30";

    // Special characters
    static TEXT_NEWLINE         = "\x0A";
    static PAGE_FEED            = "\x0C";

    // Font Parameters
    static ITALIC               = 1;
    static BOLD                 = 2;
    static UNDERLINE            = 4;

    static FONT_SIZE_24         = 24;
    static FONT_SIZE_32         = 32;
    static FONT_SIZE_48         = 48;

    static FONT_BROUGHAM        = 0;
    static FONT_LETTER_GOTHIC_BOLD = 1;
    static FONT_BRUSSELS        = 2;
    static FONT_HELSINKI        = 3;
    static FONT_SAN_DIEGO       = 4;

    // Barcode Parameters
    static BARCODE_CODE39       = "t0";
    static BARCODE_ITF          = "t1";
    static BARCODE_EAN_8_13     = "t5";
    static BARCODE_UPC_A = "t5";
    static BARCODE_UPC_E        = "t6";
    static BARCODE_CODABAR      = "t9";
    static BARCODE_CODE128      = "ta";
    static BARCODE_GS1_128      = "tb";
    static BARCODE_RSS          = "tc";
    static BARCODE_CODE93       = "td";
    static BARCODE_POSTNET      = "te";
    static BARCODE_UPC_EXTENTION = "tf";

    static BARCODE_CHARS        = "r1";
    static BARCODE_NO_CHARS     = "r0";

    static BARCODE_WIDTH_XXS    = "w4";
    static BARCODE_WIDTH_XS     = "w0";
    static BARCODE_WIDTH_S      = "w1";
    static BARCODE_WIDTH_M      = "w2";
    static BARCODE_WIDTH_L      = "w3";

    static BARCODE_RATIO_2_1     = "z0";
    static BARCODE_RATIO_25_1    = "z1";
    static BARCODE_RATIO_3_1     = "z2";

    // 2D Barcode Parameters
    static BARCODE_2D_CELL_SIZE_3   = "\x03";
    static BARCODE_2D_CELL_SIZE_4   = "\x04";
    static BARCODE_2D_CELL_SIZE_5   = "\x05";
    static BARCODE_2D_CELL_SIZE_6   = "\x06";
    static BARCODE_2D_CELL_SIZE_8   = "\x08";
    static BARCODE_2D_CELL_SIZE_10  = "\x0A";

    static BARCODE_2D_SYMBOL_MODEL_1    = "\x01";
    static BARCODE_2D_SYMBOL_MODEL_2    = "\x02";
    static BARCODE_2D_SYMBOL_MICRO_QR   = "\x03";

    static BARCODE_2D_STRUCTURE_NOT_PARTITIONED = "\x00";
    static BARCODE_2D_STRUCTURE_PARTITIONED     = "\x01";

    static BARCODE_2D_ERROR_CORRECTION_HIGH_DENSITY             = "\x01";
    static BARCODE_2D_ERROR_CORRECTION_STANDARD                 = "\x02";
    static BARCODE_2D_ERROR_CORRECTION_HIGH_RELIABILITY         = "\x03";
    static BARCODE_2D_ERROR_CORRECTION_ULTRA_HIGH_RELIABILITY   = "\x04";

    static BARCODE_2D_DATA_INPUT_AUTO   = "\x00";
    static BARCODE_2D_DATA_INPUT_MANUAL = "\x01";

    constructor(uart, init = true) {
        _uart = uart;
        _buffer = blob();

        if (init) return initialize();
    }

    function initialize() {
        _uart.write(CMD_ESCP_ENABLE); // Select ESC/P mode
        _uart.write(CMD_ESCP_INIT); // Initialize ESC/P mode

        return this;
    }


    // Formating commands
    function setOrientation(orientation) {
        // Create a new buffer that we prepend all of this information to
        local orientationBuffer = blob();

        // Set the orientation
        orientationBuffer.writestring(CMD_SET_ORIENTATION);
        orientationBuffer.writestring(orientation);

        _uart.write(orientationBuffer);

        return this;
    }

    function setRightMargin(column) {
        return _setMargin(CMD_SET_RIGHT_MARGIN, column);
    }

    function setLeftMargin(column) {
        return _setMargin(CMD_SET_LEFT_MARGIN, column);;
    }

    function setFont(font) {
        if (font < 0 || font > 4) throw "Unknown font";

        _buffer.writestring(CMD_SET_FONT);
        _buffer.writen(font, 'b');

        return this;
    }

    function setFontSize(size) {
        if (size != 24 && size != 32 && size != 48) throw "Invalid font size";

        _buffer.writestring(CMD_SET_FONT_SIZE)
        _buffer.writen(size, 'b');
        _buffer.writen(0, 'b');

        return this;
    }

    // Text commands
    function write(text, options = 0) {
        local beforeText = "";
        local afterText = "";

        if (options & ITALIC) {
            beforeText  += CMD_ITALIC_START;
            afterText   += CMD_ITALIC_STOP;
        }

        if (options & BOLD) {
            beforeText  += CMD_BOLD_START;
            afterText   += CMD_BOLD_STOP;
        }

        if (options & UNDERLINE) {
            beforeText  += CMD_UNDERLINE_START;
            afterText   += CMD_UNDERLINE_STOP;
        }

        _buffer.writestring(beforeText + text + afterText);

        return this;
    }

    function writen(text, options = 0) {
        return write(text + TEXT_NEWLINE, options);
    }

    function newline() {
        return write(TEXT_NEWLINE);
    }

    // Barcode commands
    function writeBarcode(data, config = {}) {
        // Set defaults
        if(!("type" in config)) { config.type <- BARCODE_CODE39; }
        if(!("charsBelowBarcode" in config)) { config.charsBelowBarcode <- true; }
        if(!("width" in config)) { config.width <- BARCODE_WIDTH_XS; }
        if(!("height" in config)) { config.height <- 0.5; }
        if(!("ratio" in config)) { config.ratio <- BARCODE_RATIO_2_1; }

        // Start the barcode
        _buffer.writestring(CMD_BARCODE);

        // Set the type
        _buffer.writestring(config.type);

        // Set the text option
        if (config.charsBelowBarcode) {
            _buffer.writestring(BARCODE_CHARS);
        } else {
            _buffer.writestring(BARCODE_NO_CHARS);
        }

        // Set the width
        _buffer.writestring(config.width);

        // Convert height to dots
        local h = (config.height*300).tointeger();
        // Set the height
        _buffer.writestring("h");               // Height marker
        _buffer.writen(h & 0xFF, 'b');          // Lower bit of height
        _buffer.writen((h / 256) & 0xFF, 'b');  // Upper bit of height

        // Set the ratio of thick to thin bars
        _buffer.writestring(config.ratio);

        // Set data
        _buffer.writestring("\x62");
        _buffer.writestring(data);

        // End the barcode
        if (config.type == BARCODE_CODE128 || config.type == BARCODE_GS1_128 || config.type == BARCODE_CODE93) {
            _buffer.writestring("\x5C\x5C\x5C");
        } else {
            _buffer.writestring("\x5C");
        }

        return this;
    }

    function write2dBarcode(data, config = {}) {
        // Set defaults
        if (!("cell_size" in config)) { config.cell_size <- BARCODE_2D_CELL_SIZE_3; }
        if (!("symbol_type" in config)) { config.symbol_type <- BARCODE_2D_SYMBOL_MODEL_2; }
        if (!("structured_append_partitioned" in config)) { config.structured_append_partitioned <- false; }
        if (!("code_number" in config)) { config.code_number <- 0; }
        if (!("num_partitions" in config)) { config.num_partitions <- 0; }

        if (!("parity_data" in config)) { config["parity_data"] <- 0; }
        if (!("error_correction" in config)) { config["error_correction"] <- BARCODE_2D_ERROR_CORRECTION_STANDARD; }
        if (!("data_input_method" in config)) { config["data_input_method"] <- BARCODE_2D_DATA_INPUT_AUTO; }

        // Check ranges
        if (config.structured_append_partitioned) {
            config.structured_append <- BARCODE_2D_STRUCTURE_PARTITIONED;
            if (config.code_number < 1 || config.code_number > 16) throw "Unknown code number";
            if (config.num_partitions < 2 || config.num_partitions > 16) throw "Unknown number of partitions";
        } else {
            config.structured_append <- BARCODE_2D_STRUCTURE_NOT_PARTITIONED;
            config.code_number = "\x00";
            config.num_partitions = "\x00";
            config.parity_data = "\x00";
        }

        // Start the barcode
        _buffer.writestring(CMD_2D_BARCODE);

        // Set the parameters
        _buffer.writestring(config.cell_size);
        _buffer.writestring(config.symbol_type);
        _buffer.writestring(config.structured_append);
        _buffer.writestring(config.code_number);
        _buffer.writestring(config.num_partitions);
        _buffer.writestring(config.parity_data);
        _buffer.writestring(config.error_correction);
        _buffer.writestring(config.data_input_method);

        // Write data
        _buffer.writestring(data);

        // End the barcode
        _buffer.writestring("\x5C\x5C\x5C");

        return this;
    }

    // Prints the label
    function print() {
        _buffer.writestring(PAGE_FEED);
        _uart.write(_buffer);
        _buffer = blob();
    }

    function _setMargin(command, margin) {
        local marginBuffer = blob();
        marginBuffer.writestring(command);
        marginBuffer.writen(margin & 0xFF, 'b');

        _uart.write(marginBuffer);

        return this;
    }

    function _typeof() {
        return "QL720NW";
    }
}//line 14 "device.nut"

// USB Driver Library
//line 1 "USB.device.lib.nut"
// MIT License
// 
// Copyright 2017 Electric Imp
// 
// SPDX-License-Identifier: MIT
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
// 
class USB {

    static VERSION = "1.0.0";

    constructor() {
        const USB_ENDPOINT_CONTROL = 0x00;
        const USB_ENDPOINT_ISCHRONOUS = 0x01;
        const USB_ENDPOINT_BULK = 0x02;
        const USB_ENDPOINT_INTERRUPT = 0x03;

        const USB_SETUP_HOST_TO_DEVICE = 0x00;
        const USB_SETUP_DEVICE_TO_HOST = 0x80;
        const USB_SETUP_TYPE_STANDARD = 0x00;
        const USB_SETUP_TYPE_CLASS = 0x20;
        const USB_SETUP_TYPE_VENDOR = 0x40;
        const USB_SETUP_RECIPIENT_DEVICE = 0x00;
        const USB_SETUP_RECIPIENT_INTERFACE = 0x01;
        const USB_SETUP_RECIPIENT_ENDPOINT = 0x02;
        const USB_SETUP_RECIPIENT_OTHER = 0x03;

        const USB_REQUEST_GET_STATUS = 0;
        const USB_REQUEST_CLEAR_FEATURE = 1;
        const USB_REQUEST_SET_FEATURE = 3;
        const USB_REQUEST_SET_ADDRESS = 5;
        const USB_REQUEST_GET_DESCRIPTOR = 6;
        const USB_REQUEST_SET_DESCRIPTOR = 7;
        const USB_REQUEST_GET_CONFIGURATION = 8;
        const USB_REQUEST_SET_CONFIGURATION = 9;
        const USB_REQUEST_GET_INTERFACE = 10;
        const USB_REQUEST_SET_INTERFACE = 11;
        const USB_REQUEST_SYNCH_FRAME = 12;

        const USB_DEVICE_DESCRIPTOR_LENGTH = 0x12;
        const USB_CONFIGURATION_DESCRIPTOR_LENGTH = 0x09;

        const USB_DESCRIPTOR_DEVICE = 0x01;
        const USB_DESCRIPTOR_CONFIGURATION = 0x02;
        const USB_DESCRIPTOR_STRING = 0x03;
        const USB_DESCRIPTOR_INTERFACE = 0x04;
        const USB_DESCRIPTOR_ENDPOINT = 0x05;
        const USB_DESCRIPTOR_DEVICE_QUALIFIER = 0x06;
        const USB_DESCRIPTOR_OTHER_SPEED = 0x07;
        const USB_DESCRIPTOR_INTERFACE_POWER = 0x08;
        const USB_DESCRIPTOR_OTG = 0x09;
        const USB_DESCRIPTOR_HID = 0x21;

        const USB_DIRECTION_OUT = 0x0;
        const USB_DIRECTION_IN = 0x1;
    }
}


// 
// Usb wrapper class.
// 
class USB.Host {

    _eventHandlers = null;
    _customEventHandlers = null;
    _driver = null;
    _autoConfiguredPins = false;
    _bulkTransferQueue = null;
    _address = 1;
    _registeredDrivers = null;
    _usb = null
    _driverCallback = null;
    _DEBUG = false;
    _busy = false;

    // 
    // Constructor
    // 
    // @param  {Object} usb Internal `hardware.usb` object
    // @param  {Boolean} flag to specify whether to configure pins for usb usage (see https://electricimp.com/docs/hardware/imp/imp005pinmux/#usb)
    // 
    constructor(usb, autoConfPins = true) {
        _usb = usb;
        _bulkTransferQueue = [];
        _registeredDrivers = {};
        _eventHandlers = {};
        _customEventHandlers = {};

        if (autoConfPins) {
            _autoConfiguredPins = true;
            // Configure the pins required for usb
            hardware.pinW.configure(DIGITAL_IN_PULLUP);
            hardware.pinR.configure(DIGITAL_OUT, 1);
        }


        _eventHandlers[USB_DEVICE_CONNECTED] <- _onDeviceConnected.bindenv(this);
        _eventHandlers[USB_DEVICE_DISCONNECTED] <- _onDeviceDisconnected.bindenv(this);
        _eventHandlers[USB_TRANSFER_COMPLETED] <- _onTransferCompleted.bindenv(this);
        _eventHandlers[USB_UNRECOVERABLE_ERROR] <- _onHardwareError.bindenv(this);
        _usb.configure(_onEvent.bindenv(this));
    }


    // 
    // Meta method to overrride typeof instance
    // 
    // @return {String} typeof instance of class
    // 
    function _typeof() {
        return "USB.Host";
    }


    // 
    // Registers a list of VID PID pairs to a driver class with usb host. This driver will be instantiated
    // when a matching VID PID device is connected via usb
    // 
    // @param {Class} driverClass Class to be instantiated when a matching VID PID device is connected
    // @param {Array of Tables} Array of VID PID tables
    // 
    function registerDriver(driverClass, identifiers) {

        // Check the driver class is using the correct base class
        if (!(driverClass.isUSBDriver == true)) {
            throw "This driver is not a valid usb driver.";
            return;
        }

        // identifiers must be an array
        if (typeof identifiers != "array") {
            throw "Identifiers for driver must be of type array.";
            return;
        }

        // Register all indentifiers to corresponding class
        foreach (k, identifier in identifiers) {
            foreach (VID, PIDS in identifier) {
                if (typeof PIDS != "array") {
                    PIDS = [PIDS];
                }

                foreach (vidIndex, PID in PIDS) {
                    local vpid = format("%04x%04x", VID, PID);
                    // store all VID PID combos
                    _registeredDrivers[vpid] <- driverClass;
                }
            }
        }
    }


    // 
    // Returns currently active driver object. Will be null if no driver found.
    // 
    function getDriver() {
        return _driver;
    }


    // 
    // Subscribe callback to call on "eventName" event
    // 
    // @param  {String}   eventName The event name to subscribe callback to
    // @param  {Function} cb        Function to call when event emitted
    // 
    function on(eventName, cb) {
        _customEventHandlers[eventName] <- cb;
    }


    // 
    // Clear callback from "eventName" event
    // 
    // @param eventName The event name to unsubsribe from
    // 
    function off(eventName) {
        if (eventName in _customEventHandlers) {
            delete _customEventHandlers[eventName];
        }
    }


    // 
    // Opens a specific endpoint based on params
    // 
    // @param  {Float}        speed             The speed in Mb/s. Must be either 1.5 or 12
    // @param  {Integer}      deviceAddress     The address of the device
    // @param  {Integer}      interfaceNumber   The endpoint’s interface number
    // @param  {Integer}      type              The type of the endpoint
    // @param  {Integer}      maxPacketSize     The maximum size of packet that can be written or read on this endpoint
    // @param  {Integer}      endpointAddress   The address of the endpoint
    // 
    function _openEndpoint(speed, deviceAddress, interfaceNumber, type, maxPacketSize, endpointAddress) {
        _usb.openendpoint(speed, deviceAddress, interfaceNumber, type, maxPacketSize, endpointAddress);
    }


    // 
    // Set control transfer USB_REQUEST_SET_ADDRESS device address
    // 
    // @param {Integer}    address          An index value determined by the specific USB request (range 0x0000-0xFFFF)
    // @param {Float}      speed            The speed in Mb/s. Must be either 1.5 or 12
    // @param {Integer}    maxPacketSize    The maximum size of packet that can be written or read on this endpoint
    // 
    function _setAddress(address, speed, maxPacketSize) {
        _usb.controltransfer(
            speed,
            0,
            0,
            USB_SETUP_HOST_TO_DEVICE | USB_SETUP_RECIPIENT_DEVICE,
            USB_REQUEST_SET_ADDRESS,
            address,
            0,
            maxPacketSize
        );
    }


    // 
    // Set control transfer USB_REQUEST_SET_CONFIGURATION value
    // 
    // @param {Integer}    deviceAddress    The address of the device
    // @param {Float}      speed            The speed in Mb/s. Must be either 1.5 or 12
    // @param {Integer}    maxPacketSize    The maximum size of packet that can be written or read on this endpoint
    // @param {Integer}    value          An index value determined by the specific USB request (range 0x0000-0xFFFF)
    // 
    function _setConfiguration(deviceAddress, speed, maxPacketSize, value) {
        _usb.controltransfer(
            speed,
            deviceAddress,
            0,
            USB_SETUP_HOST_TO_DEVICE | USB_SETUP_RECIPIENT_DEVICE,
            USB_REQUEST_SET_CONFIGURATION,
            value,
            0,
            maxPacketSize
        );
    }


    // 
    // Creates a USB driver instance if vid/pid combo matches registered devices
    // 
    // @param {Tables} Table with keys "vendorid" and "productid" of the device
    // 
    function _create(identifiers) {
        local vid = identifiers["vendorid"];
        local pid = identifiers["productid"];
        local vpid = format("%04x%04x", vid, pid);

        if ((vpid in _registeredDrivers) && _registeredDrivers[vpid] != null) {
            return _registeredDrivers[vpid](this);
        }
        return null;
    }


    // 
    // Usb connected callback
    // 
    // @param {Table} eventdetails  Table containing the details of the connection event
    // 
    function _onDeviceConnected(eventdetails) {
        if (_driver != null) {
            server.error("UsbHost: Device already connected");
            return;
        }

        local speed = eventdetails["speed"];
        local descriptors = eventdetails["descriptors"];
        local maxPacketSize = descriptors["maxpacketsize0"];
        if (_DEBUG) {
            _logDescriptors(speed, descriptors);
        }

        // Try to create the driver for connected device
        _driver = _create(descriptors);

        if (_driver == null) {
            server.error("UsbHost: No driver found for device");
            return;
        }

        _setAddress(_address, speed, maxPacketSize);
        _driver.connect(_address, speed, descriptors);
        // Emit connected event that user can subscribe to
        _onEvent("connected", _driver);
    }


    // 
    // Device disconnected callback
    // 
    // @param {Table}  eventDetails  Table containing details about the disconnection event
    function _onDeviceDisconnected(eventdetails) {
        if (_driver != null) {
            // Emit disconnected event
            _onEvent("disconnected", typeof _driver);
            _driver = null;
        }
    }


    // 
    // Bulk transfer data blob
    // 
    // @param {Integer}    address          The address of the device
    // @param {Integer}    endpoint         The address of the endpoint
    // @param {Integer}    type             Integer
    // @param {Blob}       data             The data to be transferred
    // 
    function _bulkTransfer(address, endpoint, type, data) {
        // Push to the end of the queue
        _pushBulkTransferQueue([_usb, address, endpoint, type, data]);
        // Process request at the front of the queue
        _popBulkTransferQueue();
    }


    // 
    // Control transfer wrapper method
    // 
    // @param {Float}               speed            The speed in Mb/s. Must be either 1.5 or 12
    // @param {Integer}             deviceAddress    The address of the device
    // @param {Integer (bitfield)}  requestType      The type of the endpoint
    // @param {Integer}             request          The specific USB request
    // @param {Integer}             value            A value determined by the specific USB request (range 0x0000-0xFFFF)
    // @param {Integer}             index            An index value determined by the specific USB request (range 0x0000-0xFFFF)
    // @param {Integer}             maxPacketSize    The maximum size of packet that can be written or read on this endpoint
    // 
    function _controlTransfer(speed, deviceAddress, requestType, request, value, index, maxPacketSize) {
        _usb.controltransfer(
            speed,
            deviceAddress,
            0,
            requestType,
            request,
            value,
            index,
            maxPacketSize
        );
    }


    // 
    // Called when a Usb request is succesfully completed
    // 
    // @param  {Table} eventdetails Table with the transfer event details
    // 
    function _onTransferCompleted(eventdetails) {

        _busy = false;
        if (_driver) {
            // Pass complete event to driver
            _driver._transferComplete(eventdetails);
        }
        // Process any queued requests
        _popBulkTransferQueue();
    }


    // 
    // Callback on hardware error
    // 
    // @param  {Table} eventdetails  Table with the hardware event details
    // 
    function _onHardwareError(eventdetails) {
        server.error("UsbHost: Internal unrecoverable usb error. Resetting the bus.");
        usb.disable();
        _usb.configure(_onEvent.bindenv(this));
    }


    // 
    // Push bulk transfer request to back of queue
    // 
    // @params {Array} request  bulktransfer params to be passed via the .acall function in format [_usb, address, endpoint, type, data].
    // 
    function _pushBulkTransferQueue(request) {
        _bulkTransferQueue.push(request);
    }


    // 
    // Pop bulk transfer request to front of queue
    // 
    function _popBulkTransferQueue() {
        if (!_busy && _bulkTransferQueue.len() > 0) {
            _usb.generaltransfer.acall(_bulkTransferQueue.remove(0));
            _busy = true;
        }
    }


    // Emit event "eventtype" with eventdetails
    // 
    // @param {String}  Event name to emit
    // @param {any}     Data to pass to event listener callback
    // 
    function _onEvent(eventtype, eventdetails) {
        // Handle event internally first
        if (eventtype in _eventHandlers) {
            _eventHandlers[eventtype](eventdetails);
        }
        // Pass event to any subscribers
        if (eventtype in _customEventHandlers) {
            _customEventHandlers[eventtype](eventdetails);
        }
    }


    // 
    // Parses and returns descriptors for a device as a string
    // 
    // @param  {Integer}    deviceAddress  The address of the device
    // @param  {Float}      speed          The speed in Mb/s. Must be either 1.5 or 12
    // @param  {Integer}    maxPacketSize  The maximum size of packet that can be written or read on this endpoint
    // @param  {Integer}    index          An index value determined by the specific USB request (range 0x0000-0xFFFF)
    // @return {String}                    Descriptors for a device as a string
    // 
    function _getStringDescriptor(deviceAddress, speed, maxPacketSize, index) {
        if (index == 0) {
            return "";
        }
        local buffer = blob(2);
        _usb.controltransfer(
            speed,
            deviceAddress,
            0,
            USB_SETUP_DEVICE_TO_HOST | USB_SETUP_RECIPIENT_DEVICE,
            USB_REQUEST_GET_DESCRIPTOR,
            (USB_DESCRIPTOR_STRING << 8) | index,
            0,
            maxPacketSize,
            buffer
        );

        local stringSize = buffer[0];
        buffer = blob(stringSize);
        _usb.controltransfer(
            speed,
            deviceAddress,
            0,
            USB_SETUP_DEVICE_TO_HOST | USB_SETUP_RECIPIENT_DEVICE,
            USB_REQUEST_GET_DESCRIPTOR,
            (USB_DESCRIPTOR_STRING << 8) | index,
            0,
            maxPacketSize,
            buffer
        );

        // String descriptors are zero-terminated, unicode.
        // This could be done better.
        buffer.seek(2, 'b');
        local description = blob();
        while (!buffer.eos()) {
            local char = buffer.readn('b');
            if (char != 0) {
                description.writen(char, 'b');
            }
            buffer.readn('b');
        }
        return description.tostring();
    }


    // 
    // Prints the descriptors for a device
    // 
    // @param  {Float}  speed       The speed in Mb/s. Must be either 1.5 or 12
    // @param  {Table}  descriptor  The descriptors received from the device
    // 
    function _logDescriptors(speed, descriptor) {
        local maxPacketSize = descriptor["maxpacketsize0"];
        server.log("USB Device Connected, speed=" + speed + " Mbit/s");
        server.log(format("usb = 0x%04x", descriptor["usb"]));
        server.log(format("class = 0x%02x", descriptor["class"]));
        server.log(format("subclass = 0x%02x", descriptor["subclass"]));
        server.log(format("protocol = 0x%02x", descriptor["protocol"]));
        server.log(format("maxpacketsize0 = 0x%02x", maxPacketSize));
        local manufacturer = _getStringDescriptor(0, speed, maxPacketSize, descriptor["manufacturer"]);
        server.log(format("VID = 0x%04x (%s)", descriptor["vendorid"], manufacturer));
        local product = _getStringDescriptor(0, speed, maxPacketSize, descriptor["product"]);
        server.log(format("PID = 0x%04x (%s)", descriptor["productid"], product));
        local serial = _getStringDescriptor(0, speed, maxPacketSize, descriptor["serial"]);
        server.log(format("device = 0x%04x (%s)", descriptor["device"], serial));

        local configuration = descriptor["configurations"][0];
        local configurationString = _getStringDescriptor(0, speed, maxPacketSize, configuration["configuration"]);
        server.log(format("Configuration: 0x%02x (%s)", configuration["value"], configurationString));
        server.log(format("  attributes = 0x%02x", configuration["attributes"]));
        server.log(format("  maxpower = 0x%02x", configuration["maxpower"]));

        foreach (interface in configuration["interfaces"]) {
            local interfaceDescription = _getStringDescriptor(0, speed, maxPacketSize, interface["interface"]);
            server.log(format("  Interface: 0x%02x (%s)", interface["interfacenumber"], interfaceDescription));
            server.log(format("    altsetting = 0x%02x", interface["altsetting"]));
            server.log(format("    class=0x%02x", interface["class"]));
            server.log(format("    subclass = 0x%02x", interface["subclass"]));
            server.log(format("    protocol = 0x%02x", interface["protocol"]));

            foreach (endpoint in interface["endpoints"]) {
                local address = endpoint["address"];
                local endpointNumber = address & 0x3;
                local direction = (address & 0x80) >> 7;
                local attributes = endpoint["attributes"];
                local type = _endpointTypeString(attributes);
                server.log(format("    Endpoint: 0x%02x (ENDPOINT %d %s %s)", address, endpointNumber, type, _directionString(direction)));
                server.log(format("      attributes = 0x%02x", attributes));
                server.log(format("      maxpacketsize = 0x%02x", endpoint["maxpacketsize"]));
                server.log(format("      interval = 0x%02x", endpoint["interval"]));
            }
        }
    }


    // 
    // Extract the direction from and endpoint address
    // 
    // @param  {Integer} direction  Direction of data as an Integer
    // @return {String}             Direction of data as a String
    // 
    function _directionString(direction) {
        if (direction == USB_DIRECTION_IN) {
            return "IN";
        } else if (direction == USB_DIRECTION_OUT) {
            return "OUT";
        } else {
            return "UNKNOWN";
        }
    }


    // 
    // Extract the endpoint type from attributes byte
    // 
    // @param {Integer} attributes  Transfer attributes retrived from device descriptors
    // @return {String}             String representing type of transfer
    // 
    function _endpointTypeString(attributes) {
        local type = attributes & 0x3;
        if (type == 0) {
            return "CONTROL";
        } else if (type == 1) {
            return "ISOCHRONOUS";
        } else if (type == 2) {
            return "BULK";
        } else if (type == 3) {
            return "INTERRUPT";
        }
    }
};


// 
// Usb control tranfer wrapper class
// 
class USB.ControlEndpoint {

    _usb = null;
    _deviceAddress = null;
    _speed = null;
    _maxPacketSize = null;

    // 
    // Contructor
    // 
    // @param  {UsbHostClass} usb       Instance of the UsbHostClass
    // @param  {Integer} deviceAddress  The address of the device
    // @param  {Float} speed            The speed in Mb/s. Must be either 1.5 or 12
    // @param  {Integer} maxPacketSize  The maximum size of packet that can be written or read on this endpoint
    // 
    constructor(usb, deviceAddress, speed, maxPacketSize) {
        _usb = usb;
        _deviceAddress = deviceAddress;
        _speed = speed;
        _maxPacketSize = maxPacketSize;
    }


    // 
    // Configures the control endpoint
    // 
    // @param {Integer} value   A value determined by the specific USB request (range 0x0000-0xFFFF)
    // 
    function _setConfiguration(value) {
        _usb._setConfiguration(_deviceAddress, _speed, _maxPacketSize, value);
    }


    // 
    // Retrieves and returns the string descriptors from the UsbHost.
    // 
    // @param {Integer} index   An index value determined by the specific USB request (range 0x0000-0xFFFF)
    // @return {String}         String of device descriptors
    // 
    function getStringDescriptor(index) {
        return _usb._getStringDescriptor(_deviceAddress, _speed, _maxPacketSize, index);
    }


    // 
    // Makes a control transfer
    // 
    // @param  {Integer (bitfield)} requestType  The type of the endpoint
    // @param  {Integer}            request      The specific USB request
    // @param  {Integer}            value        A value determined by the specific USB request (range 0x0000-0xFFFF)
    // @param  {Integer}            index        An index value determined by the specific USB request (range 0x0000-0xFFFF)
    // 
    function send(requestType, request, value, index) {
        return _usb._controlTransfer(_speed, _deviceAddress, requestType, request, value, index, _maxPacketSize)
    }
}


// 
// Usb bulk transfer wrapper super class
// 
class USB.BulkEndpoint {

    _usb = null;
    _deviceAddress = null;
    _endpointAddress = null;


    // 
    // Constructor
    // 
    // @param  {UsbHostClass} usb               Instance of the UsbHostClass
    // @param  {Float}        speed             The speed in Mb/s. Must be either 1.5 or 12
    // @param  {Integer}      deviceAddress     The address of the device
    // @param  {Integer}      interfaceNumber   The endpoint’s interface number
    // @param  {Integer}      endpointAddress   The address of the endpoint
    // @param  {Integer}       maxPacketSize    The maximum size of packet that can be written or read on this endpoint
    // 
    constructor(usb, speed, deviceAddress, interfaceNumber, endpointAddress, maxPacketSize) {
        _usb = usb;
        if (_usb._DEBUG) server.log(format("Opening bulk endpoint 0x%02x", endpointAddress));

        _deviceAddress = deviceAddress;
        _endpointAddress = endpointAddress;
        _usb._openEndpoint(speed, _deviceAddress, interfaceNumber, USB_ENDPOINT_BULK, maxPacketSize, _endpointAddress);
    }
}

// 
// Usb bulk in transfer wrapper class
// 
class USB.BulkInEndpoint extends USB.BulkEndpoint {

    _data = null;

    // 
    // Constructor
    // 
    // @param  {UsbHostClass} usb               Instance of the UsbHostClass
    // @param  {Float}        speed             The speed in Mb/s. Must be either 1.5 or 12
    // @param  {Integer}      deviceAddress     The address of the device
    // @param  {Integer}      interfaceNumber   The endpoint’s interface number
    // @param  {Integer}      endpointAddress   The address of the endpoint
    // @param  {Integer}       maxPacketSize    The maximum size of packet that can be written or read on this endpoint
    // 
    constructor(usb, speed, deviceAddress, interfaceNumber, endpointAddress, maxPacketSize) {
        assert((endpointAddress & 0x80) >> 7 == USB_DIRECTION_IN);
        base.constructor(usb, speed, deviceAddress, interfaceNumber, endpointAddress, maxPacketSize);
    }

    // 
    // Reads incoming data
    // 
    // @param {String/Blob} data to be read
    // 
    function read(data) {
        _data = data;
        _usb._bulkTransfer(_deviceAddress, _endpointAddress, USB_ENDPOINT_BULK, data);
    }


    // 
    // Mark transfer as complete
    // 
    // @param {Table} details  detials of the transfer
    // @return result of bulkin transfer
    function done(details) {
        assert(details["endpoint"] == _endpointAddress);
        _data.resize(details["length"]);
        // assign locally
        local data = _data;
        // blank current data
        _data = null;
        return data;
    }


}


// 
// Usb bulk out transfer wrapper classs
// 
class USB.BulkOutEndpoint extends USB.BulkEndpoint {

    _data = null;

    // 
    // Constructor
    // 
    // @param  {UsbHostClass} usb               Instance of the UsbHostClass
    // @param  {Float}        speed             The speed in Mb/s. Must be either 1.5 or 12
    // @param  {Integer}      deviceAddress     The address of the device
    // @param  {Integer}      interfaceNumber   The endpoint’s interface number
    // @param  {Integer}      endpointAddress   The address of the endpoint
    // @param  {Integer}       maxPacketSize    The maximum size of packet that can be written or read on this endpoint
    // 
    constructor(usb, speed, deviceAddress, interfaceNumber, endpointAddress, maxPacketSize) {
        assert((endpointAddress & 0x80) >> 7 == USB_DIRECTION_OUT);
        base.constructor(usb, speed, deviceAddress, interfaceNumber, endpointAddress, maxPacketSize);
    }


    // 
    // Writes data to usb via bulk transfer
    // 
    // @param {String/Blob} data to be written
    // 
    function write(data) {
        _data = data;
        _usb._bulkTransfer(_deviceAddress, _endpointAddress, USB_ENDPOINT_BULK, data);
    }


    // 
    // Called when transfer is complete
    // 
    // @param  {Table}   details    detials of the transfer
    // 
    function done(details) {
        assert(details["endpoint"] == _endpointAddress);
        _data = null;
    }


}


// 
// Super class for Usb driver classes.
// 
class USB.DriverBase {

    static VERSION = "1.0.0";

    static isUSBDriver = true;

    _usb = null;
    _controlEndpoint = null;
    _eventHandlers = {};

    constructor(usb) {
        _usb = usb;
    }


    // 
    // Set up the usb to connect to this device
    // 
    // @param  {Integer} deviceAddress The address of the device
    // @param  {Float}   speed         The speed in Mb/s. Must be either 1.5 or 12
    // @param  {String}  descriptors   The descriptors received from device
    // 
    function connect(deviceAddress, speed, descriptors) {
        _setupEndpoints(deviceAddress, speed, descriptors);
        _configure(descriptors["device"]);
        _start();
    }


    // 
    // Should return an array of VID PID combination tables.
    // 
    function getIdentifiers() {
        throw "Method not implemented";
    }


    // 
    // Registers a callback to a specific event
    // 
    // @param  {String}   eventType The event name to subscribe callback to
    // @param  {Function} cb        Function to call when event emitted
    // 
    function on(eventType, cb) {
        _eventHandlers[eventType] <- cb;
    }


    // 
    // Clears event listener on specific event
    // 
    // @param  {String}   eventName The event name to unsubscribe from
    // 
    function off(eventName) {
        if (eventName in _eventHandlers) {
            delete _eventHandlers[eventName];
        }
    }


    // 
    // Handle case when a Usb request is succesfully completed
    // 
    function _transferComplete(eventdetails) {
        throw "Method not implemented";
    }


    // 
    // Initialize and set up all required endpoints
    // 
    // @param  {Integer} deviceAddress The address of the device
    // @param  {Float}   speed         The speed in Mb/s. Must be either 1.5 or 12
    // @param  {String}  descriptors   The descriptors received from device
    // 
    function _setupEndpoints(deviceAddress, speed, descriptors) {
        if (_usb._DEBUG) server.log(format("Driver connecting at address 0x%02x", deviceAddress));
        _deviceAddress = deviceAddress;
        _controlEndpoint = USB.ControlEndpoint(_usb, deviceAddress, speed, descriptors["maxpacketsize0"]);

        // Select configuration
        local configuration = descriptors["configurations"][0];

        if (_usb._DEBUG) server.log(format("Setting configuration 0x%02x (%s)", configuration["value"], _controlEndpoint.getStringDescriptor(configuration["configuration"])));
        _controlEndpoint._setConfiguration(configuration["value"]);

        // Select interface
        local interface = configuration["interfaces"][0];
        local interfacenumber = interface["interfacenumber"];

        foreach (endpoint in interface["endpoints"]) {
            local address = endpoint["address"];
            local maxPacketSize = endpoint["maxpacketsize"];
            if ((endpoint["attributes"] & 0x3) == 2) {
                if ((address & 0x80) >> 7 == USB_DIRECTION_OUT) {
                    _bulkOut = USB.BulkOutEndpoint(_usb, speed, _deviceAddress, interfacenumber, address, maxPacketSize);
                } else {
                    _bulkIn = USB.BulkInEndpoint(_usb, speed, _deviceAddress, interfacenumber, address, maxPacketSize);
                }
            }
        }
    }


    // 
    // Set up basic parameters using control transfer
    // 
    // @param {Integer} device key receieved in descriptors
    // 
    function _configure(device) {

        if (_usb._DEBUG) server.log(format("Configuring for device version 0x%04x", device));

        // Set Baud Rate
        local baud = 115200;
        local baudValue;
        local baudIndex = 0;
        local divisor3 = 48000000 / 2 / baud; // divisor shifted 3 bits to the left

        if (device == 0x0200) { // FT232AM
            if ((divisor3 & 0x07) == 0x07) {
                divisor3++; // round x.7/8 up to x+1
            }

            baudValue = divisor3 >> 3;
            divisor3 = divisor3 & 0x7;

            if (divisor3 == 1) {
                baudValue = baudValue | 0xc000; // 0.125
            } else if (divisor3 >= 4) {
                baudValue = baudValue | 0x4000; // 0.5
            } else if (divisor3 != 0) {
                baudValue = baudValue | 0x8000; // 0.25
            }

            if (baudValue == 1) {
                baudValue = 0; // special case for maximum baud rate
            }

        } else {
            local divfrac = [0, 3, 2, 0, 1, 1, 2, 3];
            local divindex = [0, 0, 0, 1, 0, 1, 1, 1];

            baudValue = divisor3 >> 3;
            baudValue = baudValue | (divfrac[divisor3 & 0x7] << 14);

            baudIndex = divindex[divisor3 & 0x7];

            // Deal with special cases for highest baud rates.
            if (baudValue == 1) {
                baudValue = 0; // 1.0
            } else if (baudValue == 0x4001) {
                baudValue = 1; // 1.5
            }
        }

        _controlEndpoint.send(FTDI_REQUEST_FTDI_OUT, FTDI_SIO_SET_BAUD_RATE, baudValue, baudIndex);

        const xon = 0x11;
        const xoff = 0x13;

        _controlEndpoint.send(FTDI_REQUEST_FTDI_OUT, FTDI_SIO_SET_FLOW_CTRL, xon | (xoff << 8), FTDI_SIO_DISABLE_FLOW_CTRL << 8);
    }


    // Emit event "eventtype" with eventdetails
    // 
    // @param {String}  Event name to emit
    // @param {any}     Data to pass to event listener callback
    // 
    function _onEvent(eventtype, eventdetails) {
        // Handle event internally first
        if (eventtype in _eventHandlers) {
            _eventHandlers[eventtype](eventdetails);
        }
    }


    // 
    // Instantiate the buffer
    // 
    function _start() {
        _bulkIn.read(blob(1));
    }
};//line 1 "FtdiUsbDriver.device.lib.nut"
// MIT License
// 
// Copyright 2017 Electric Imp
// 
// SPDX-License-Identifier: MIT
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

class FtdiUsbDriver extends USB.DriverBase {

    static VERSION = "1.0.0";

    // FTDI vid and pid
    static VID = 0x0403;
    static PID = 0x6001;

    // FTDI driver
    static FTDI_REQUEST_FTDI_OUT = 0x40;
    static FTDI_SIO_SET_BAUD_RATE = 3;
    static FTDI_SIO_SET_FLOW_CTRL = 2;
    static FTDI_SIO_DISABLE_FLOW_CTRL = 0;

    _deviceAddress = null;
    _bulkIn = null;
    _bulkOut = null;


    // 
    // Metafunction to return class name when typeof <instance> is run
    // 
    function _typeof() {
        return "FtdiUsbDriver";
    }


    // 
    // Returns an array of VID PID combination tables.
    // 
    // @return {Array of Tables} Array of VID PID Tables
    // 
    function getIdentifiers() {
        local identifiers = {};
        identifiers[VID] <-[PID];
        return [identifiers];
    }


    // 
    // Write string or blob to usb
    // 
    // @param  {String/Blob} data data to be sent via usb
    // 
    function write(data) {
        local _data = null;

        // Convert strings to blobs
        if (typeof data == "string") {
            _data = blob();
            _data.writestring(data);
        } else if (typeof data == "blob") {
            _data = data;
        } else {
            throw "Write data must of type string or blob";
            return;
        }

        // Write data via bulk transfer
        _bulkOut.write(_data);
    }
    

    // 
    // Handle a transfer complete event
    // 
    // @param  {Table} eventdetails Table with the transfer event details
    // 
    function _transferComplete(eventdetails) {
        local direction = (eventdetails["endpoint"] & 0x80) >> 7;
        if (direction == USB_DIRECTION_IN) {
            local readData = _bulkIn.done(eventdetails);
            if (readData.len() >= 3) {
                readData.seek(2);
                _onEvent("data", readData.readblob(readData.len()));
            }
            // Blank the buffer
            _bulkIn.read(blob(64 + 2));
        } else if (direction == USB_DIRECTION_OUT) {
            _bulkOut.done(eventdetails);
        }
    }


    // 
    // Initialize the buffer.
    // 
    function _start() {
        _bulkIn.read(blob(64 + 2));
    }
};//line 18 "device.nut"
// ADC Library
//line 1 "MCP3208.device.lib.nut"
class MCP3208 {

    static MCP3208_STARTBIT      = 0x10;
    static MCP3208_SINGLE_ENDED  = 0x08;
    static MCP3208_DIFF_MODE     = 0x00;

    static MCP3208_CHANNEL_0     = 0x00;
    static MCP3208_CHANNEL_1     = 0x01;
    static MCP3208_CHANNEL_2     = 0x02;
    static MCP3208_CHANNEL_3     = 0x03;
    static MCP3208_CHANNEL_4     = 0x04;
    static MCP3208_CHANNEL_5     = 0x05;
    static MCP3208_CHANNEL_6     = 0x06;
    static MCP3208_CHANNEL_7     = 0x07;

    _spi = null;
    _csPin = null;
    _vref = null;

    function constructor(spi, vref, cs = null) { 
        _spi = spi;
        _vref = vref;
        _csPin = cs;
        if (_csPin) _csPin.configure(DIGITAL_OUT, 1);
    }
    
    function readADC(channel) { 

        (_csPin == null) ? _spi.chipselect(1) : _csPin.write(0);
        
        // 3 byte command
        local sent = blob();
        sent.writen(0x06 | (channel >> 2), 'b');
        sent.writen((channel << 6) & 0xFF, 'b');
        sent.writen(0, 'b');
        
        local read = _spi.writeread(sent);

        (_csPin == null) ? _spi.chipselect(0) : _csPin.write(1);

        // Extract reading as volts
        local reading = ((((read[1] & 0x0f) << 8) | read[2]) / 4095.0) * _vref;
        
        return reading;
    }

    function readDifferential(in_minus, in_plus) {

        (_csPin == null) ? _spi.chipselect(1) : _csPin.write(0);
        
        local select = in_plus; // datasheet
        local sent = blob();
        
        sent.writen(0x04 | (select >> 2), 'b'); // only difference b/w read single
        // and read differential is the bit after the start bit
        sent.writen((select << 6) & 0xFF, 'b');
        sent.writen(0, 'b');
        
        local read = _spi.writeread(sent);

        (_csPin == null) ? _spi.chipselect(0) : _csPin.write(1);
        
        local reading = ((((read[1] & 0x0f) << 8) | read[2]) / 4095.0) * _vref;
        return reading;
    }
}


//line 20 "device.nut"

class AcceleratorTestingFactory {

    constructor(ssid, password) {
        FactoryTools.isFactoryFirmware(function(isFactoryEnv) {
            if (isFactoryEnv) {
                FactoryTools.isFactoryImp() ? RunFactoryFixture(ssid, password) : RunDeviceUnderTest();
            } else {
              server.log("This firmware is not running in the Factory Environment");
            }
        }.bindenv(this))
    }

//line 1 "RunFactoryFixture.device.nut"
RunFactoryFixture = class {

    static FIXTURE_BANNER = "AD DiscKit Tests";

    // How long to wait (seconds) after triggering BlinkUp before allowing another
    static BLINKUP_TIME = 5;

    // Flag used to prevent new BlinkUp triggers while BlinkUp is running
    sendingBlinkUp = false;

    FactoryFixture_005 = null;
    lcd = null;
    printer = null;

    _ssid = null;
    _password = null;

    constructor(ssid, password) {
        imp.enableblinkup(true);
        _ssid = ssid;
        _password = password;

        // Factory Fixture HAL
        FactoryFixture_005 = {
            "LED_RED" : hardware.pinF,
            "LED_GREEN" : hardware.pinE,
            "BLINKUP_PIN" : hardware.pinM,
            "GREEN_BTN" : hardware.pinC,
            "FOOTSWITCH" : hardware.pinH,
            "LCD_DISPLAY_UART" : hardware.uart2,
            "USB_PWR_EN" : hardware.pinR,
            "USB_FAULT_L" : hardware.pinW,
            "RS232_UART" : hardware.uart0,
            "FTDI_UART" : hardware.uart1,
        }

        // Initialize front panel LEDs to Off
        FactoryFixture_005.LED_RED.configure(DIGITAL_OUT, 0);
        FactoryFixture_005.LED_GREEN.configure(DIGITAL_OUT, 0);

        // Intiate factory BlinkUp on either a front-panel button press or footswitch press
        configureBlinkUpTrigger(FactoryFixture_005.GREEN_BTN);
        configureBlinkUpTrigger(FactoryFixture_005.FOOTSWITCH);

        lcd = CFAx33KL(FactoryFixture_005.LCD_DISPLAY_UART);
        setDefaultDisply();
        configurePrinter();

        // Open agent listener
        agent.on("data.to.print", printLabel.bindenv(this));
    }

    function configureBlinkUpTrigger(pin) {
        // Register a state-change callback for BlinkUp Trigger Pins
        pin.configure(DIGITAL_IN, function() {
            // Trigger only on rising edges, when BlinkUp is not already running
            if (pin.read() && !sendingBlinkUp) {
                sendingBlinkUp = true;
                imp.wakeup(BLINKUP_TIME, function() {
                    sendingBlinkUp = false;
                }.bindenv(this));

                // Send factory BlinkUp
                server.factoryblinkup(_ssid, _password, FactoryFixture_005.BLINKUP_PIN, BLINKUP_FAST | BLINKUP_ACTIVEHIGH);
            }
        }.bindenv(this));
    }

    function setDefaultDisply() {
        lcd.clearAll();
        lcd.setLine1("Electric Imp");
        lcd.setLine2(FIXTURE_BANNER);
        lcd.setBrightness(100);
        lcd.storeCurrentStateAsBootState();
    }

    function configurePrinter() {
        FactoryFixture_005.RS232_UART.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS, function() {
            server.log(uart.readstring());
        });

        printer = QL720NW(FactoryFixture_005.RS232_UART)
            .setOrientation(QL720NW.PORTRAIT)
            .setFont(QL720NW.FONT_HELSINKI)
            .setFontSize(QL720NW.FONT_SIZE_48);
    }

    function printLabel(data) {
        if (printer == null) configurePrinter();

        printer.setOrientation(QL720NW.PORTRAIT)
            .setFont(QL720NW.FONT_HELSINKI)
            .setFontSize(QL720NW.FONT_SIZE_48);

        if ("mac" in data) {
            // Log mac address
            server.log(data.mac);
            // Add 2D barcode of mac address to label
            printer.write2dBarcode(data.mac, {
                "cell_size": QL720NW.BARCODE_2D_CELL_SIZE_5,
                "symbol_type": QL720NW.BARCODE_2D_SYMBOL_MODEL_2,
                "structured_append_partitioned": false,
                "error_correction": QL720NW.BARCODE_2D_ERROR_CORRECTION_STANDARD,
                "data_input_method": QL720NW.BARCODE_2D_DATA_INPUT_AUTO
            });
            // Add mac address to label
            printer.write(data.mac);
            // Print label
            printer.print();
            // Log status
            server.log("Printed: "+data.mac);
        }
    }
}//line 1 "RunDeviceUnderTest.device.nut"
RunDeviceUnderTest = class {
        static LED_FEEDBACK_AFTER_TEST = 1;
        static PAUSE_BTWN_TESTS = 0.5;

        test = null;

        constructor() {
            test = AcceleratorTestingFactory.RunDeviceUnderTest.AutodeskDiscKitTesting(LED_FEEDBACK_AFTER_TEST, PAUSE_BTWN_TESTS, testsDone.bindenv(this));
            test.run();
        }

        function testsDone(passed) {
            // Only print label for passing hardware
            if (passed) {
                local deviceData = {};
                deviceData.mac <- imp.getmacaddress();
                deviceData.id <- hardware.getdeviceid();
                server.log("Sending Label Data: " + deviceData.mac);
                agent.send("set.label.data", deviceData);
            }

            // Clear wifi credentials on power cycle
            imp.clearconfiguration();
        }

//line 1 "AcceleratorTestSuite.device.nut"
AcceleratorTestSuite = class {

    // NOTE: LED test are not included in this class
    
    // Requires an echo server (RasPi)
    // Test opens a connection and receiver
    // Sends the test string
    // Checks resp for test string
    // Closes the connection
    function wiznetEchoTest(wiz) {
        server.log("Wiznet test.");
        local wiznetTestStr = "SOMETHING";

        return Promise(function(resolve, reject) {
            wiz.onReady(function() {
                // Connection settings
                local destIP   = "192.168.201.3";
                local destPort = 4242;
                local sourceIP = "192.168.201.2";
                local subnet_mask = "255.255.255.0";
                local gatewayIP = "192.168.201.1";
                wiz.configureNetworkSettings(sourceIP, subnet_mask, gatewayIP);

                server.log("Attemping to connect via LAN...");
                // Start Timer
                local started = hardware.millis();
                wiz.openConnection(destIP, destPort, function(err, connection) {
                    // 
                    local dur = hardware.millis() - started;

                    if (err) {
                        local errMsg = format("Connection failed to %s:%d in %d ms: %s", destIP, destPort, dur, err.tostring());
                        if (connection) {
                            connection.close(function() {
                                return reject(errMsg);
                            });
                        } else {
                            return reject(errMsg);
                        }
                    } else {
                        // Create event handlers for this connection
                        connection.onReceive(function(err, resp) {
                            connection.close(function() {
                                server.log("Connection closed. Ok to disconnect cable.")
                            });
                            local respStr = "";
                            resp.seek(0, 'b');
                            respStr = resp.readstring(9);

                            local index = respStr.find(wiznetTestStr); 
                            return (index != null) ? resolve("Received expected response") : reject("Expected response not found");
                        }.bindenv(this));
                        connection.transmit(wiznetTestStr, function(err) {
                            if (err) {
                                return reject("Send failed: " + err);
                            } else {
                                server.log("Send successful");
                            }
                        }.bindenv(this))
                    }
                }.bindenv(this))
            }.bindenv(this));   
        }.bindenv(this))
    }

    // Requires a PLC Click 
    // Reads a register
    // Writes that register with new value
    // Reads that register and checks for new value
    function RS485ModbusTest(modbus, devAddr) {
        server.log("RS485 test.");
        return Promise(function(resolve, reject) {
            local registerAddr = 4;
            local expected = null;
            modbus.read(devAddr, MODBUSRTU_TARGET_TYPE.HOLDING_REGISTER, registerAddr, 1, function(err, res) {
                if (err) return reject("Modbus read error: " + err);
                expected = (typeof res == "array") ? res[0] : res;
                // adjust the value
                (expected > 100) ? expected -- : expected ++;
                modbus.write(devAddr, MODBUSRTU_TARGET_TYPE.HOLDING_REGISTER, registerAddr, 1, expected, function(e, r) {
                    if (e) return reject("Modbus write error: " + e);
                    modbus.read(devAddr, MODBUSRTU_TARGET_TYPE.HOLDING_REGISTER, registerAddr, 1, function(error, resp) {
                        if (error) return reject("Modbus read error: " + error);
                        if (typeof resp == "array") resp = resp[0];
                        return (resp == expected) ? resolve("RS485 test passed.") : reject("RS485 test failed.");
                    }.bindenv(this))
                }.bindenv(this))
            }.bindenv(this))
        }.bindenv(this))
    }

    // Requires special cable to loop pin 1 on both groves together and pin 2 on both groves together
    function analogGroveTest(in1, in2, out1, out2) {
        server.log("Analog Grove Connectors test.");
        return Promise(function(resolve, reject) {
            local ones = 1;
            local twos = 0;
            out1.write(ones);
            out2.write(twos);
            return (in1.read() == ones && in2.read() == twos) ? resolve("Analog grove test passed.") : reject("Analog grove test failed.");
        }.bindenv(this))
    }

    function ADCTest(adc, chan, expected, range) {
        server.log("ADC test.");
        return Promise(function(resolve, reject) {
            local lower = expected - range;
            local upper = expected + range;
            local reading = adc.readADC(chan);
            return (reading > lower && reading < upper) ? resolve("ADC readings on chan " + chan + " in range.") : reject("ADC readings not in range. Chan : " + chan + " Reading: " + reading);
        }.bindenv(this))
    }

    function scanI2CTest(i2c, addr) {
        // note scan doesn't currently work on an imp005
        server.log("i2c bus scan.");
        local count = 0;
        return Promise(function(resolve, reject) {  
            for (local i = 2 ; i < 256 ; i+=2) {
                local val = i2c.read(i, "", 1);
                if (val != null) {
                    count ++;
                    server.log(val);
                    server.log(format("Device at address: 0x%02X", i));
                    if (i == addr) {
                        if (count == 1) {
                            return resolve(format("Found I2C sensor at address: 0x%02X", i));
                        } else {
                            return resolve(format("Found I2C sensor at address: 0x%02X and %i sensors", i, count));
                        }
                    }
                }
            }
            return reject(format("I2C scan did not find sensor at address: 0x%02X", addr));
        }.bindenv(this));
    }

    function ic2test(i2c, addr, reg, expected) {
        server.log("i2c read register test.");
        return Promise(function(resolve, reject) {
            local result = i2c.read(addr, reg.tochar(), 1);
            if (result == null) reject("i2c read error: " + i2c.readerror());
            return (result == expected.tochar()) ? resolve("I2C read returned expected value.") : reject("I2C read returned " + result);
        }.bindenv(this))
    }

    // Requires a USB FTDI device
    // Initializes USB host and FTDI driver
    // Looks for an onConnected FTDI device
    function usbFTDITest() {
        server.log("USB test.");
        return Promise(function(resolve, reject) {
            // Setup usb
            local usbHost = USB.Host(hardware.usb);
            usbHost.registerDriver(FtdiUsbDriver, FtdiUsbDriver.getIdentifiers());
            local timeout = imp.wakeup(5, function() {
                return reject("FTDI USB Driver not found. USB test failed.");
            }.bindenv(this))
            usbHost.on("connected", function(device) {
                imp.cancelwakeup(timeout);
                if (typeof device == "FtdiUsbDriver") {
                    return resolve("FTDI USB Driver found. USB test passed.");
                } else {
                    return reject("FTDI USB Driver not found. USB test failed.");
                }
            }.bindenv(this));
        }.bindenv(this))
    }

}//line 1 "AutodeskDiscKitTesting.device.nut"
AutodeskDiscKitTesting = class {

    // NOTE: LED tests are included in this class not the tests class

    static LED_ON = 0;
    static LED_OFF = 1;

    feedbackTimer = null;
    pauseTimer = null;
    done = null;

    accelerator = null;
    tests = null;       
    wiz = null;
    modbus = null;
    adc = null;

    passLED = null;
    failLED = null;
    testsCompleteLED = null;

    failedCount = 0;

    constructor(_feedbackTimer, _pauseTimer, _done) {
        feedbackTimer = _feedbackTimer;
        pauseTimer = _pauseTimer;
        done = _done;

        // assign HAL here 
        accelerator = { "LED_RED" : hardware.pinE,
                        "LED_GREEN" : hardware.pinF,
                        "LED_YELLOW" : hardware.pinG,

                        "GROVE_I2C" : hardware.i2c0,
                        "GROVE_1_D1" : hardware.pinS,
                        "GROVE_1_D2" : hardware.pinM,
                        "GROVE_2_D1" : hardware.pinJ,
                        "GROVE_2_D2" : hardware.pinK,

                        "ADC_SPI" : hardware.spiBCAD,
                        "ADC_CS" : hardware.pinD,

                        "RS485_UART" : hardware.uart1,
                        "RS485_nRE" : hardware.pinL,

                        "WIZNET_SPI" : hardware.spi0,
                        "WIZNET_RESET" : hardware.pinQ,
                        "WIZNET_INT" : hardware.pinH,

                        "USB_EN" : hardware.pinR,
                        "USB_LOAD_FLAG" : hardware.pinW }

        // Configure Hardware
        configureLEDs();
        configureGrove();
        configureWiznet();
        configureModbusRS485();
        configureADC();

        // Initialize Test Class
        tests = AcceleratorTestingFactory.RunDeviceUnderTest.AcceleratorTestSuite();
    }

    // This method runs all tests
    // When testing complete should call done with one param - allTestsPassed (bool)
    function run() {
        pause()
            .then(function(msg) {
                server.log(msg);
                return ledTest();
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))
            .then(function(msg) {
                server.log(msg);
                return tests.wiznetEchoTest(wiz);
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))
            .then(function(msg) {
                server.log(msg);
                return tests.usbFTDITest();
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))
            .then(function(msg) {   
                server.log(msg);
                local deviceAddr = 0x01;
                return tests.RS485ModbusTest(modbus, deviceAddr);
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))       
            .then(function(msg) {   
                server.log(msg);
                local chan = 6;
                local expected = 0;
                local range = 0.2;
                return tests.ADCTest(adc, chan, expected, range);
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))   
            .then(function(msg) {   
                server.log(msg);
                local chan = 7;
                local expected = 2.5; // expecting 2.5
                local range = 0.2;
                return tests.ADCTest(adc, chan, expected, range);
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))                               
            .then(function(msg) {
                server.log(msg);
                local tempHumidI2CAddr = 0xBE;
                local whoamiReg = 0x0F;
                local whoamiVal = 0xBC;
                return tests.ic2test(accelerator.GROVE_I2C, tempHumidI2CAddr, whoamiReg, whoamiVal);
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))
            .then(function(msg) {
                server.log(msg);
                return tests.analogGroveTest(accelerator.GROVE_1_D1, accelerator.GROVE_1_D2, accelerator.GROVE_2_D1, accelerator.GROVE_2_D2);
            }.bindenv(this))
            .then(passed.bindenv(this), failed.bindenv(this))
            .then(function(msg) {
                local passing = (failedCount == 0);
                (passing) ? passLED.write(LED_ON) : failLED.write(LED_ON);
                testsCompleteLED.write(LED_ON);
                done(passing); 
            }.bindenv(this))
    }

    // HARDWARE CONFIGURATION HELPERS
    // -----------------------------------------------------------------------------
    function configureLEDs() {
        accelerator.LED_RED.configure(DIGITAL_OUT, LED_OFF);
        accelerator.LED_GREEN.configure(DIGITAL_OUT, LED_OFF);
        accelerator.LED_YELLOW.configure(DIGITAL_OUT, LED_OFF);

        passLED = accelerator.LED_GREEN;
        failLED = accelerator.LED_RED;
        testsCompleteLED = accelerator.LED_YELLOW;
    }

    function configureGrove() {
        accelerator.GROVE_I2C.configure(CLOCK_SPEED_400_KHZ);
        // Grove 1 pins configure as output
        accelerator.GROVE_1_D1.configure(DIGITAL_IN);
        accelerator.GROVE_1_D2.configure(DIGITAL_IN);
        // Grove 2 pins configure as input
        accelerator.GROVE_2_D1.configure(DIGITAL_OUT, 0);
        accelerator.GROVE_2_D2.configure(DIGITAL_OUT, 0);
    }

    function configureADC() {
        local speed = 100;
        local vref = 3.3;
        accelerator.ADC_SPI.configure(CLOCK_IDLE_LOW, speed);
        adc = MCP3208(accelerator.ADC_SPI, vref, accelerator.ADC_CS);
    }

    function configureWiznet() {
        local speed = 1000;
        local spi = accelerator.WIZNET_SPI;
        spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, speed);
        wiz = W5500(accelerator.WIZNET_INT, spi, null, accelerator.WIZNET_RESET);
    }

    function configureModbusRS485() {
        local opts = {};
        opts.baudRate <- 38400;
        opts.parity <- PARITY_ODD;
        modbus = Modbus485Master(accelerator.RS485_UART, accelerator.RS485_nRE, opts);
    }

    // TESTING HELPERS
    // -----------------------------------------------------------------------------

    // Used to space out tests
    function pause(double = false) {
        local pauseTime = (double) ? pauseTimer * 2 : pauseTimer;
        return Promise(function(resolve, reject) {
            imp.wakeup(pauseTime, function() {
                return resolve("Start...");
            });
        }.bindenv(this))
    }

    function passed(msg) {
        server.log(msg);
        return Promise(function (resolve, reject) {
            passLED.write(LED_ON);
            imp.wakeup(feedbackTimer, function() {
                passLED.write(LED_OFF);
                imp.wakeup(pauseTimer, function() {
                    return resolve("Start...");
                });
            }.bindenv(this));
        }.bindenv(this))
    }

    function failed(errMsg) {
        server.error(errMsg);   
        return Promise(function (resolve, reject) {
            failLED.write(LED_ON);
            failedCount ++;
            imp.wakeup(feedbackTimer, function() {
                failLED.write(LED_OFF);
                imp.wakeup(pauseTimer, function() {
                    return resolve("Start...");
                });
            }.bindenv(this));
        }.bindenv(this))
    }

    function ledTest() {
        server.log("Testing LEDs.");
        // turn LEDs on one at a time
        // then pass a passing test result  
        return Promise(function (resolve, reject) {
            failLED.write(LED_ON);
            imp.wakeup(feedbackTimer, function() {
                failLED.write(LED_OFF);
                imp.wakeup(pauseTimer, function() {
                    testsCompleteLED.write(LED_ON);
                    imp.wakeup(feedbackTimer, function() {
                        testsCompleteLED.write(LED_OFF);
                        imp.wakeup(pauseTimer, function() {
                            passLED.write(LED_ON);
                            imp.wakeup(feedbackTimer, function() {
                                passLED.write(LED_OFF);
                                return resolve("LEDs Testing Done.");
                            }.bindenv(this))
                        }.bindenv(this))
                    }.bindenv(this))
                }.bindenv(this))
            }.bindenv(this))
        }.bindenv(this))
    }
}//line 28 "RunDeviceUnderTest.device.nut"
}//line 35 "device.nut"
}

// // Factory Code
// // ------------------------------------------
server.log("Device Running...");

const SSID = "";
const PASSWORD = "";

AcceleratorTestingFactory(SSID, PASSWORD);
