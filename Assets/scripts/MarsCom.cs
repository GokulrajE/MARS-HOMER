using UnityEngine;
using System.IO;
//using System.IO.Ports;
using System;
using System.ComponentModel;


public static class MarsComm 
{
 
    static public float[] currentSensorData;
    static public byte currentButtonState,previousButtonState;
    static int sensorDataLength ; 
   
    // Button released event.
    public delegate void MarsButtonReleasedEvent();
    public static event MarsButtonReleasedEvent OnButtonReleased;

    //constant variables
    private const float len1 = 475.0f, len2 = 291.0f;
    static public float shF, shA, elF;

    static public float theta1, theta2, theta3, theta4;
    public static float[] shPos = new float[3];
    static public float[] endPt = new float[3];
    static public float[] zvec = new float[3];
    static public float[] elPt = new float[3];
    static public float[] fA = new float[3];
    static public float[] uA = new float[3];
    public static int[] CONTROL_STATUS_CODE = new int[] { 1001,  //hold
                                                             0   //release
                                                        };
    public static float SUPPORT;
    public static float[] SUPPORT_CODE = new float[] {
                                                         0.0f,//NoSupport
                                                         1.0f,//FullWeightSupport
                                                         0.5f //HalfweightSupport
                                                      };
    public static float[] OFFSET = new float[] { 0,
                                                -0.01745f,//LEFT-HAND 
                                                 0.01745f //RIGHT-HAND
                                                };

    public static int controlStatus;
    public static float thetades1;

    static public DateTime currentTime { get; private set; }
    //static public float angleOne
    //{
    //    get
    //    {
    //        return currentSensorData[0];
    //    }
    //}
    //static public float angleTwo
    //{
    //    get
    //    {
    //        return currentSensorData[1];
    //    }
    //}
    //static public float angleThree
    //{
    //    get
    //    {
    //        return currentSensorData[2];
    //    }
    //}
    //static public float angleFour
    //{
    //    get
    //    {
    //        return currentSensorData[3];
    //    }
    //}
    //static public float forceOne
    //{
    //    get
    //    {
    //        return currentSensorData[4];
    //    }
    //}
    //static public float calibBtnState
    //{
    //    get
    //    {
    //        return currentSensorData[5];
    //    }
    //}
    //static public float desOne
    //{
    //    get
    //    {
    //        return currentSensorData[6];
    //    }
    //}
    //static public float desTwo
    //{
    //    get
    //    {
    //        return currentSensorData[7];
    //    }
    //}
    //static public float desThree
    //{
    //    get
    //    {
    //        return currentSensorData[8];
    //    }
    //}
    //static public float pcParameter
    //{
    //    get
    //    {
    //        return currentSensorData[9];
    //    }
    //}

    static public float angleOne
    {
        get
        {
            return currentSensorData[0];
        }
    }
    static public float angleTwo
    {
        get
        {
            return currentSensorData[1];
        }
    }
    static public float angleThree
    {
        get
        {
            return currentSensorData[2];
        }
    }
    static public float angleFour
    {
        get
        {
            return currentSensorData[3];
        }
    }
    static public float forceOne
    {
        get
        {
            return currentSensorData[4];
        }
    }
    static public float calibBtnState
    {
        get
        {
            return currentSensorData[5];
        }
    }
    static public float desOne
    {
        get
        {
            return currentSensorData[6];
        }
    }
    static public float desTwo
    {
        get
        {
            return currentSensorData[7];
        }
    }
    static public float desThree
    {
        get
        {
          
            return currentSensorData[8];
        }
    }
    static public float pcParameter
    {
        get
        {
            return currentSensorData[9];
        }
    }
    static public float shPosX
    {
        get
        {
            return currentSensorData[10];
        }
    }
    static public float shPosY
    {
        get
        {
            return currentSensorData[11];
        }
    }
    static public float shPosZ
    {
        get
        {
            return currentSensorData[12];
        }
    }
    static public float lenUpperArm
    {
        get
        {
            return currentSensorData[13];
        }
    }
    static public float lenLowerArm
    {
        get
        {
            return currentSensorData[14];
        }
    }
    static public float weight1
    {
        get
        {
            return currentSensorData[15];
        }
    }
    static public float weight2
    {
        get
        {
            return currentSensorData[16];
        }
    }
    static public float imuAng1
    {
        get
        {
            return currentSensorData[17];
        }
    }
    static public float imuAng2
    {
        get
        {
            return currentSensorData[18];
        }
    }
    static public float imuAng3
    {
        get
        {
            return currentSensorData[19];
        }
    }
    static public float imuAng4
    {
        get
        {
            return currentSensorData[20];
        }
    }
    //if we need to get imuRaw values
    //static public float imu1aX
    //{
    //    get
    //    {
    //        return currentSensorData[21];
    //    }
    //}
    //static public float imu1aY
    //{
    //    get
    //    {
    //        return currentSensorData[22];
    //    }
    //}
    //static public float imu1aZ
    //{
    //    get
    //    {
    //        return currentSensorData[23];
    //    }
    //}
    //static public float imu2aX
    //{
    //    get
    //    {
    //        return currentSensorData[24];
    //    }
    //}
    //static public float imu2aY
    //{
    //    get
    //    {
    //        return currentSensorData[25];
    //    }
    //}
    //static public float imu2aZ
    //{
    //    get
    //    {
    //        return currentSensorData[26];
    //    }
    //}
    //static public float imu3aX
    //{
    //    get
    //    {
    //        return currentSensorData[27];
    //    }
    //}
    //static public float imu3aY
    //{
    //    get
    //    {
    //        return currentSensorData[28];
    //    }
    //}
    //static public float imu3aZ
    //{
    //    get
    //    {
    //        return currentSensorData[29];
    //    }
    //}
    static public byte buttonState
    {
        get
        {
            return currentButtonState;
        }
    }
 
    static public void initalizeDataLength(int lenght)
    {
        sensorDataLength = (int)(lenght - 2) / 4; //buttonState,checksum bytes
        Debug.Log(sensorDataLength);

        currentSensorData = new float[sensorDataLength];
    }
    static public void parseRawBytes(byte[] rawBytes, uint payloadSize ,DateTime plTime)
    {
        //Debug.Log(payloadSize);
        //Debug.Log(rawBytes.Length);
        //sensorDataLength = (int)(payloadSize - 2) / 4; //buttonState,checksum bytes
        //Debug.Log(sensorDataLength);
        if ( rawBytes.Length < payloadSize)
        {
            //Debug.Log("working");
            return;
        }
        try
        {
            previousButtonState = currentButtonState;
            currentTime = plTime;
            for (int i = 0; i < sensorDataLength; i++)
            {  
               //10 float values
                currentSensorData[i] = BitConverter.ToSingle (
                                            new byte[] { rawBytes[(i * 4) + 1],
                                                         rawBytes[(i * 4) + 2],
                                                         rawBytes[(i * 4) + 3],
                                                         rawBytes[(i * 4) + 4]
                                            }
                                            
                );
                
            }
            currentButtonState = rawBytes[payloadSize - 1];
            //// Check if the button has been released.
            if (previousButtonState == 0 && currentButtonState == 1)
            {
                OnButtonReleased?.Invoke();
            }

        }
        catch (Exception ex)
        {
            Debug.LogError($"Error in parseRawBytes: {ex.Message}");
        }
      
    }
    static public void computeShouderPosition()
    {
           
            theta1 = OFFSET[AppData.Instance.userData.useHand] * angleOne;
            theta2 = OFFSET[AppData.Instance.userData.useHand] * angleTwo;
            theta3 = OFFSET[AppData.Instance.userData.useHand] * angleThree;
            theta4 = OFFSET[AppData.Instance.userData.useHand] * angleFour;

            zvec[0] = Mathf.Cos(theta1) * Mathf.Cos(theta2 + theta3 + theta4);
            zvec[1] = Mathf.Sin(theta1) * Mathf.Cos(theta2 + theta3 + theta4);
            zvec[2] = -Mathf.Sin(theta2 + theta3 + theta4);

            endPt[0] = Mathf.Cos(theta1) * (len1 * Mathf.Cos(theta2) + len2 * Mathf.Cos(theta2 + theta3));
            endPt[1] = Mathf.Sin(theta1) * (len1 * Mathf.Cos(theta2) + len2 * Mathf.Cos(theta2 + theta3));
            endPt[2] = -len1 * Mathf.Sin(theta2) - len2 * Mathf.Sin(theta2 + theta3);

            if (calibrationSceneHandler.calibrationState>0) 
            {
              shPos = new float[] { endPt[0], endPt[1] + AppData.Instance.userData.uaLength, endPt[2] - AppData.Instance.userData.faLength};
            }
            
            elPt[0] = endPt[0] - AppData.Instance.userData.faLength * zvec[0];
            elPt[1] = endPt[1] - AppData.Instance.userData.faLength * zvec[1];
            elPt[2] = endPt[2] - AppData.Instance.userData.faLength * zvec[2];

            fA[0] = endPt[0] - elPt[0];
            fA[1] = endPt[1] - elPt[1];
            fA[2] = endPt[2] - elPt[2];

            uA[0] = elPt[0] - shPos[0];
            uA[1] = elPt[1] - shPos[1];
            uA[2] = elPt[2] - shPos[2];

            if (Mathf.Abs((fA[0] * uA[0] + fA[1] * uA[1] + fA[2] * uA[2]) / (AppData.Instance.userData.faLength * AppData.Instance.userData.uaLength)) > 0.9999999f)
            {
                elF = 0;
            }
            else
            {
                elF = Mathf.Acos((fA[0] * uA[0] + fA[1] * uA[1] + fA[2] * uA[2]) / (AppData.Instance.userData.faLength * AppData.Instance.userData.uaLength));
            }
            shF = Mathf.Atan2(endPt[1], endPt[0]);

            if (Mathf.Abs(uA[2] / AppData.Instance.userData.uaLength) < 1)
            {
                shA = Mathf.Asin(uA[2] / AppData.Instance.userData.uaLength);
            }
        
    }

    //To control the motor manually hold and release 
    static public void onclickHold()
    {
        AppLogger.LogInfo($"motor on hold");
        controlStatus = CONTROL_STATUS_CODE[0];
        thetades1 = MarsComm.angleOne;
        AppData.dataSendToRobot = new float[] { 0, thetades1, 0, controlStatus };
        AppData.sendToRobot(AppData.dataSendToRobot);

        Debug.Log("Hold enabled");
    }
    static public void onclickRealease()
    {
        AppLogger.LogInfo($"motor on released");
        controlStatus = CONTROL_STATUS_CODE[1];
        AppData.dataSendToRobot = AppData.dataSendToRobot = new float[] { 0.0f, 0.0f, 0.0f, controlStatus };
        AppData.sendToRobot(AppData.dataSendToRobot);

    }
   

}
 public static class MarsComLogger
    {
        private static string logFilePath;
        private static StreamWriter logWriter = null;
        private static readonly object logLock = new object();

        public static bool DEBUG = false;
        public static string InBraces(string text) => $"[{text}]";

        public static bool isLogging
        {
            get
            {
                return logFilePath != null;
            }
        }

        public static void StartLogging(string dtstr)
        {
            // Start Log file only if we are not already logging.
            if (isLogging) return;
            if (!Directory.Exists(DataManager.logPath)) Directory.CreateDirectory(DataManager.logPath);
            // Create the log file name.
            logFilePath = Path.Combine(DataManager.logPath, $"{dtstr}-marscomm.log");

            // Create the log file writer.
            logWriter = new StreamWriter(logFilePath, true);
            LogInfo("Created PLUTO log file.");
        }

        public static void StopLogging()
        {
            if (logWriter != null)
            {
                LogInfo("Closing log file.");
                logWriter.Close();
                logWriter = null;
                logFilePath = null;
            }
        }

        public static void LogMessage(string message, LogMessageType logMsgType)
        {
            lock (logLock)
            {
                if (logWriter != null)
                {
                    string _user = AppData.Instance.userData != null ? AppData.Instance.userData.hospNumber : "";
                    string _msg = $"{DateTime.Now:dd-MM-yyyy HH:mm:ss} {logMsgType,-7} {InBraces(_user),-10} {InBraces(AppLogger.currentScene),-12} {InBraces(AppLogger.currentMechanism),-8} {InBraces(AppLogger.currentGame),-8} >> {message}";
                    logWriter.WriteLine(_msg);
                    logWriter.Flush();
                    if (DEBUG) Debug.Log(_msg);
                }
            }
        }

        public static void LogInfo(string message)
        {
            LogMessage(message, LogMessageType.INFO);
        }

        public static void LogWarning(string message)
        {
            LogMessage(message, LogMessageType.WARNING);
        }

        public static void LogError(string message)
        {
            LogMessage(message, LogMessageType.ERROR);
        }
    }