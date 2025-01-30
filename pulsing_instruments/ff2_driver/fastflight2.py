from usb_interface import usbInterface
from FF2_parms import *
import usb.core
import math
from enum import IntEnum
import errno
from warnings import warn

def memcmp(a, b):
    return bytes(a) == bytes(b)

class FastFlight2(usbInterface):
    def __init__(self):
        super().__init__(FF2_VID, FF2_PID)
        self.db = self.dataBuffer()
        self.settings = self.Protocol()

    def __sendFile(self, fname):
        pass

    def __sendFirmware(self):
        pass

    def __setupFile(self, chip):
        pass
    
    def __init(self):
        self.dev.clear_halt(CONTROL_OUT)
        self.dev.clear_halt(CONTROL_IN)
        # IMPLEMENT ME
        pass

    def __strangeDance(self):
        for i, move in enumerate(STRANGE_DANCE):
            if move > 0:
                self.setParameter(0x10, move)
            else:
                p = self.getParameter(0x10)
                if (p != -move): warn("Dance mismatch on byte 0x%x; expected 0x%02x, got 0x%02x\n",i,-move,p)
        self.setParameter(0x18, 0x06)
        self.setParameter(0x19, 0x00)
        self.setParameter(0x1a, 0x07)
        self.setParameter(0x18, 0x24)
        self.setParameter(0x19, 0x7d)
        self.setParameter(0x1a, 0x00)
        self.setParameter(0x18, 0x2c)
        self.setParameter(0x19, 0x74)
        self.setParameter(0x1a, 0x00)
        self.setParameter(0x18, 0x9f)
        self.setParameter(0x19, 0x9f)
        self.setParameter(0x1a, 0x01)

    class Protocol:
        def __init__(self):
            self.b1 = [0] * 0x0d                    # Bitfields for transmission
            self.b2 = [0] * 0x12

            self.recordLength = 1e7                 # Nanoseconds
            self.voltageOffset = 0.0                # Volts
            self.timeOffset = 16.0                  # Nanoseconds
            self.recordsPerSpectrum = 256           # Traces

            self.precisionEnhancer = True           # flag

            self.tpp = self.TPP.INT_500ps

            self.compression = self.Compression.LOSSLESS
            self.ringingProtection = 2
            self.sensitivity = self.Sensitivity.SENS_2x
            self.minimumThreshold = 10
            self.backgroundInterval = 200
            self.adjacentBackground = 0x10
            self.correlatedSubtraction = False
            self.minimumPeak = 4
            self.maximumPeak = 400

            self.singleIonLength = 100              # Nanoseconds
            self.singleIonStart = 100               # Nanoseconds

        class TPP(IntEnum):
            INT_250ps = 0x10
            INT_500ps = 0x20
            INT_1ns = 0x40
            INT_2ns = 0x80

        class Compression(IntEnum):
            PEAK_ONLY = 0x0
            LOSSLESS = 0x1
            STICK = 0x2

        class Sensitivity(IntEnum):
            SENS_2x = 0x0
            SENS_3x = 0x01
            SENS_4x = 0x02

        def time_per_point(self):
            if self.tpp == self.TPP.INT_250ps:
                return 0.25
            elif self.tpp == self.TPP.INT_500ps:
                return 0.5
            elif self.tpp == self.TPP.INT_1ns:
                return 1.0
            elif self.tpp == self.TPP.INT_2ns:
                return 2.0
            else:
                raise ValueError(f"Undefined TPP 0x{self.tpp:02x}")

        def set_time_per_point(self, tpp):
            if tpp <= 0.251:
                self.tpp = self.TPP.INT_250ps
            elif tpp < 0.51:
                self.tpp = self.TPP.INT_500ps
            elif tpp < 1.01:
                self.tpp = self.TPP.INT_1ns
            else:
                self.tpp = self.TPP.INT_2ns

        def stuff(self):
            self.b1 = bytearray(0x0d)  # 13 bytes
            self.b2 = bytearray(0x12)  # 18 bytes

            points = int(round(self.recordLength / self.time_per_point()))
            points = max(16, min(1500000, points))
            self.recordLength = points * self.time_per_point()

            # Stuff b1
            divider = int(0x10 * 0.5 / self.time_per_point())
            self.b1[0] = (points // divider) & 0xff
            self.b1[1] = (points // (divider * 0x100)) & 0xff

            toi = int(self.timeOffset / 16.0)
            toi = max(1, min(0xffff, toi))
            self.timeOffset = toi * 16

            self.b1[3] = toi & 0xff
            self.b1[4] = (toi // 0x100) & 0xff
            self.b1[5] = self.recordsPerSpectrum & 0xff
            self.b1[6] = (self.recordsPerSpectrum // 0x100) & 0xff

            # This formula is a guess
            i = int(round(((self.voltageOffset + 0.25) / 0.5) * 65535))
            i = max(0, min(0xffff, i))
            self.b1[8] = i & 0x00ff
            self.b1[9] = (i & 0xff00) // 0x100
            self.voltageOffset = 0.5 * (i / 65535.0) - 0.25

            if self.tpp == self.TPP.INT_250ps:
                self.b1[0xb] = 0
            elif self.tpp == self.TPP.INT_500ps:
                self.b1[0xb] = 0x01
            elif self.tpp == self.TPP.INT_1ns:
                self.b1[0xb] = 0x02
            elif self.tpp == self.TPP.INT_2ns:
                self.b1[0xb] = 0x03

            self.b1[0xc] = 1 if self.precisionEnhancer else 0

            # Stuff b2
            self.b2[0] = self.compression | self.tpp
            self.b2[1] = self.ringingProtection * 0x10 | self.sensitivity
            self.b2[2] = 0x0a
            self.b2[3] = 0x00
            self.b2[4] = 0x30
            self.b2[5] = (self.backgroundInterval // 4) & 0xff
            self.b2[6] = (self.adjacentBackground & 0x7f) | (0x80 if self.correlatedSubtraction else 0)

            points = (points // 8) * 8 - 2

            self.b2[7] = 0x64
            self.b2[8] = 0x04
            self.b2[9] = points & 0xff
            self.b2[0xa] = (points // 0x100) & 0xff
            self.b2[0xb] = (points // 0x10000) & 0x1f

            self.b2[0x0c] = 0x00
            self.b2[0x0d] = 0x00
            self.b2[0x0e] = 0x00
            self.b2[0x0f] = 0x00
            self.b2[0x10] = self.recordsPerSpectrum & 0xff
            self.b2[0x11] = (self.recordsPerSpectrum // 0x100) & 0xff

        def __eq__(self, other):
            if not isinstance(other, self):
                return NotImplemented
            self.stuff()
            other.stuff()
            if memcmp(self.b1, other.b1) != 0:
                return False
            if memcmp(self.b2, other.b2) != 0:
                return False
            return True

    class codeType_t(IntEnum):
        DATA_16BIT = 0x00
        DATA_24BIT = 0x01
        DATA_STICK = 0x02
        SPECTRUM_BEGIN = 0x03
        SPECTRUM_END = 0x03
        TIME_LOW = 0x04
        TIME_HIGH = 0x05
        PROTOCOL = 0x06
        ION_COUNT = 0x07
        SYNC = 0x07
        NOT_CODE = 0xFF

    class dataBuffer:
        def __init__(self):
            self.data = bytearray(MAX_BULK_SIZE)
            self.index = 0
            self.last_taken = 0
            self.bytecount = 0
            self.unget = -1

        def reset(self):
            self.bytecount = 0

    def getLastProtocol(self):
        return self.__lastProtocol

    def loadBackgroundCal(self):
        pass

    def applyCalibration(self):
        pass

    def setRapidProtocolSelection(self, state):
        c = self.getMemory(MISC_CNTRL_PTR)
        if state:
            nc = c | RAPID_PROTOCOL_MASK
        else:
            nc = c & ~RAPID_PROTOCOL_MASK
        if nc != c: self.setMemory(MISC_CNTRL_PTR, nc)

    def getRapidProtocolSelection(self):
        return self.getMemory(MISC_CNTRL_PTR) & RAPID_PROTOCOL_MASK

    def setParameter(self, param, val):
        cmd = bytes([SET_CMD, param, val])
        try:
            self.Write(CONTROL_OUT, cmd)
            response = self.Read(CONTROL_IN, 1)

            if response[0] not in [0,1]:
                print(f"Never-before-seen response code 0x{response[0]:02x} setting parameter 0x{param:02x} to 0x{val:02x}")
            
            return response[0] == 1
        except usb.core.USBError as e:
            print(f"USB Error: {str(e)}")
            return False
        
    def getParameter(self, param):
        cmd = bytes([GET_CMD, param])
        try:
            self.Write(CONTROL_OUT, cmd)
            response = self.Read(CONTROL_IN, 1)
            return response[0]
        except usb.core.USBError as e:
            print(f"USB Error: {str(e)}")
            return None

    def setMemory(self, address, val):
        try:
            resp = self.Control(usb.util.CTRL_TYPE_VENDOR | 
                               usb.util.CTRL_RECIPIENT_DEVICE |
                               usb.util.CTRL_IN, MEMORY_SET_REQUEST,
                               address, 0, bytes([val]))
            return resp == 1
        except usb.core.USBError as e:
            print(f"USB Error: {str(e)}")
            return False

    def getMemory(self):
        # gets the value at miscellaneous control pointer
        try:
            buf = self.Control(usb.util.CTRL_TYPE_VENDOR | 
                               usb.util.CTRL_RECIPIENT_DEVICE |
                               usb.util.CTRL_IN, MEMORY_SET_REQUEST,
                               MISC_CNTRL_PTR, 0, 1)
            return buf[0] if buf else None
        except usb.core.USBError as e:
            print(f"USB Error: {str(e)}")
            return None

    def isInitialized(self):
        pass

    def sendProtocol(self):
        pass

    def setProtocol(self):
        pass

    def getExternalTrigger(self):
        return self.getMemory() & EXT_TRIGGER_MASK

    def setExternalTrigger(self, state):
        c = self.getMemory()
        if state:
            nc = c | EXT_TRIGGER_MASK
        else:
            nc = c & ~EXT_TRIGGER_MASK
        if nc != c: self.setMemory(MISC_CNTRL_PTR, nc)

    def setTriggerEnableHigh(self, high):
        c = self.getParameter(TRIGGER_PARAMETER)
        if high:
            c |= TRIGGER_POLARITY_MASK
        else:
            c &= ~TRIGGER_POLARITY_MASK
        self.setParameter(TRIGGER_PARAMETER, c)

    def getTriggerEnableHigh(self):
        return (self.getParameter(TRIGGER_PARAMETER) & TRIGGER_POLARITY_MASK) != 0

    def setTriggerRising(self, high):
        c = self.getParameter(TRIGGER_PARAMETER)
        if high:
            c |= TRIGGER_RISING_MASK
        else:
            c &= ~TRIGGER_RISING_MASK
        self.setParameter(TRIGGER_PARAMETER, c)

    def isTriggerRising(self):
        return (self.getParameter(TRIGGER_PARAMETER) & TRIGGER_RISING_MASK) != 0

    def setTrigger50ohm(self, state):
        if state: return
        warn("FastFlight 2 only supports 50 ohm trigger\n")

    def isTrigger50ohm(self):
        return True

    def getTriggerThreshold(self):
        return self.__triggerThreshold

    def setTimePerPoint(self, tpp):
        self.settings.set_time_per_point(tpp)

    def getTimePerPoint(self):
        return self.settings.time_per_point()

    def setSensitivity(self, sens):
        if sens == 0.5: return
        warn("FastFlight 2 has fixed sensitivity of 0.5\n")

    def getSensitivity(self):
        return 0.5

    def setTraceLength(self, tl):
        self.settings.recordLength = tl
        self.settings.stuff()
        self.__rps = self.getLength()

    def getTraceLength(self):
        return self.settings.recordLength

    def setLength(self, l):
        self.settings.recordLength = 1 * self.getTimePerPoint()
        self.settings.stuff()
        self.__rps = self.getLength()

    def getLength(self):
        return self.settings.recordLength//self.getTimePerPoint()

    def setOffset(self, v):
        self.settings.voltageOffset = v
        self.settings.stuff()

    def getOffset(self):
        return self.settings.voltageOffset

    def getScale(self):
        scale = 0.5/(256. * self.__rps)
        offset = self.settings.voltageOffset
        tscale = self.settings.time_per_point() * 1e-9
        return scale, offset, tscale

    def setTriggerThreshold(self, v):
        self.__triggerThreshold = v
        v = ((2.5-v)/5.)*1024
        i = math.ceil(v)
        self.setParameter(0x14, (i & 0x3)*0x40)
        self.setParameter(0x15, i//0x04)

    def resetTimer(self):
        m = self.getMemory(MISC_CNTRL_PTR)
        m = m | TIMER_RESET_MASK
        self.setMemory(MISC_CNTRL_PTR, m)
        m = m & ~TIMER_RESET_MASK
        self.setMemory(MISC_CNTRL_PTR, m)

    def clearBuffer(self):
        cmd2 = 0x12
        self.setParameter(0x07, 0x20)
        self.Write(CONTROL_OUT, [cmd2])
        res = self.Read(CONTROL_IN, 1)
        assert res[0] == 1, "Expected 1, got {}".format(res[0])
        self.setParameter(0x07, 0x00)
        self.db.index = self.db.bytecount = self.db.last_taken = 0
        self.db.unget = -1

    def startAquisition(self):
        self.clearBuffer()
        self.setParameter(0x05, 0xd0)

        self.setMemory(0xa1fc, 0x00)
        self.setMemory(0xa1fc, 0x00)
        self.setMemory(0xa1fc, 0x10)
        self.setMemory(0xa1fc, 0x10)
        self.setMemory(0xa1fc, 0x00)
        self.setMemory(0xa1fc, 0x00)
        self.setMemory(0xa1fc, 0x50)
        self.setMemory(0xa1fb, 0x08)
        self.setMemory(0xa1fb, 0x18)
        self.setMemory(0xa1fe, 0x00)

        e = self.getMemory()
        self.setMemory(MISC_CNTRL_PTR, e | UNKNOWN_START)
        self.setMemory(MISC_CNTRL_PTR, e & ~UNKNOWN_START)
        self.setMemory(MISC_CNTRL_PTR, e | RUN_MASK)

    def stopAquisition(self):
        e = self.getMemory()
        self.setMemory(MISC_CNTRL_PTR, e & ~RUN_MASK)

    def takeSweep(self):
        pass

    def takeSweepDither(self):
        pass


    def getSpectrum(self):
        pass

    def getCodeType(self, word):
        if (word & 0xff000000) != 0xff000000:
            return self.codeType_t.NOT_CODE
        word = (word & 0x00e00000) // 0x00200000
        if word >= self.codeType_t.DATA_16BIT and word <= self.codeType_t.SYNC:
            return self.codeType_t(word)
        raise ValueError(f"Unknown code type 0x{word:x}")

    def getData(self, buffer_size):
        cmd = bytes([0xff, 0x03])

        off = 0
        for _ in range(3):
            try:
                ret = self.Write(SPECTRA_OUT, cmd[off:], 50)
                if ret == len(cmd) - off: break
                if ret == 0: break
                print(f"Incomplete command write ({ret}/{len(cmd)}), continuing")
                off+=ret
            except usb.core.USBTimeoutError:
                break
            except usb.core.USBError as e:
                print(f"Error from Write: {e}")
                break
        
        buffer = bytearray(buffer_size)
        for retry in range(2):
            if retry != 0: print(f"Retry {retry} on read")
            try:
                r = self.Read(SPECTRA_IN, buffer, 1000)
                break
            except usb.core.USBTimeoutError:
                continue
            except usb.core.USBError as e:
                print(f"Error from bulkRead: {e}")
                r = -1
                break
        else:
            r = -errno.ETIMEDOUT

        return bytes(buffer[:r]) if r > 0 else None

    def get(self, target):
        if self.db.unget != -1:
            ret = self.db.unget
            self.db.unget = -1
            self.db.bytecount+=1
            return ret
        if self.db.index < self.db.last_taken:
            self.db.bytecount+=1
            ret = self.db.data[self.db.index]
            self.db.index+=1
            return ret
        self.db.index = 0
        self.db.last_taken = 0
        if target < 0 or (target - self.db.bytecount > MAX_BULK_SIZE):
            to_take = MAX_BULK_SIZE
        else:
            assert(self.db.bytecount < target)
            to_take = target - self.db.bytecount

        while True:
            data = self.getData(to_take)
            r = len(data)
            self.db.data[self.db.last_taken:self.db.last_taken + r] = data
            if r > 0:
                self.db.last_taken+=r
                self.db.bytecount+=1
                ret = self.db.data[self.db.index]
                self.db.index+=1
                return ret

    def unget(self, c):
        self.db.unget = c
        self.db.bytecount-=1

    def synchronize(self): # look for spectrum sync marker
        cTarget = 8
        c = 0
        while True:
            if self.get() == 0xff:
                c+=1
                if c == cTarget:
                    c = self.get() # we may have been mislead by the final 0xff from an old command
                    if c != 0xff:
                        self.unget(c)
                    return
            else:
                c = 0