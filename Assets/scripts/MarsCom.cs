using UnityEngine;
using System.IO;
//using System.IO.Ports;
using System;
using System.ComponentModel;
using System.Text;


public static class MarsComm
{
    // For error logging
    // Thread-safe version using lock
    private static readonly System.Random _random = new System.Random();
    private static readonly object _lock = new object();

    private static int GetRandomNumber()
    {
        lock (_lock)
        {
            return _random.Next(1, 101);
        }
    }

    // Device Level Constants
    public static readonly string[] OUTDATATYPE = new string[] { "SENSORSTREAM", "CONTROLPARAM", "DIAGNOSTICS", "VERSION" };
    public static readonly string[] LIMBTYPE = new string[] { "NOLIMB", "RIGHT", "LEFT" };
    public static readonly string[] LIMBTEXT = new string[] {
        "No Limb",
        "Right",
        "Left"
    };
    public static readonly string[] CALIBRATION = new string[] { "NOCALIB", "YESCALIB" };
    public static readonly string[] CONTROLTYPE = new string[] { "NONE", "POSITION", "TORQUE", "ARM_WEIGHT_SUPPORT" };
    public static readonly string[] CONTROLTYPETEXT = new string[] {
        "None",
        "Position",
        "Torque",
        "Arm Weight Support"
    };
    public static readonly int[] SENSORNUMBER = new int[] {
        5,  // SENSORSTREAM 
        0,  // CONTROLPARAM
        5   // DIAGNOSTICS
    };
    public static readonly double MAXTORQUE = 1.0; // Nm
    public static readonly int[] INDATATYPECODES = new int[] { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x80 };
    public static readonly string[] INDATATYPE = new string[] {
        "GET_VERSION",
        "RESET_PACKETNO",
        "SET_LIMB",
        "CALIBRATE",
        "START_STREAM",
        "STOP_STREAM",
        "SET_CONTROL_TYPE",
        "SET_CONTROL_TARGET",
        "SET_DIAGNOSTICS",
        "HEARTBEAT",
    };
    public static readonly string[] ERRORTYPES = new string[] {
        "ANGSENSERR",
        "MCURRSENSERR",
        "NOHEARTBEAT"
    };
    public static readonly int INVALID_TARGET = 999;

    // Human Limb Parameter Constants
    public static readonly float MIN_UA_LENGTH = 200.0f; // millimeters
    public static readonly float MAX_UA_LENGTH = 400.0f; // millimeters
    public static readonly float MIN_FA_LENGTH = 200.0f; // millimeters
    public static readonly float MAX_FA_LENGTH = 500.0f; // millimeters
    public static readonly float MIN_UA_WEIGHT = 1.0f; // Kg
    public static readonly float MAX_UA_WEIGHT = 5.0f; // Kg
    public static readonly float MIN_FA_WEIGHT = 1.0f; // Kg
    public static readonly float MAX_FA_WEIGHT = 5.0f; // Kg
    public static readonly float MIN_SHLDR_Z_POS = 100.0f; // millimeters
    public static readonly float MAX_SHLDR_Z_POS = 400.0f; // millimeters

    static public byte currentButtonState, previousButtonState;
    static int sensorDataLength;

    // Button released event.
    public delegate void MarsButtonReleasedEvent();
    public static event MarsButtonReleasedEvent OnMarsButtonReleased;
    public delegate void CalibButtonReleasedEvent();
    public static event CalibButtonReleasedEvent OnCalibButtonReleased;
    // New data event.
    public delegate void MarsNewDataEvent();
    public static event MarsNewDataEvent OnNewMarsData;


    // MARS Robot Parameters
    private const float L1 = 475.0f;
    private const float L2 = 291.0f;
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


    // Private variables
    static private byte[] rawBytes = new byte[256];
    // For the following arrays, the first element represents the number of elements in the array.
    static private int[] previousStateData = new int[32];
    static private int[] currentStateData = new int[32];
    static private float[] currentSensorData = new float[10];

    // Public variables
    static public DateTime previousTime { get; private set; }
    static public DateTime currentTime { get; private set; }

    static public double frameRate { get; private set; }
    static public String deviceId { get; private set; }
    static public String version { get; private set; }
    static public String compileDate { get; private set; }
    static public ushort packetNumber { get; private set; }
    static public float runTime { get; private set; }
    static public float prevRunTime { get; private set; }
    public static int GetMarsCodeFromLabel(string[] array, string value)
    {
        return Array.IndexOf(array, value) - 1;
    }
    static public int status
    {
        get
        {
            return currentStateData[1];
        }
    }
    static public int dataType
    {
        get => status >> 4;

    }
    static private int prevErrorStatus = 0;
    static public int errorStatus
    {
        get
        {
            return currentStateData[2];
        }
    }
    static public string errorString
    {
        get => getErrorString(errorStatus);
    }
    static public int controlType
    {
        get
        {
            return getControlType(status);
        }
    }
    static public int calibration
    {
        get
        {
            return status & 0x01;
        }
    }

    static public int limb

    {
        get => currentStateData[3] & 0x0F;
    }
    static public int marButton
    {

        get => (currentStateData[3] >> 4) & 0x01;

    }
    static public int calibButton
    {
        get => (currentStateData[3] >> 5) & 0x01;
    }
    static public float angle1
    {
        get => currentSensorData[1];
    }
    static public float angle2
    {
        get => currentSensorData[2];
    }
    static public float angle3
    {
        get => currentSensorData[3];
    }
    static public float angle4
    {
        get => currentSensorData[4];
    }
    static public float force
    {
        get => currentSensorData[5];
    }
    static public float uaLengthByte
    {
        get => currentStateData[4];
    }
    static public float uaLength
    {
        get => decodeUpperArmLength((byte)currentStateData[4]);
    }
    static public float faLengthByte
    {
        get => currentStateData[5];
    }
    static public float faLength
    {
        get => decodeForeArmLength((byte)currentStateData[5]);
    }
    static public float uaWeightByte
    {
        get => currentStateData[6];
    }
    static public float uaWeight
    {
        get => decodeUpperArmWeight((byte)currentStateData[6]);
    }
    static public float faWeightByte
    {
        get => currentStateData[7];
    }
    static public float faWeight
    {
        get => decodeForeArmWeight((byte)currentStateData[7]);
    }
    static public float shPosZByte
    {
        get => currentStateData[10];
    }
    static public float shPosZ
    {
        get => decodeShoulderPosZ((byte)currentStateData[8]);
    }
    static public short imu1Angle
    {
        get => (sbyte)currentStateData[9];
    }
    static public short imu2Angle
    {
        get => (sbyte)currentStateData[10];
    }
    static public short imu3Angle
    {
        get => (sbyte)currentStateData[11];
    }
    static public short imu4Angle
    {
        get => (sbyte)currentStateData[12];
    }
    static public byte buttonState
    {
        get
        {
            return currentButtonState;
        }
    }


    private static int getControlType(int statusByte)

    {
        return (statusByte & 0x0E) >> 1;
    }

    private static string getErrorString(int err)
    {
        if (err == 0) return "NOERROR";
        string _str = "";
        for (int i = 0; i < 16; i++)
        {
            if ((errorStatus & (1 << i)) != 0)
            {
                _str += (_str != "") ? " | " : "";
                _str += ERRORTYPES[i];
            }
        }
        return _str;
    }

    public static void parseByteArray(byte[] payloadBytes, int payloadCount, DateTime payloadTime)
    {

        Debug.Log("adsgasdg");
        if (payloadCount == 0)
        {
            return;
        }
        Array.Copy(currentStateData, previousStateData, currentStateData.Length);
        rawBytes = payloadBytes;
        previousTime = currentTime;
        currentTime = payloadTime;
        prevRunTime = runTime;

        // Updat current state data
        // Status
        currentStateData[1] = rawBytes[1];
        // Error
        prevErrorStatus = errorStatus;
        currentStateData[2] = 255 * rawBytes[3] + rawBytes[2];
        // Check if the error is not 0.
        if (errorStatus != 0)
        {
            // Print when error changes. If error is the same, then flip a coin to decide if we print or not.
            // This is to avoid flooding the log with the same error message. 
            // if (prevErrorStatus != errorStatus || GetRandomNumber() <= 5) MarsCommLogger.LogError($"Error: {errorString} ({errorStatus}) | Time: {runTime:F2}");
        }
        else
        {
            // Print if the error is resolved.
            // if (prevErrorStatus != errorStatus) MarsCommLogger.LogInfo($"Error Resolved: {errorString} | Previous Error: {getErrorString(prevErrorStatus)}({prevErrorStatus}) | Time: {runTime:F2}");
        }
        // Limb type
        currentStateData[3] = rawBytes[4];

        // Handle data based on what type of data it is.
        byte _datatype = (byte)(currentStateData[1] >> 4);
        switch (OUTDATATYPE[_datatype])
        {
            case "SENSORSTREAM":
            case "DIAGNOSTICS":
                // Get the packet number.
                packetNumber = BitConverter.ToUInt16(new byte[] { rawBytes[5], rawBytes[6] });

                // Get the runtime.
                runTime = 0.001f * BitConverter.ToUInt32(new byte[] { rawBytes[7], rawBytes[8], rawBytes[9], rawBytes[10] });

                // Update current sensor data
                int offset = 10;
                int nSensors = SENSORNUMBER[_datatype];
                currentSensorData[0] = nSensors;
                for (int i = 0; i < nSensors; i++)
                {
                    currentSensorData[i + 1] = BitConverter.ToSingle(
                        new byte[] {
                            rawBytes[offset + 1 + (i * 4)],
                            rawBytes[offset + 2 + (i * 4)],
                            rawBytes[offset + 3 + (i * 4)],
                            rawBytes[offset + 4 + (i * 4)] },
                        0
                    );
                }

                // Human limb parameters
                // Upper arm length
                currentStateData[4] = rawBytes[(nSensors + 1) * 4 + 6 + 1];
                // Forearm length
                currentStateData[5] = rawBytes[(nSensors + 1) * 4 + 6 + 2];
                // Upper arm weight
                currentStateData[6] = rawBytes[(nSensors + 1) * 4 + 6 + 3];
                // Forearm weight
                currentStateData[7] = rawBytes[(nSensors + 1) * 4 + 6 + 4];
                // // Shoulder position X
                // currentStateData[8] = rawBytes[(nSensors + 1) * 4 + 6 + 5];
                // // Shoulder position Y
                // currentStateData[9] = rawBytes[(nSensors + 1) * 4 + 6 + 6];
                // Shoulder position Z
                currentStateData[8] = rawBytes[(nSensors + 1) * 4 + 6 + 5];

                // IMU angles
                currentStateData[9] = rawBytes[(nSensors + 1) * 4 + 6 + 6];
                currentStateData[10] = rawBytes[(nSensors + 1) * 4 + 6 + 7];
                currentStateData[11] = rawBytes[(nSensors + 1) * 4 + 6 + 8];
                currentStateData[12] = rawBytes[(nSensors + 1) * 4 + 6 + 9];

                // MARS button
                currentStateData[13] = rawBytes[(nSensors + 1) * 4 + 6 + 10];
                // Calib button
                currentStateData[14] = rawBytes[(nSensors + 1) * 4 + 6 + 11];

                // Number of current state data
                currentStateData[0] = 3;

                // Updat framerate
                frameRate = 1 / (runTime - prevRunTime);

                // Check if the MARS button has been released.
                if (previousStateData[15] == 0 && currentStateData[15] == 1)
                {
                    // MarsCommLogger.LogInfo($"Pluto Button Released | Button: {currentStateData[6]} | Time: {runTime:F2}");
                    OnMarsButtonReleased?.Invoke();
                }

                // Check if the Calib button has been released.
                if (previousStateData[16] == 0 && currentStateData[16] == 1)
                {
                    // MarsCommLogger.LogInfo($"Pluto Button Released | Button: {currentStateData[6]} | Time: {runTime:F2}");
                    OnCalibButtonReleased?.Invoke();
                }

                // Check if the control mode has been changed.
                // if (getControlType(previousStateData[1]) != getControlType(currentStateData[1]))
                // {
                //     MarsCommLogger.LogInfo($"Control Mode Changed | ControlType: {getControlType(currentStateData[1])} | Time: {runTime:F2}");
                //     OnControlModeChange?.Invoke();
                // }

                // Check if the mechanism has been changed.
                // if ((previousStateData[3] >> 4) != (currentStateData[3] >> 4))
                // {
                //     MarsCommLogger.LogInfo($"Mechanism Changed | Mechanism: {currentStateData[3] >> 4} | Time: {runTime:F2}");
                //     OnMechanismChange?.Invoke();
                // }

                // Invoke the new data event only for SENSORSTREAM or DIAGNOSTICS data.
                OnNewMarsData?.Invoke();
                break;
            case "VERSION":
                // Read the bytes into a string.
                deviceId = Encoding.ASCII.GetString(rawBytes, 5, rawBytes[0] - 4 - 1).Split(",")[0];
                version = Encoding.ASCII.GetString(rawBytes, 5, rawBytes[0] - 4 - 1).Split(",")[1];
                compileDate = Encoding.ASCII.GetString(rawBytes, 5, rawBytes[0] - 4 - 1).Split(",")[2];
                MarsCommLogger.LogInfo($"Received Version | Version: {version} | Compile Date: {compileDate} | Device ID: {deviceId}");
                break;
        }
    }
    // static public void parseRawBytes(byte[] rawBytes, uint payloadSize ,DateTime plTime)
    // {
    //     Debug.Log(payloadSize);
    //     //Debug.Log(rawBytes.Length);
    //     sensorDataLength = (int)(payloadSize - 2) / 4; //buttonState,checksum bytes
    //     Debug.Log(sensorDataLength);
    //     if ( rawBytes.Length < payloadSize)
    //     {
    //         //Debug.Log("working");
    //         return;
    //     }
    //     try
    //     {
    //         previousButtonState = currentButtonState;
    //         currentTime = plTime;
    //         for (int i = 0; i < sensorDataLength; i++)
    //         {  
    //            //10 float values
    //             currentSensorData[i] = BitConverter.ToSingle (
    //                                         new byte[] { rawBytes[(i * 4) + 1],
    //                                                      rawBytes[(i * 4) + 2],
    //                                                      rawBytes[(i * 4) + 3],
    //                                                      rawBytes[(i * 4) + 4]
    //                                         }

    //             );

    //         }
    //         currentButtonState = rawBytes[payloadSize - 1];
    //         //// Check if the button has been released.
    //         if (previousButtonState == 0 && currentButtonState == 1)
    //         {
    //             OnButtonReleased?.Invoke();
    //         }

    //     }
    //     catch (Exception ex)
    //     {
    //         Debug.LogError($"Error in parseRawBytes: {ex.Message}");
    //     }

    // }

    static public void computeShouderPosition()
    {

        // theta1 = OFFSET[AppData.useHand] * angleOne;
        // theta2 = OFFSET[AppData.useHand] * angleTwo;
        // theta3 = OFFSET[AppData.useHand] * angleThree;
        // theta4 = OFFSET[AppData.useHand] * angleFour;

        // zvec[0] = Mathf.Cos(theta1) * Mathf.Cos(theta2 + theta3 + theta4);
        // zvec[1] = Mathf.Sin(theta1) * Mathf.Cos(theta2 + theta3 + theta4);
        // zvec[2] = -Mathf.Sin(theta2 + theta3 + theta4);

        // endPt[0] = Mathf.Cos(theta1) * (len1 * Mathf.Cos(theta2) + len2 * Mathf.Cos(theta2 + theta3));
        // endPt[1] = Mathf.Sin(theta1) * (len1 * Mathf.Cos(theta2) + len2 * Mathf.Cos(theta2 + theta3));
        // endPt[2] = -len1 * Mathf.Sin(theta2) - len2 * Mathf.Sin(theta2 + theta3);


        // if (calibrationSceneHandler.calibrationState > 0)
        // {
        //     shPos = new float[] { endPt[0], endPt[1] + AppData.lu, endPt[2] - AppData.lf };
        // }

        // elPt[0] = endPt[0] - AppData.lf * zvec[0];
        // elPt[1] = endPt[1] - AppData.lf * zvec[1];
        // elPt[2] = endPt[2] - AppData.lf * zvec[2];

        // fA[0] = endPt[0] - elPt[0];
        // fA[1] = endPt[1] - elPt[1];
        // fA[2] = endPt[2] - elPt[2];

        // uA[0] = elPt[0] - shPos[0];
        // uA[1] = elPt[1] - shPos[1];
        // uA[2] = elPt[2] - shPos[2];

        // if (Mathf.Abs((fA[0] * uA[0] + fA[1] * uA[1] + fA[2] * uA[2]) / (AppData.lf * AppData.lu)) > 0.9999999f)
        // {
        //     elF = 0;
        // }
        // else
        // {
        //     elF = Mathf.Acos((fA[0] * uA[0] + fA[1] * uA[1] + fA[2] * uA[2]) / (AppData.lf * AppData.lu));
        // }
        // shF = Mathf.Atan2(endPt[1], endPt[0]);

        // if (Mathf.Abs(uA[2] / AppData.lu) < 1)
        // {
        //     shA = Mathf.Asin(uA[2] / AppData.lu);
        // }

    }

    // Decode human limb parameters from byte values
    public static float DecodeHumanLimbParam(byte val, float min, float max) => min + (max - min) * Mathf.Clamp(val / 255.0f, 0, 1);
    private static float decodeUpperArmLength(byte uaLengthByte) => DecodeHumanLimbParam(uaLengthByte, MIN_UA_LENGTH, MAX_UA_LENGTH);
    private static float decodeForeArmLength(byte faLengthByte) => DecodeHumanLimbParam(faLengthByte, MIN_FA_LENGTH, MAX_FA_LENGTH);
    private static float decodeUpperArmWeight(byte uaWeightByte) => DecodeHumanLimbParam(uaWeightByte, MIN_UA_WEIGHT, MAX_UA_WEIGHT);
    private static float decodeForeArmWeight(byte faWeightByte) => DecodeHumanLimbParam(faWeightByte, MIN_FA_WEIGHT, MAX_FA_WEIGHT);
    private static float decodeShoulderPosZ(byte shPosZByte) => DecodeHumanLimbParam(shPosZByte, MIN_SHLDR_Z_POS, MAX_SHLDR_Z_POS);

    // Encode human limb parameters to byte values
    public static byte EncodeHumanLimbParam(float val, float min, float max) => (byte)Mathf.Clamp((val - min) / (max - min) * 255.0f, 0, 255);
    private static byte encodeUpperArmLength(float uaLength) => EncodeHumanLimbParam(uaLength, MIN_UA_LENGTH, MAX_UA_LENGTH);
    private static byte encodeForeArmLength(float faLength) => EncodeHumanLimbParam(faLength, MIN_FA_LENGTH, MAX_FA_LENGTH);
    private static byte encodeUpperArmWeight(float uaWeight) => EncodeHumanLimbParam(uaWeight, MIN_UA_WEIGHT, MAX_UA_WEIGHT);
    private static byte encodeForeArmWeight(float faWeight) => EncodeHumanLimbParam(faWeight, MIN_FA_WEIGHT, MAX_FA_WEIGHT);
    private static byte encodeShoulderPosZ(float shPosZ) => EncodeHumanLimbParam(shPosZ, MIN_SHLDR_Z_POS, MAX_SHLDR_Z_POS);


    /*
     * Function to send data to the robot.
     */
    public static void startSensorStream()
    {
        MarsCommLogger.LogInfo("Starting Sensor Stream");
        JediComm.SendMessage(new byte[] { (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "START_STREAM")] });
    }

    public static void stopSensorStream()
    {
        MarsCommLogger.LogInfo("Stopping Sensor Stream");
        JediComm.SendMessage(new byte[] { (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "STOP_STREAM")] });
    }

    public static void setDiagnosticMode()
    {
        MarsCommLogger.LogInfo("Setting Diagnostic Mode");
        JediComm.SendMessage(new byte[] { (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "SET_DIAGNOSTICS")] });
    }

    public static void setLimb(string limb)
    {
        MarsCommLogger.LogInfo($"Setting Limb: {limb}");
        JediComm.SendMessage(
            new byte[] {
                (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "SET_LIMB")],
                (byte)Array.IndexOf(LIMBTYPE, limb)

            }
        );
    }

    public static void calibrate()
    {
        MarsCommLogger.LogInfo("Calibrating");
        JediComm.SendMessage(new byte[] { (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "CALIBRATE")] });
    }

    public static void getVersion()
    {
        MarsCommLogger.LogInfo("Getting Version");
        JediComm.SendMessage(new byte[] { (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "GET_VERSION")] });
    }
    public static void resetPacketNo()
    {
        MarsCommLogger.LogInfo($"Resetting Packet Number");
        JediComm.SendMessage(new byte[] { (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "RESET_PACKETNO")] });
    }

    public static void sendHeartbeat()
    {
        JediComm.SendMessage(new byte[] { (byte)INDATATYPECODES[Array.IndexOf(INDATATYPE, "HEARTBEAT")] });
    }

    //To control the motor manually hold and release
    static public void onclickHold()
    {
        AppLogger.LogInfo($"motor on hold");
        controlStatus = CONTROL_STATUS_CODE[0];
        thetades1 = MarsComm.angle1;
        AppData.dataSendToRobot = new float[] { 0, thetades1, 0, controlStatus };
        // AppData.sendToRobot(AppData.dataSendToRobot);

        Debug.Log("Hold enabled");
    }
    static public void onclickRealease()
    {
        AppLogger.LogInfo($"motor on released");
        controlStatus = CONTROL_STATUS_CODE[1];
        AppData.dataSendToRobot = AppData.dataSendToRobot = new float[] { 0.0f, 0.0f, 0.0f, controlStatus };
        // AppData.sendToRobot(AppData.dataSendToRobot);

    }
   

}


public static class MarsCommLogger
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
        // NEEDS CHANGE
        // if (!Directory.Exists(DataManager.logPath)) Directory.CreateDirectory(DataManager.logPath);
        // // Create the log file name.
        // logFilePath = Path.Combine(DataManager.logPath, $"{dtstr}-plutocomm.log");

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
                // NEEDS CHANGE
                // string _user = AppData.Instance.userData != null ? AppData.Instance.userData.hospNumber : "";
                // string _msg = $"{DateTime.Now:dd-MM-yyyy HH:mm:ss} {logMsgType,-7} {InBraces(_user),-10} {InBraces(AppLogger.currentScene),-12} {InBraces(AppLogger.currentMechanism),-8} {InBraces(AppLogger.currentGame),-8} >> {message}";
                // logWriter.WriteLine(_msg);
                // logWriter.Flush();
                // if (DEBUG) Debug.Log(_msg);
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

