
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Threading;
//using UnityEditor.Experimental.GraphView;
using UnityEngine;
using UnityEngine.UIElements;

/*
 * JediComm
 * Class to handle serial communication with a device using the JEDI (Jolly sErial Data Interface)
 * format for data communication.
 */
public static class JediComm
{
    public static SerialPort serPort { get; private set; }
    private static Thread reader;

    //payLoad related variables
    static public byte[] payLoadBytes = new byte[256] ;

    // Headers for Rx and Tx.
    static public byte HeaderIn = 0xFF;
    static public byte[] HeaderOut = new byte[] { 0xFF, 0xFE };

    static private DateTime plTime;
    //flags
    private static bool stop = false;
    private static bool pause = false;
    public static volatile bool isMars = false;
    public static int plcount;

    public static void ConnectToRobot(String port)
    {
        serPort = new SerialPort
        {
            PortName = port,
            BaudRate = 115200,
            Parity = Parity.None,
            DataBits = 8,
            StopBits = StopBits.One,
            Handshake = Handshake.None,
            DtrEnable = true,
            ReadTimeout = 500,
            WriteTimeout = 500,
        

        };
        if (serPort.IsOpen)
        {
            serPort.Close(); // Close the port if it’s already open.
        }
        if (!serPort.IsOpen)
        {
            stop = false;
            try
            {
                serPort.Open();
            }
            catch (Exception ex)
            {
                Debug.Log("exception: " + ex);
            }

            reader = new Thread(SerialReaderThread);
            reader.Start();
        }
    }

    public static void Disconnect()
    {
        if (serPort.IsOpen)
        {
            stop = true;
            reader.Join(); // Ensure the reader thread has exited
            serPort.Close();
            Debug.Log("Serial port closed.");
        }
    }


    public static void SerialReaderThread()
    {
        while (!stop)
        {
            if (pause) continue;

            try
            {
                //DebugReadBytes();
                if (ReadFullSerialPacket())
                {
                    plTime = DateTime.Now;
                    isMars = true;
                    MarsComm.initalizeDataLength((int)plcount);
                    MarsComm.parseRawBytes(payLoadBytes, (uint)plcount, plTime);
                }
                ////AppData.sendToRobot();
            }
            catch (TimeoutException)
            {
                isMars = false; 
                continue;        
            }
        }
        serPort.Close();  
    }
    private static void DebugReadBytes()
    {
        int availableBytes = serPort.BytesToRead;
        if (availableBytes > 0)
        {
            byte[] buffer = new byte[availableBytes];
            serPort.Read(buffer, 0, availableBytes);

            Debug.Log("Raw Bytes: " + BitConverter.ToString(buffer));
        }
    }
   
    private static bool ReadFullSerialPacket()
    {
        int checksum = 0;
        int receivedChecksum;
        plcount = 0;
    
        if (serPort.ReadByte() == HeaderIn && serPort.ReadByte() == HeaderIn)
        {
            checksum += HeaderIn + HeaderIn;
            // Read payload size
            payLoadBytes[plcount++] = (byte)serPort.ReadByte();
            //Debug.Log(payLoadBytes[0]);
            checksum += payLoadBytes[0];
            if (payLoadBytes[0] != HeaderIn) 
            { 
                for (int i = 0; i < payLoadBytes[0]-1; i++)
                {
                    payLoadBytes[plcount++] = (byte)serPort.ReadByte();
                    checksum += payLoadBytes[plcount-1];
                }
                // Read the transmitted checksum
                receivedChecksum = serPort.ReadByte();
               
                return (receivedChecksum == (checksum & 0xFF));
            }
            else
            {
                return false;
            }
        }
        else{
            return false;
        }
        
    }

    public static void SendMessage(byte[] outBytes)
    {
        List<byte> outPayload = new List<byte>
        {
            HeaderOut[0], // Header byte 1
            HeaderOut[1], // Header byte 2
            (byte)(outBytes.Length + 1) // Length of the message (+1 for checksum)
        };

        outPayload.AddRange(outBytes);
        byte checksum = (byte)(outPayload.Sum(b => b) % 256);
        outPayload.Add(checksum);

        bool outDebug = false; // Set this to true for debugging
        if (outDebug)
        {
            Debug.Log("Out data: " + string.Join(" ", outPayload.Select(b => b.ToString("X2"))));
        }

        try
        {
            serPort.Write(outPayload.ToArray(), 0, outPayload.Count);
            Debug.Log("Message sent to device.");
        }
        catch (Exception ex)
        {
            Debug.LogError($"Error sending message: {ex.Message}");
        }
    }
}
