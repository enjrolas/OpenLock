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
  pollEthernet();
  if(Serial.available()>0)
    {
      command=Serial.read();
      interpretCommand();
    }
  if(mode==WAITING_FOR_CARD)
  {
    if(waitForCard(500))
    {
    Serial.println(tagString);
    if(checkAllCards())
    {
      mode=LOCK_OPEN;
      lockTimer=millis();
      #ifdef DEBUG
        Serial.println("opening lock...");
      #endif
    }
    }
  }
  if(mode==LOCK_OPEN)
  {
    digitalWrite(2,HIGH);
    if((millis()-lockTimer)>UNLOCK_TIME)
      {
        #ifdef DEBUG
        Serial.println("Time's up!  Lock's closing");
        #endif
        mode=WAITING_FOR_CARD;
        digitalWrite(2,LOW);
      }
  }
  if(mode==PRINT_CARDS)
  {
    printCards();
    mode=WAITING_FOR_CARD;
  }
  if(mode==LEARN_NEW_CARD)
  {
    #ifdef DEBUG
      Serial.println("I'm going to authorize the next card you show me!");
    #endif
    if(waitForCard(5000))
    {  
      if(!checkAllCards())  //only save the card if we don't already have it stored
      {
        saveCard(tagIndex);
      }
      else
      {
        #ifdef DEBUG
          Serial.println("I already know that card.  I think we should meet new people");
        #endif
      }
    }
    else
    {
      #ifdef DEBUG
        Serial.println("you didn't show me a card in time.  Try again!");
      #endif
    }
    mode=WAITING_FOR_CARD;
  }
  if(mode==DELETE_ALL_CARDS)
  {
    deleteAllCards();
    mode=WAITING_FOR_CARD;
  }
  if(mode==DELETE_ONE_CARD)
  {
      unsigned long timeout=millis();
      while((Serial.available()==0)&&(millis()-timeout<500)){}  //wait for the index of the card we should delete   
      if(millis()-timeout<500)
      {
        unsigned char deletionIndex=Serial.read();
        deleteOneCard(deletionIndex);
        #ifdef DEBUG
          Serial.print("Deleting card number");
          Serial.println(deletionIndex);
        #endif
      }
      else
      {
        #ifdef DEBUG
          Serial.println("hmmm, you never told us what to delete.  Going back to the main loop");
        #endif
      }
      mode=WAITING_FOR_CARD;
    }
    if(mode==LOAD_CARD)
    {
      loadCard();
      mode=WAITING_FOR_CARD;        
    }
}

void pollEthernet()
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
  tagIndex=EEPROM.read(0)*256+EEPROM.read(1);
}


// Just a utility function to nicely format an IP address.
const char* ip_to_str(const uint8_t* ipAddr)
{
  static char buf[16];
  sprintf(buf, "%d.%d.%d.%d\0", ipAddr[0], ipAddr[1], ipAddr[2], ipAddr[3]);
  return buf;
}

void loadCard()
{
      unsigned long timeout=millis();
      char a=' ';
      unsigned char i;
      i=0;
      while((Serial.available()>0)&&(a!='\n')&&(i<14)&&(millis()-timeout<COMM_TIMEOUT))
      {
        tagString[i]=Serial.read();
        a=tagString[i];
        i++;
      }
      if(i>14)  //string was too long
      {
        Serial.print("-");  //something's wrong
      }
      else if(millis()-timeout>COMM_TIMEOUT)  //took too long
      {
        Serial.print("-");  //something's wrong
      }     
      else //we got a null-terminated string that's the right length
      {
        saveCard(tagIndex);
        Serial.print("+");  //success!
      }
}

void interpretCommand()
{
  if(command=='L')
    mode=LEARN_NEW_CARD;
  if(command=='S')
    mode=LOAD_CARD;
  if(command=='P')
    mode=PRINT_CARDS;
  if(command=='Z')
    mode=DELETE_ALL_CARDS;
   if(command=='R')
     mode=DELETE_ONE_CARD;
}

boolean checkAllCards()
{
  boolean match=false;
  int i=0;
  while((match==false)&&(i<tagIndex))
  {
    #ifdef DEBUG
      Serial.print("checking ");
      Serial.print(i);
      Serial.print("...  ");
    #endif
    
    match=checkCard(i);

    #ifdef DEBUG
    if(match)
      Serial.println("it's a match!");
    else
      Serial.println("no poop");
    #endif  
     
    i++;
  }
  return match;  
}

boolean checkCard(int cardIndex)
{
  boolean match=true;
  int i;
  for(i=0;i<14;i++)
    if(EEPROM.read(CARD_MEMORY_INDEX+cardIndex*14+i)!=tagString[i])
      match=false;
  return match;
}

void saveCard(int index)
{
  int a;
  for(a=0;a<14;a++)
    EEPROM.write(CARD_MEMORY_INDEX+index*14+a,tagString[a]);    
  
  #ifdef DEBUG
    Serial.print("saved new card ");
    for(a=0;a<14;a++)
      Serial.print(tagString[a]);
    Serial.print(" to index ");
    Serial.println(tagIndex);
  #endif
  //update the tag indices, too
  tagIndex++;
  saveTagIndex();

}

void deleteOneCard(int index)
{
  #ifdef DEBUG
    Serial.print("deleting card ");
    Serial.println(index);
  #endif
  int i;
  for(i=index;i<tagIndex-1;i++)
    for(int j=0;j<14;j++)
      EEPROM.write(CARD_MEMORY_INDEX+i*14+j,EEPROM.read(CARD_MEMORY_INDEX+(i+1)*14+j));
  tagIndex--;
  saveTagIndex();
  #ifdef DEBUG
    Serial.println("done");
  #endif
}

void deleteAllCards()
{
  #ifdef DEBUG
  Serial.println("deleting all cards....");
  #endif
  
  tagIndex=0;
  saveTagIndex();
  readCards();
  
  #ifdef DEBUG
  Serial.println("done");
  #endif
  
}

void saveTagIndex()
{
  EEPROM.write(0,tagIndex/256);
  EEPROM.write(1,tagIndex%256);
}

void printCards()
{
  char a;
  int i,j;
  #ifdef DEBUG
  Serial.print("you've stored ");
  Serial.print(tagIndex);
  Serial.println(" cards");
  #endif
  Serial.print(tagIndex,BYTE);
  for(i=0;i<tagIndex;i++)
  {
    Serial.print(i);
    Serial.print(",");
    for(j=0;j<14;j++)
      Serial.print(EEPROM.read(CARD_MEMORY_INDEX+i*14+j));
    Serial.println();
  }
}
