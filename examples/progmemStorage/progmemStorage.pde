#include <Flash.h>

//  Copyright (C) 2010 Georg Kaindl
//  http://gkaindl.com
//
//  This file is part of Arduino EthernetDHCP.
//
//  EthernetDHCP is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as
//  published by the Free Software Foundation, either version 3 of
//  the License, or (at your option) any later version.
//
//  EthernetDHCP is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with EthernetDHCP. If not, see
//  <http://www.gnu.org/licenses/>.
//

//  Illustrates how to use EthernetDHCP in polling (non-blocking)
//  mode.
#include <Wire.h>
#include <SL018.h>
#include <EEPROM.h>

#define NUM_CARDS 50  //total number of authorized cards we'll store
#define CARD_MEMORY_INDEX 2

SL018 rfid;
char * tagString;
int tagIndex=0;

unsigned char mode;
unsigned long lockTimer;

char command;

#define UNLOCK_TIME 3000 //time the lock will be open, in milliseconds
#define COMM_TIMEOUT 500  //time before we decide that a string didn't make it through

#define WAITING_FOR_CARD 0
#define LOCK_OPEN 1
#define LEARN_NEW_CARD 2
#define PRINT_CARDS 3
#define DELETE_ALL_CARDS 4
#define DELETE_ONE_CARD 5
#define LOAD_CARD 6



#if defined(ARDUINO) && ARDUINO > 18
#include <SPI.h>
#endif
#include <Ethernet.h>
#include <EthernetDHCP.h>

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte server[] = { 97, 107, 134, 162  }; // www.artiswrong.com

const char* ip_to_str(const uint8_t*);
Client client(server, 80);

FLASH_TABLE(char, cards, 14, {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0});

void setup()
{
  Serial.begin(115200);
  pinMode(2,OUTPUT);
  #ifdef DEBUG
    Serial.println("reading cards from EEPROM...");
  #endif
  readCards();

  
  #ifdef DEBUG
  Serial.println("done!");
  #endif

  mode=WAITING_FOR_CARD;

  #ifdef DEBUG
  Serial.println("listening for cards...");
  #endif
  
  Serial.print("+");  //all systems go!
  
  // Initiate a DHCP session. The argument is the MAC (hardware) address that
  // you want your Ethernet shield to use. The second argument enables polling
  // mode, which means that this call will not block like in the
  // SynchronousDHCP example, but will return immediately.
  // Within your loop(), you can then poll the DHCP library for its status,
  // finding out its state, so that you can tell when a lease has been
  // obtained. You can even find out when the library is in the process of
  // renewing your lease.
  EthernetDHCP.begin(mac, 1);
  Wire.begin();
}

void loop()
{
  static DhcpState prevState = DhcpStateNone;
  static unsigned long prevTime = 0;
  
  // poll() queries the DHCP library for its current state (all possible values
  // are shown in the switch statement below). This way, you can find out if a
  // lease has been obtained or is in the process of being renewed, without
  // blocking your sketch. Therefore, you could display an error message or
  // something if a lease cannot be obtained within reasonable time.
  // Also, poll() will actually run the DHCP module, just like maintain(), so
  // you should call either of these two methods at least once within your
  // loop() section, or you risk losing your DHCP lease when it expires!
  DhcpState state = EthernetDHCP.poll();

  if (prevState != state) {
    Serial.println();

    switch (state) {
      case DhcpStateDiscovering:
        Serial.print("Discovering servers.");
        break;
      case DhcpStateRequesting:
        Serial.print("Requesting lease.");
        break;
      case DhcpStateRenewing:
        Serial.print("Renewing lease.");
        break;
      case DhcpStateLeased: {
        Serial.println("Obtained lease!");

        // Since we're here, it means that we now have a DHCP lease, so we
        // print out some information.
        const byte* ipAddr = EthernetDHCP.ipAddress();
        const byte* gatewayAddr = EthernetDHCP.gatewayIpAddress();
        const byte* dnsAddr = EthernetDHCP.dnsIpAddress();

        Serial.print("My IP address is ");
        Serial.println(ip_to_str(ipAddr));

        Serial.print("Gateway IP address is ");
        Serial.println(ip_to_str(gatewayAddr));

        Serial.print("DNS IP address is ");
        Serial.println(ip_to_str(dnsAddr));

        Serial.println();
        
        break;
      }
    }
  } else if (state != DhcpStateLeased && millis() - prevTime > 300) {
     prevTime = millis();
     Serial.print('.'); 
  }

  prevState = state;
  if(waitForCard(500))
    logEntry();    
}

void logEntry()
{
  if (client.connect()) {
    client.print("GET /OpenLock/log.php?card=");
    client.print(tagString);
    client.println(" HTTP/1.0"); 
    client.println();
  } 
  else {
    Serial.println(" connection failed");
  } 
  client.stop();
  client.flush();  
}


boolean waitForCard(int timeout)
{
  unsigned long waitTimer=millis();

  // start seek mode
  rfid.seekTag();
  // loop until we detect a tag or we timeout
  while(!rfid.available()&&(millis()-waitTimer<timeout));
  // print tag id
  tagString=rfid.getTagString();
  return rfid.available();
}

void readCards()
{
  int i,j;
  
  tagIndex=EEPROM.read(0)*256+EEPROM.read(1);
  for(i=0;i<tagIndex,i<NUM_CARDS;i++)
    for(j=0;j<14;j++)      
      cards[i][j]=EEPROM.read(CARD_MEMORY_INDEX+i*14+j);
}


// Just a utility function to nicely format an IP address.
const char* ip_to_str(const uint8_t* ipAddr)
{
  static char buf[16];
  sprintf(buf, "%d.%d.%d.%d\0", ipAddr[0], ipAddr[1], ipAddr[2], ipAddr[3]);
  return buf;
}


