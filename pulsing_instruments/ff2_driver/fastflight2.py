from usb_interface import usbInterface
from FF2_parms import *
import usb.core
import math
from enum import IntEnum
import errno
import os
from warnings import warn

def memcmp(a, b): return bytes(a) == bytes(b)
def firstByte(a): return (a & 0xff000000)>>24
def secondByte(a): return (a & 0x00ff0000)>>16
def thirdByte(a): return (a & 0x0000ff00)>>8
def fourthByte(a): return (a & 0x000000ff)

class FastFlight2(usbInterface):
    def __init__(self):
        super().__init__(FF2_VID, FF2_PID)
        self.lastfile = -1
        self.db = self.dataBuffer()
        self.settings = self.Protocol()
        self.maxProtocol = 16
        self.lastSent = [self.Protocol() for _ in range(self.maxProtocol)]

        self.__init()
        self.setTraceLength(TRAC_LEN)
        self.setOffset(OFFSET)
        self.setTriggerThreshold(TRIG_THRESH)
        self.setTimePerPoint(TPP)
        self.setExternalTrigger(True)
        self.setTriggerEnableHigh(False)
        self.setTriggerRising(True)
        self.setRapidProtocolSelection(True)

    def __sendFile(self, fname):
        batch = firstbatch = rest = 0x20
        hunk_count = 0

        buf = bytearray(rest)
        n = os.path.join(FPGA_DIR, fname)
        print(f"Sending file \"{n}\" to chip {self.lastfile:x}")

        try:
            with open(n, 'rb') as f:
                buf[0] = self.lastfile + 1
                s = f.read(firstbatch - 1)
                buf[1:len(s) + 1] = s
                print(f"Writing hunk 0x{hunk_count:06x}\r", end="")
                self.Write(CONTROL_OUT, buf[:len(s) + 1], 500)
                ret = self.Read(CONTROL_IN, 1)
                assert(ret[0] == 0)
                if len(s) != firstbatch - 1: return

                while True:
                    s = f.read(rest - 1)
                    if not s: break
                    if hunk_count % 0x10 == 0:
                        print(f"Writing hunk 0x{hunk_count:06x}\r", end="")
                        hunk_count+=1

                        buf[1:len(s)+1] = s
                        self.dev.write(self.control_out, buf[:len(s)+1])
                        ret = self.dev.read(self.control_in, 1)
                        assert ret[0] == 0
            
            print(f"Writing hunk.......... Done ({hunk_count} hunks)")
        
        except IOError as e:
            if e.errno == errno.ENOENT:
                raise IOError(f"Unable to open FPGA file \"{n}\": {os.strerror(e.errno)}")
            else:
                raise

    def __sendFirmware(self):
        buf = bytearray(8)
        right = bytearray([0x42, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
        self.Control(usb.util.CTRL_TYPE_VENDOR | 
                     usb.util.CTRL_RECIPIENT_DEVICE | 
                     usb.util.CTRL_IN,
                     0xa2, 0xfff0, 0, buf)
        if buf != right:
            print("Unexpected Response Sending Firmware\n")
            print("Expected: ")
            self.binaryDump(right)
            print("Got: ")
            self.binaryDump(buf)

        self.__setupFile(0x4)
        self.__sendFile("AcqControl.rbf")
        
        self.__setupFile(0x6)
        self.__sendFile("pipes.rbf")
        self.__sendFile("pipes.rbf")
        self.__sendFile("pipes.rbf")
        self.__sendFile("pipes4P2.rbf")

        self.__setupFile(0x8)
        self.__sendFile("compressionfpga.rbf")

        self.__setupFile(0xc)
        self.__sendFile("00_AnalogFPGA.rbf")
        self.__sendFile("TrigProcFPGA.rbf")

        self.__setupFile(0xa)
        self.__sendFile("fanout.bin")

        buf = bytearray([0xe, 0xdf])
        self.Write(CONTROL_OUT, buf)
        ret = self.Read(CONTROL_IN, 1)
        assert(ret == 0)
        buf[1] = bytes(0xd7)
        self.Write(CONTROL_OUT, buf)
        ret = self.Read(CONTROL_IN, 1)
        assert(ret == 0)
        buf[1] = bytes(0x95)
        self.Write(CONTROL_OUT, buf)
        ret = self.Read(CONTROL_IN, 1)
        assert(ret == 0)
        buf[1] = bytes(0x00)
        self.Write(CONTROL_OUT, buf)
        ret = self.Read(CONTROL_IN, 1)
        assert(ret == 0)

        self.__strangeDance()

    def __setupFile(self, chip):
        if chip == self.lastfile: return
        self.lastfile = chip
        buf = bytes([chip])
        self.Write(CONTROL_OUT, buf)
        resp = self.Read(CONTROL_IN, 1)
        assert resp[0] == 0
    
    def __init(self):
        self.dev.clear_halt(CONTROL_OUT)
        self.dev.clear_halt(CONTROL_IN)
        if not self.isInitialized():
            warn("Device is not yet initialized. Sending firmware.\n")
            self.__sendFirmware()
        self.stopAquisition()
        self.clearBuffer()
        self.resetTimer()

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
            self.sent = False

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

    def applyCalibration(self, data, length):
        if len(self.backgroundCal) == 0: return data
        if length > len(self.backgroundCal): raise IndexError("Too many samples acquired for current background calibration")

        scale, offset, tscale = self.getScale()
        print("Using background calibration")
        for i in range(length): data[i] -= self.backgroundCal[i] / scale
        return data

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
        return True # FOR DEBUGGING PURPOSES
        isInitCmd = bytes([0x0f])
        try:
            self.Write(CONTROL_OUT, isInitCmd)
            resp = self.Read(CONTROL_IN, 1)
            if resp[0] not in [0, 1]:
                raise ValueError(f"Never-before-seen response code 0x{resp[0]:02x} to 0x{isInitCmd[0]:02x}")
            return resp[0] == 1
        except usb.core.USBError as e:
            print(f"USB Error: {e}")
            return False
            
    def sendProtocol(self, p, slot):
        # p is a Protocol object
        assert(slot >= 0 and slot <= self.maxProtocol)
        if self.lastSent[slot].sent == True and self.lastSent[slot] == p: return
        p.stuff()
        self.lastSent[slot] = p
        self.lastSent[slot].sent = True
        self.Control(usb.util.CTRL_TYPE_VENDOR | 
                     usb.util.CTRL_RECIPIENT_DEVICE | 
                     usb.util.ENDPOINT_OUT, MEMORY_SET_REQUEST,
                     PROTOCOL_BASE + slot*PROTOCOL_STEP, 0, p.b1)
        self.Control(usb.util.CTRL_TYPE_VENDOR | 
                     usb.util.CTRL_RECIPIENT_DEVICE | 
                     usb.util.ENDPOINT_OUT, MEMORY_SET_REQUEST,
                     PROTOCOL_BASE + slot*PROTOCOL_STEP + 0xe, 0, p.b2)

    def setProtocol(self, slot):
        self.setMemory(PROTOCOL_SET_PTR, slot)

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
        cmd2 = bytes([0x12])
        self.setParameter(0x07, 0x20)
        self.Write(CONTROL_OUT, cmd2)
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

    def getWord(self, target=-1):
        i = self.get(target)
        i |= self.get(target) * 0x100
        i |= self.get(target) * 0x10000
        i |= self.get(target) * 0x1000000
        return i

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

    def getSpectrum(self, length):
        data = bytearray(length)
        index = t = spectrumNumber = _index = spectrumLength = lastCodeType = 0
        # goto resync
        def resync(): # return here if we get an unexpected synchronize or get confused
            nonlocal index, t, spectrumNumber, _index, spectrumLength, lastCodeType
            index = 0
            self.db.reset()
            t = self.getWord()
            if self.getCodeType(t) != self.codeType_t.SPECTRUM_BEGIN:
                print(f"Corrupt spectrum on spectrum length; got 0x{t:08x}, codetype 0x{self.getCodeType(t):x}")
                self.synchronize()
                resync()
            t&=CODE_DATA_MASK
            spectrumNumber = t
            _index = spectrumNumber

            t = self.getWord()
            if self.getCodeType(t) != self.codeType_t.SPECTRUM_BEGIN:
                print(f"Corrupt spectrum on spectrum length; got 0x{t:08x}, codetype 0x{self.getCodeType(t):x}")
                self.synchronize()
                resync()

            spectrumLength = t & CODE_DATA_MASK
            lastCodeType = self.codeType_t.SPECTRUM_BEGIN

        spectrumNumber = -1
        self.synchronize()
        resync()
        while True:
            t = self.getWord()
            codeType = self.getCodeType(t)
            match codeType:
                case self.codeType_t.DATA_16BIT | self.codeType_t.DATA_24BIT:
                    if index != (t & CODE_DATA_MASK):
                        print(f"Found jump to {t & CODE_DATA_MASK} from {index}, code 0x{t:x}, codetype 0x{codeType:x}")
                        index = t & CODE_DATA_MASK

                        if index > length:
                            print("Illegal jump; resyncing!")
                            self.synchronize(); resync(); continue # goto retry

                case self.codeType_t.NOT_CODE:
                    if index + 4 > length:
                        print(f"Too many data bytes; {index+4}>{length}. Retrying")
                        self.synchronize(); resync(); continue # goto retry

                    match lastCodeType:
                        case self.codeType_t.DATA_16BIT:
                            u = self.getWord()
                            data[index] = (firstByte(t)<<8) | firstByte(u); index+=1
                            data[index] = (secondByte(t)<<8) | secondByte(u); index+=1
                            data[index] = (thirdByte(t)<<8) | thirdByte(u); index+=1
                            data[index] = (fourthByte(t)<<8) | fourthByte(u); index+=1

                        case self.codeType_t.DATA_24BIT:
                            u = self.getWord()
                            v = self.getWord()
                            data[index] = firstByte(t)<<16 + firstByte(u)<<8 + firstByte(v); index+=1
                            data[index] = secondByte(t)<<16 + secondByte(u)<<8 + secondByte(v); index+=1
                            data[index] = thirdByte(t)<<16 + thirdByte(u)<<8 + thirdByte(v); index+=1
                            data[index] = fourthByte(t)<<16 + fourthByte(u)<<8 + fourthByte(v); index+=1
                        
                        case _:
                            print(f"Unknown data type following code 0x{lastCodeType:x}")

                case self.codeType_t.SPECTRUM_END:
                    l = t & CODE_DATA_MASK
                    if l != spectrumLength:
                        print(f"Byte count mismatch; retrying (0x{spectrumLength:06x} != 0x{l:06x})")
                        self.synchronize(); resync(); continue # goto retry
                    if l*4 != 8 + self.db.bytecount:
                        print(f"Read {8 + self.db.bytecount} bytes, expected {l*4}. Retrying")
                        self.synchronize(); resync(); continue # goto retry
                    
                    return index, data

                case self.codeType_t.DATA_STICK:
                    print(f"Stick data not supported; assuming comm error.")
                    self.synchronize(); resync(); continue # goto retry

                case self.codeType_t.TIME_LOW: pass
                case self.codeType_t.TIME_HIGH: pass
                
                case self.codeType_t.PROTOCOL: self.__lastProtocol = t & CODE_DATA_MASK
                
                case self.codeType_t.ION_COUNT:
                    if (t & CODE_DATA_MASK == CODE_DATA_MASK):
                        u = self.getWord()
                        if u == 0xffffffff:
                            print("Unexpected synchronize; restarting.")
                            resync(); continue # goto resync
                        else:
                            print("Unexpected partial resync; restarting.")
                            self.synchronize(); resync; continue # goto retry
                    
                    u = self.getWord()
                    self.getWord()
                    self.getWord()
                    self.__overload = 0
                    if u & 0x00008000: self.__overload |= OVERLOAD
                    if u & 0x80000000: self.__overload |= UNDERLOAD
                
                case _:
                    print("Unhandled code word 0x{t:08x}")

    def takeSweep(self, length, sweeps):
        if (sweeps > CHUNK_SIZE) and (DITHER_LEN != 0):
            return self.takeSweep_dither(length, sweeps)
        
        final = 0
        stop = False
        sweep = 0
        buf2 = [0 for _ in range(len)]

        if sweeps < CHUNK_SIZE:
            self.settings.recordsPerSpectrum = sweeps
            self.sendProtocol(self.settings, 0)
            self.setProtocol(0)
            self.startAquisition()
            l1, buf = self.getSpectrum(length)
            self.__rps = sweeps

        else:
            final = sweeps - (sweeps // CHUNK_SIZE)*CHUNK_SIZE
            self.settings.recordsPerSpectrum = CHUNK_SIZE
            self.sendProtocol(self.settings, 0)
            if final != 0:
                self.settings.recordsPerSpectrum = final
            else:
                final = CHUNK_SIZE
            self.sendProtocol(self.settings, 1)
            self.setProtocol(0)
            self.startAquisition()
            l1, buf = self.getSpectrum(length)
            rep_count = 2 if self.settings.recordLength > 40000 else 1

            self.__reps = CHUNK_SIZE
            while self.__reps < sweeps and not stop:
                if sweeps - (self.__rps + CHUNK_SIZE) < CHUNK_SIZE: self.setProtocol(1)

                l2, buf2 = self.getSpectrum(length)
                for i in range(length): buf[i] += buf2[i]

                if self.__rps % rep_count == 0:
                    print(f"Sweep {self.__rps}/{sweeps} ({self.getLastProtocol()})")
                
                if self.getLastProtocol == 1:
                    if final == 0: print(f"Crazy; we found a protocol 1 spectrum before we were ready ({final})!")
                    self.__rps += final
                
                else:
                    self.__rps += CHUNK_SIZE
                
                if l2 != l1: print(f"Trace length mismatch: {l2} != {l1}")
            
        if self.__rps != sweeps: print(f"Accidentally took too many sweeps ({self.__rps} > {sweeps}) {"STOP" if stop else ""}")
        self.stopAquisition()

        buf = self.applyCalibration(buf, length)
        return l1, buf

    def takeSweep_dither(self, length, sweeps):
        final = 0
        stop = False
        sweep = 0
        buf2 = [0 for _ in range(len)]
        oorigin = self.settings.voltageOffset

        if sweeps < CHUNK_SIZE:
            self.settings.recordsPerSpectrum = sweeps
            self.sendProtocol(self.settings, 0)
            self.setProtocol(0)
            self.startAquisition()
            l1, buf = self.getSpectrum(length)
            self.__rps = sweeps
            offset = 0

        else:
            chunks = min(sweeps // CHUNK_SIZE, self.maxProtocol - 1)
            final = sweeps - (sweeps // CHUNK_SIZE)*CHUNK_SIZE
            ostep = DITHER_LEN // chunks
            self.settings.recordsPerSpectrum = CHUNK_SIZE
            for i in range(chunks): 
                self.settings.voltageOffset = oorigin + i*ostep
                self.sendProtocol(self.settings, i)
            if final != 0:
                self.settings.recordsPerSpectrum = final
            else:
                final = CHUNK_SIZE

            self.settings.voltageOffset = oorigin
            self.sendProtocol(self.settings, self.maxProtocol - 1)
            self.setProtocol(sweep % chunks); sweep+=1
            self.startAquisition()
            self.setProtocol(sweep % chunks); sweep+=1
            l1, buf = self.getSpectrum(length)
            rep_count = 2 if self.settings.recordLength > 40000 else 1

            self.__reps = CHUNK_SIZE
            while self.__reps < sweeps and not stop:
                print(f"Sweep {self.__rps}/{sweeps}\r", end="")
                if sweeps - (self.__rps + CHUNK_SIZE) < CHUNK_SIZE: 
                    self.setProtocol(self.maxProtocol - 1)
                else:
                    self.setProtocol(sweep % chunks); sweep+=1

                l2, buf2 = self.getSpectrum(length)
                for i in range(length): buf[i] += buf2[i]

                if self.getLastProtocol() == self.maxProtocol - 1:
                    if final == 0: print(f"Crazy; we found a protocol 1 spectrum before we were ready ({final})!")
                    self.__rps += final
                else:
                    self.__rps += CHUNK_SIZE

                if self.__rps % rep_count == 0: print(f"Sweep {self.__rps}/{sweeps} ({self.getLastProtocol()})")
                if l2 != l1: 
                    print(f"Trace length mismatch: {l2} != {l1}")
                else:
                    if self.getLastProtocol() != self.maxProtocol - 1:
                        o = 512 * ostep * self.getLastProtocol() * CHUNK_SIZE
                        offset += o

        for i in range(length): buf[i] += offset
        if self.__rps != sweeps: 
            print(f"Accidentally took too many sweeps ({self.__rps} > {sweeps}) {"STOP" if stop else ""}")
            for i in range(length): buf[i] *= sweeps // self.__rps
        self.stopAquisition()

        buf = self.applyCalibration(buf, length)
        return l1, buf