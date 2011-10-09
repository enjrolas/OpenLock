#include <EEPROM.h>

/**
 *  @title:  StrongLink SL018/SL030 RFID reader demo
 *  @author: marc@marcboon.com
 *  @see:    http://www.stronglink.cn/english/sl018.htm
 *  @see:    http://www.stronglink.cn/english/sl030.htm
 *
 *  Arduino to SL018/SL030 wiring:
 *  A4/SDA     2     3
 *  A5/SCL     3     4
 *  5V         4     -
 *  GND        5     6
 *  3V3        -     1
 */

#include <Wire.h>
#include <SL018.h>


//  #define DEBUG 1     //uncomment this line if you want to play with the arduino in debug mode,
                        //but it'll BREAK the system if you try to use it with the computer-side
                        //software in debug mode


#define NUM_CARDS 50  //total number of authorized cards we'll store
#define CARD_MEMORY_INDEX 2

char cards[50][14];
unsigned char buffer[5];

SL018 rfid;
int tagIndex=0;
char * tagString;

unsigned char mode;
unsigned long lockTimer;

char command;

#define UNLOCK_TIME 3000 //time the lock will be open, in milliseconds

#define WAITING_FOR_CARD 0
#define LOCK_OPEN 1
#define LEARN_NEW_CARD 2
#define PRINT_CARDS 3
#define DELETE_ALL_CARDS 4
#define DELETE_ONE_CARD 5

void setup()
{

  Wire.begin();
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
}

void readCards()
{
  int i,j;
  tagIndex=EEPROM.read(0)*256+EEPROM.read(1);
  for(i=0;i<tagIndex,i<NUM_CARDS;i++)
    for(j=0;j<14;j++)      
      cards[i][j]=EEPROM.read(CARD_MEMORY_INDEX+i*14+j);
}

void loop()
{
  if(Serial.available()>0)
    {
      command=Serial.read();
      interpretCommand();
    }
  if(mode==WAITING_FOR_CARD)
  {
    if(waitForCard(500))
    {
      if(checkAllCards())
    {
      Serial.println(tagString);
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

void interpretCommand()
{
  if(command=='L')
    mode=LEARN_NEW_CARD;
  if(command=='P')
    mode=PRINT_CARDS;
  if(command=='D')
    mode=DELETE_ALL_CARDS;
   if(command=='R')
     mode=DELETE_ONE_CARD;
}

boolean checkAllCards()
{
  Serial.println(mode);
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
    if(cards[cardIndex][i]!=tagString[i])
      match=false;
  return match;
}

void saveCard(int index)
{
  int a;
  for(a=0;a<14;a++)
  {
    EEPROM.write(CARD_MEMORY_INDEX+index*14+a,tagString[a]);    
    cards[index][a]=tagString[a];
  }
  
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
  {
    for(int j=0;j<14;j++)
    {
      cards[i][j]=cards[i+1][j];
      EEPROM.write(CARD_MEMORY_INDEX+i*14+j,cards[i][j]);
    }    
  }
  tagIndex--;
  saveTagIndex();
  #ifdef DEBUG
    Serial.println("done");
  #endif
}

void deleteAllCards()
{
  Serial.println("deleting all cards....");
  tagIndex=0;
  saveTagIndex();
  readCards();
  Serial.println("done");
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
      Serial.print(cards[i][j]);
    Serial.println();
  }
}
