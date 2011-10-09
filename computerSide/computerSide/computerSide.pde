import controlP5.*;
import processing.serial.*;

Serial myPort;
String [] cards;
int a=0;

ControlP5 controlP5;

void readCards()
{
  myPort.clear();
  myPort.write('P');
  delay(1000);

  int num=myPort.read();
  if (num>0)
  {
    cards=new String[num];
    for (int i=0;i<num;i++)  
    {  
      controlP5.addButton("delete"+i, 0, 150, 5+i*20, 100, 20);
      String temp=myPort.readStringUntil(10);
      String [] parts=split(temp, ',');
      cards[i]=parts[1];
    }
  }
}


void setup()
{
  cards=new String[0];
  myPort=new Serial(this, Serial.list()[0], 115200);
  while (myPort.available ()==0) {
  }
  myPort.read();
  size(800, 800);
  controlP5 = new ControlP5(this);
  controlP5.addButton("teach",0,500,20,100,20);
  
}

void draw()
{
  if (a==0)
    readCards();
  background(0);
  stroke(255);
  fill(255);
  for (int i=0;i<cards.length;i++)
  {
    text(cards[i], 20, 20+i*20);
  }
  while (myPort.available ()>0)
    print((char)myPort.read());  
  a++;
}

void keyPressed()
{
  switch(key)
  {
    case('D'):
    myPort.write('D');
    break;
    case('P'):
    readCards();
    break;
    case('L'):
    myPort.write('L');
    break;
    case('R'):
    myPort.write('R');
    myPort.write(1);
    break;
  }
}

public void controlEvent(ControlEvent theEvent) {
  println(theEvent.controller().name());
  if(theEvent.controller().name().equals("teach"))
  {
    myPort.write('L');
    delay(5000);
    readCards();
  }
  for(int i=0;i<cards.length;i++)
    if(theEvent.controller().name().equals("delete"+i))
    {
      println("deleting ..."+i);
      myPort.write('R');
      myPort.write(i);
      readCards();
    }
}

