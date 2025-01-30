import os
import usb.core
import usb.util
import usb.backend.libusb1

# Set up the backend that points to libusb-1.0
dllPath = os.path.join(os.path.dirname(__file__), "libusb-1.0.dll")
bknd = usb.backend.libusb1.get_backend(find_library = lambda x: dllPath)

def devToStr(dev):
    vendorID = dev.idVendor
    productID = dev.idProduct
    try:
        vendor = usb.util.get_string(dev, dev.iManufacturer)
        product = usb.util.get_string(dev, dev.iProduct)
        serial = usb.util.get_string(dev, dev.iSerialNumber)
    except:
        vendor, product, serial = "unknown", "unknown", "unknown"
    
    s = f"Device: {vendor} {product}\n"
    s+= f"       Vendor ID: 0x{vendorID:04x}\n"
    s+= f"      Product ID: 0x{productID:04x}\n"
    s+= f"   Serial Number: {serial}\n"
    return s

def listDevices():
    devices = usb.core.find(find_all = True)
    for dev in devices:
        print(devToStr(dev), end="")

def locateDevice(*args, **kwargs):
    dev = usb.core.find(*args, backend=bknd, **kwargs)
    if dev is None: raise ValueError("Device Not Found.")
    dev.set_configuration()
    usb.util.claim_interface(dev, 0)
    return dev