import controlP5.*;
import processing.serial.*;
import javax.swing.*; 

Serial myPort;
String [] cards;
int a=0;
String tagString="";

ControlP5 controlP5;



void setup()
{
  cards=new String[0];
  myPort=new Serial(this, Serial.list()[0], 115200);
  while (myPort.available ()==0) {
  }
  myPort.read();
  size(800, 800);
  controlP5 = new ControlP5(this);
  controlP5.addButton("teach", 0, 500, 20, 100, 20);
  controlP5.addButton("save to file", 0, 500, 450, 100, 20);
  controlP5.addButton("load from file", 0, 500, 480, 100, 20);
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
    if(tagString!=null)
    {
    if (tagString.equals(cards[i]))
      fill(0, 255, 0);
    else
      fill(255);
      text(cards[i], 20, 20+i*20);
}
  }
  text("Last card checked :"+tagString, 500, 200);
  if (myPort.available ()>0)
    tagString=myPort.readStringUntil(10);
  a++;
}

void keyPressed()
{
  switch(key)
  {
    case('Z'):  //delete all cards!
    myPort.write('Z');
    break;
    case('P'):  //print out cards!
    readCards();
    break;
    case('L'):  //learn new card
    myPort.write('L');
    break;
    case('R'):  //delete card number 1
    myPort.write('R');
    myPort.write(1);
    break;
  }
}


void readCards()
{
  myPort.clear();
  myPort.write('P');
  delay(1000);

  int num=myPort.read();
  if (num>0)
  {
    for (int i=0;i<cards.length;i++)
      controlP5.remove("delete"+i);
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

void saveToFile()
{
// set system look and feel 
 
try { 
  UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName()); 
} catch (Exception e) { 
  e.printStackTrace();  
 
} 
 
// create a file chooser 
final JFileChooser fc = new JFileChooser(sketchPath("")); 
 
// in response to a button click: 
int returnVal = fc.showSaveDialog(this); 
 
if (returnVal == JFileChooser.APPROVE_OPTION) { 
  File file = fc.getSelectedFile(); 
  PrintWriter output;
  output=createWriter(file);
  for(int i=0;i<cards.length;i++)
  {
    output.print(cards[i]);
    for(int j=0;j<cards[i].length();j++)
      print(cards[i].charAt(j)+" ");
  }
  output.flush();
  output.close();
}
 else { 
  println("save command cancelled by user."); 
}  
}

void loadFromFile()
{
  // set system look and feel 
 
try { 
  UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName()); 
} catch (Exception e) { 
  e.printStackTrace();  
 
} 
 
// create a file chooser 
final JFileChooser fc = new JFileChooser(sketchPath("")); 
println("file chooser!"); 
// in response to a button click: 
int returnVal = fc.showOpenDialog(this); 
 
if (returnVal == JFileChooser.APPROVE_OPTION) { 
  File file = fc.getSelectedFile(); 
  String loadedCards[]=loadStrings(file);
  myPort.write('Z');  //delete all cards
  for(int i=0;i<loadedCards.length;i++) 
 { 
   println(loadedCards[i]);
   
    myPort.write('S');
    delay(50);
    for(int j=0;j<loadedCards[i].length();j++)
      myPort.write(loadedCards[i].charAt(j));
    myPort.write('\n');
    delay(1000);
      if(myPort.available()>0)
        println((char)myPort.read());
 }
}
else
{
  println("load command cancelled by user");
}
readCards();
}
public void controlEvent(ControlEvent theEvent) {
  println(theEvent.controller().name());
  if (theEvent.controller().name().equals("teach"))
  {
    myPort.write('L');
    delay(5000);
    readCards();
  }
  if (theEvent.controller().name().equals("save to file"))
    saveToFile();
  if (theEvent.controller().name().equals("load from file"))
    loadFromFile();    
  for (int i=0;i<cards.length;i++)
    if (theEvent.controller().name().equals("delete"+i))
    {
      println("deleting ..."+i);
      myPort.write('R');
      myPort.write(i);
      readCards();
    }
}

