import os
import usb.core
import usb.util
import usb.backend.libusb1
backend = usb.backend.libusb1.get_backend(find_library = lambda x: \
        os.path.join(os.path.dirname(__file__), "libusb-1.0.dll"))

devices = usb.core.find(find_all = True, backend=backend)

for device in devices:
    try:
        vendor = usb.util.get_string(device, device.iManufacturer)
        product = usb.util.get_string(device, device.iProduct)
        serial = usb.util.get_string(device, device.iSerialNumber)
    except:
        vendor = "unknown"
        product = "unknown"
        serial = "unknown"

    print(f"Device: {vendor} {product}")
    print(f"    Vendor ID: 0x{device.idVendor:04x}")
    print(f"    Product ID: 0x{device.idProduct:04x}")
    print(f"    Serial Number: {serial}")