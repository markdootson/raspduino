// Drive 8 Pixel NeoPixel Stick

#include <Adafruit_NeoPixel.h>
#ifdef __AVR__
  #include <avr/power.h>
#endif
#include <Wire.h>

#define NEOPIXEL_PIN      6
#define NUM_LEDS          8
#define I2C_BUS_ADDRESS   0x55

// Registers
#define REG_CONFIG        0x00
#define REG_BRIGHTNESS    0x01
#define REG_PIXEL_0       0x04
#define REG_PIXEL_1       0x08
#define REG_PIXEL_2       0x0C
#define REG_PIXEL_3       0x10
#define REG_PIXEL_4       0x14
#define REG_PIXEL_5       0x18
#define REG_PIXEL_6       0x1C
#define REG_PIXEL_7       0x20

#define MAX_REGISTER      REG_PIXEL_7 + 3

// config Register
#define CONFIG_SHOW       0x02
#define CONFIG_CLEAR      0x04

bool pixel_update_pending = false;
bool request_mode = false;
unsigned int regpointer = 0;

byte registers[] = {
  0, 5, 
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0
};

Adafruit_NeoPixel strip = Adafruit_NeoPixel(NUM_LEDS, NEOPIXEL_PIN, NEO_GRBW + NEO_KHZ800);

void setup() {
  Wire.begin(I2C_BUS_ADDRESS);      // join i2c bus with address DEV_ADDRESS
  Wire.onReceive(receiveEvent);     // register event
  Wire.onRequest(requestEvent);     // register event
  Serial.begin(9600);
  Serial.print("Arduino 8 Neopixel Pixel Stick Controller on 0x");
  Serial.println(I2C_BUS_ADDRESS, HEX);
  // setup strip all off
  strip.setBrightness(registers[REG_BRIGHTNESS]);
  strip.begin();
  strip.show();
}

// receive event - only set registers in here
void receiveEvent(int bytesreceived) {
  byte input;

  if( bytesreceived == 0 )
    return;

  // the first byte is our regpointer
  regpointer = Wire.read();
  
  if( bytesreceived == 1 ) {
    request_mode = true;
    return;
  }
  
  // we wrap the reg pointer
  while( regpointer > MAX_REGISTER ) {
    regpointer -= MAX_REGISTER;
  }

  while( Wire.available() ) {
    registers[regpointer] = Wire.read();
    regpointer++;
    if(regpointer > MAX_REGISTER)
      regpointer = 0;
  }

  pixel_update_pending = true;
}

// request event - only read registers in here
void requestEvent() {
  byte writebuffer[4];
  int i;
  int devindex;
  int readbytes = 4;

  if( request_mode == false ) {
    // write null buffer byte
    Wire.write(writebuffer, 1);
    return;
  }
  
  request_mode = false;

  // reads of the first 4 registers return a single byte
  if( regpointer < 3 )
    readbytes = 1;
    
  for( i = 0; i < readbytes; ++i ) {
    devindex = regpointer + i;
    // wrap request
    if(devindex > MAX_REGISTER)
      devindex -= ( MAX_REGISTER + 1 ); 
      
    writebuffer[i] = registers[devindex];
  }
  
  Wire.write(writebuffer, readbytes);
}

void update_neopixels() {
  int i;
  int pixel_num;

  if( registers[REG_CONFIG] & CONFIG_CLEAR ) {
    for ( i = 4; i < MAX_REGISTER; i ++ ) {
      registers[i] = 0;
    }
    // clear the config bit
    registers[REG_CONFIG] &= ~CONFIG_CLEAR;
    // clear the pixels
    strip.clear();
    // always update on clear
    strip.show();
  }

  if( registers[REG_CONFIG] & CONFIG_SHOW ) {
    // set the brightness
    strip.setBrightness(registers[REG_BRIGHTNESS]);
    // set the pixel colors - groups of 4 from register REG_PIXEL_0 upwards
    for ( i = 4; i < MAX_REGISTER; i += 4 ) {
      pixel_num = ( i - REG_PIXEL_0 ) / 4;
      strip.setPixelColor(pixel_num, strip.Color( 
        registers[i],
        registers[i + 1],
        registers[i + 2],
        registers[i + 3]
          )
      );
    }
    // clear the config bit
    registers[REG_CONFIG] &= ~CONFIG_SHOW;
    // refresh the pixels
    strip.show();
  }
}

void loop() {
  if( pixel_update_pending ) {
    pixel_update_pending = false;
    update_neopixels();
  }
  delay(10);
}
