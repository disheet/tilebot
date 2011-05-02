#include "NewSoftSerial.h"
//#include "pololu/orangutan.h"
//#include "SoftwareSerial.h"

#define rx_barcode_pin 4
#define tx_barcode_pin 5

#define rx_pololu_pin 6
#define tx_pololu_pin 7

// set up a new serial port
NewSoftSerial bcode_port(rx_barcode_pin, tx_barcode_pin);
NewSoftSerial robot_port(rx_pololu_pin, tx_pololu_pin);

char barcode_buf[32];
volatile bool new_barcode;

void send_robot(char *buf, int buflen)
{
    while(buflen)
    {
        robot_port.print(*buf);
        buf++;
        buflen--;
    }
}

// set the motor speeds
void slave_set_motors(int speed1, int speed2)
{
	char message[4] = {0xC1, speed1, 0xC5, speed2};
	if(speed1 < 0)
	{
		message[0] = 0xC2; // m1 backward
		message[1] = -speed1;
	}
	if(speed2 < 0)
	{
		message[2] = 0xC6; // m2 backward
		message[3] = -speed2;
	}
	send_robot(message,4);
}

// do calibration
void slave_calibrate()
{
	send_robot("\xB4",1);
	int tmp_buffer[5];

	// read 10 characters (but we won't use them)
	//serial_receive_blocking((char *)tmp_buffer, 10, 100);
}

// reset calibration
void slave_reset_calibration()
{
	send_robot("\xB5",1);
}

// calibrate (waits for a 1-byte response to indicate completion)
void slave_auto_calibrate()
{
	int tmp_buffer[1];
	send_robot("\xBA",1);
	//serial_receive_blocking((char *)tmp_buffer, 1, 10000);
}

// sets up the pid constants on the 3pi for line following
void slave_set_pid(char max_speed, char p_num, char p_den, char d_num, char d_den)
{
	char string[6] = "\xBB";
	string[1] = max_speed;
	string[2] = p_num;
	string[3] = p_den;
	string[4] = d_num;
	string[5] = d_den;
	send_robot(string,6);
}

// stops the pid line following
void slave_stop_pid()
{
	send_robot("\xBC", 1);
}

void read_barcode()
{
    if (new_barcode) { return; }

    int timeout = 32;
    char *ptr = barcode_buf;
    while(timeout)
    {
        if (bcode_port.available())
        {
            char ch = bcode_port.read();
            if (ch == '\r')
            {
                break;
            }
            *ptr = ch;
            ptr++;
        }
        timeout--;
    }
    *ptr = 0;
    new_barcode = true;
}

void configure_barcode_scanner()  
{
    Serial.println("barcode config");
    //bcode_port.print("<K200,0>");
    /*
    bcode_port.print("<Z>");
    */
    int timeout = 500;
    //bcode_port.print("<Ard>");
    //bcode_port.print("<K100,4>");
    bcode_port.print("<K?>");
    while(timeout)
    {
        if (bcode_port.available())
        {
            char ch = bcode_port.read();
            Serial.print(ch);
            if (ch == '>')
            {
                Serial.println("");
            }
        } else
        {
            delay(50);
            timeout -= 1;
        }
    }
    attachInterrupt(0, read_barcode, LOW);
    new_barcode = false;
}

void setup()
{
    // set the data rate for the SoftwareSerial port
    Serial.begin(9600);
    bcode_port.begin(9600);
    configure_barcode_scanner();
	robot_port.begin(9600);
	// wait for the device to show up
    Serial.println("master");
    send_robot("\x81",1);
    for(int x = 0; x < 6; ++x)
    {
        char ch = robot_port.read();
        Serial.print(ch);
    }
    Serial.println("");

    // play a tune
    char tune[] = "\xB3 l16o6gab>c";
    tune[1] = sizeof(tune)-3;

    send_robot(tune,sizeof(tune)-1);
    delay(1000);

}

void loop()
{
    if(new_barcode)
    {
        Serial.print("barcode: ");
        Serial.println(barcode_buf);
        new_barcode = false;
    }
}
