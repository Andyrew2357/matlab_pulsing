from lusb import *
import usb.util

class usbInterface:

    def __init__(self, vendorID, productID, defaultBufferLen=1024, defaultTimeout=None):
        self.vendorID = vendorID
        self.productID = productID
        self.defaultBufferLen = defaultBufferLen
        self.defaultTimeout = defaultTimeout
        
        self.dev = locateDevice(idVendor=vendorID, idProduct=productID)

    def __str__(self):
        return devToStr(self.dev)
    
    def __repr__(self):
        return f"<usbInterface-VID0x{self.vendorID:04x}-PID0x{self.productID:04x}>"

    def getManufacturerName(self): return usb.util.get_string(self.dev, self.dev.iManufacturer)
    def getProductName(self): return usb.util.get_string(self.dev, self.dev.iProduct)
    def getSerialNumber(self): return usb.util.get_string(self.dev, self.dev.iSerialNumber)

    def Write(self, endpoint, data, timeout=None):
        if timeout is None: timeout = self.defaultTimeout
        return self.dev.write(endpoint, data, timeout)

    def Read(self, endpoint, bufferLen=None, timeout=None):
        if timeout is None: timeout = self.defaultTimeout
        if bufferLen is None: bufferLen = self.defaultBufferLen
        return self.dev.read(endpoint, bufferLen, timeout)

    def Control(self, requestType, request, val, index, data_or_len, timeout=None):
        if timeout is None: timeout = self.defaultTimeout
        return self.dev.ctrl_transfer(requestType, request, val, index, data_or_len, timeout)