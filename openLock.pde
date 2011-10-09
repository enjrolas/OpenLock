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
#define numCards 50  //total number of authorized cards we'll store

char cards[50][14];

SL018 rfid;
int tagIndex=0;
char * tagString;

void setup()
{
  Wire.begin();
  Serial.begin(115200);
  pinMode(2,OUTPUT);
  Serial.println("reading cards from EEPROM...");
  readCards();
  Serial.println("done!");
  tagString="047F8F21E30280";
  if(checkAllCards())
    Serial.println("bam!");
  // prompt for tag
  Serial.println("Show me your tag");
}


void readCards()
{
  int i,j;
  for(i=0;i<numCards;i++)
    for(j=0;j<14;j++)      
      cards[i][j]=EEPROM.read(i*14+j);
}

void loop()
{
  
  // start seek mode
  rfid.seekTag();
  // wait until tag detected
  while(!rfid.available());
    
  // print tag id
  tagString=rfid.getTagString();
  if(checkAllCards())
  {
    Serial.println("It's a match!");
    digitalWrite(2,HIGH);
    delay(5000);
    digitalWrite(2,LOW);
  }
  else
    Serial.println("no joy, buttface");  
  Serial.println(tagString);
}

boolean checkAllCards()
{
  boolean match=false;
  int i=0;
  while((match==false)&&(i<numCards))
  {
    Serial.print("checking ");
    Serial.print(i);
    Serial.print("...  ");
    match=checkCard(i);
    if(match)
      Serial.println("it's a match!");
    else
      Serial.println("no poop");
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
  int a=0;
  for(a=0;a<14;a++)
  {
    EEPROM.write(index+a,tagString[a]);    
    cards[index][a]=tagString[a];
  }
}

void printCards()
{
  char a;
  int i,j;
  Serial.print("you've stored ");
  Serial.print(tagIndex);
  Serial.println(" cards");
  for(i=0;i<numCards;i++)
  {
    Serial.print(i);
    Serial.print(":  ");
    for(j=0;j<14;j++)
      Serial.print(cards[i][j]);
    Serial.println();
  }
}
