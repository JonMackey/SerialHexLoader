# ArduinoISP eeprom write bug

Bug in ArduinoISP example code when writing large blocks of eeprom data:

When writing to eeprom, the circular serial buffer gets overwritten when writing more than twice the length of the serial input buffer bytes of data.  This happens because the serial data is read within write_eeprom_chunk() at 32 bytes at a time and may take several seconds to write the data to the eeprom. According to the SDK500 doc you should be able to write up to 256 bytes for each write request.

# Fix
Move the fill() call from write_eeprom_chunk() to write_eeprom().  The moved fill() will read the entire length of the requested device block in one shot.  Pass write_eeprom_chunk() the dataOffset within the ArduinoISP input buffer (which has a 256 byte capacity.)

```
uint8_t write_eeprom(unsigned int length) {
  // here is a word address, get the byte address
  unsigned int start = here * 2;
  unsigned int remaining = length;
  unsigned int dataOffset = 0;
  if (length > param.eepromsize) {
    error++;
    return STK_FAILED;
  }
  fill(length);
  
  while (remaining > EECHUNK) {
    write_eeprom_chunk(start, EECHUNK, dataOffset);
    start += EECHUNK;
    dataOffset += EECHUNK;
    remaining -= EECHUNK;
  }
  write_eeprom_chunk(start, remaining, dataOffset);
  return STK_OK;
}
// write (length) bytes, (start) is a byte address
uint8_t write_eeprom_chunk(unsigned int start, unsigned int length, unsigned int dataOffset) {
  // this writes byte-by-byte, page writing may be faster (4 bytes at a time)
 // fill(length);	moved to write_eeprom
  prog_lamp(LOW);
  for (unsigned int x = 0; x < length; x++) {
    unsigned int addr = start + x;
    spi_transaction(0xC0, (addr >> 8) & 0xFF, addr & 0xFF, buff[x+dataOffset]);
    delay(45);
  }
  prog_lamp(HIGH);
  return STK_OK;
}
```
