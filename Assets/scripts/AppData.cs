
using System.Text;
using System;
using Debug = UnityEngine.Debug;
using UnityEngine;

public partial class AppData
{

    private static readonly Lazy<AppData> _instance = new Lazy<AppData>(() => new AppData());

    public static AppData Instance => _instance.Value;


    static public readonly string COMPort = "COM35";

    /*
   * SESSION DETAILS
   */
    public int currentSessionNumber { get; set; }
    public DateTime startTime { get; private set; }
    public DateTime? stopTime { get; private set; }
    public DateTime trialStartTime { get; set; }
    public DateTime? trialStopTime { get; set; }

    /*
    * Logging file names.
    */
    public string trialRawDataFile { get; private set; } = null;
    static public string trialDataFileLocation;
    private StringBuilder rawDataString = null;
    private readonly object rawDataLock = new object();
    private StringBuilder aanExecDataString = null;

    public string userID { get; private set; } = null;

    public float successRate { get; private set; } = 0f;


    /* DO OBJECT CREATION HERE */
    public string selectedGame { get; private set; } = null;

    public MarsMovement selectedMovement {  get; private set; }

    public marsUserData userData;
    public MarsTransitionControl transitionControl { get; private set; }

    
    public static float[] dataSendToRobot;  //parameters send  to robot

    public void Initialize(string scene, bool doNotResetMovement = true)
    {
        UnityEngine.Debug.Log(Application.persistentDataPath);

        // Set sesstion start time.
        startTime = DateTime.Now;

        // Create file structure.
        DataManager.createFileStructure();

        // Start logging.
        string _dtstr = AppLogger.StartLogging(scene);

        //Connect and init robot.
        InitializeRobotConnection(doNotResetMovement, _dtstr);
        

     
        // Initialize the user data.
        UnityEngine.Debug.Log(DataManager.configFilePath);
        UnityEngine.Debug.Log(DataManager.sessionFilePath);

        userData = new marsUserData(DataManager.configFilePath, DataManager.sessionFilePath);
        transitionControl = new MarsTransitionControl();
        // Selected movement and game.
        selectedMovement = null;
        selectedGame = null;

        // Get current session number.
        currentSessionNumber = userData.dTableSession.Rows.Count > 0 ?
            Convert.ToInt32(userData.dTableSession.Rows[userData.dTableSession.Rows.Count - 1]["SessionNumber"]) + 1 : 1;
        AppLogger.LogWarning($"Session number set to {currentSessionNumber}.");

        //set to upload the data to the AWS
        //awsManager.changeUploadStatus(awsManager.status[0]);
    }


    //waiting for MarsComm
    private void InitializeRobotConnection(bool doNotResetMov, string datetimestr = null)
    {
        //Initialize the MARS Comm logger.
        if (datetimestr != null)
        {
            MarsCommLogger.StartLogging(datetimestr);
        }

        if (!ConnectToRobot.isMARS)
        {
            ConnectToRobot.Connect(COMPort);
        }
        MarsComm.getVersion();
        MarsComm.startSensorStream();

        //// Check if the connection is successful.
        if (!ConnectToRobot.isConnected)
        {
            AppLogger.LogError($"Failed to connect to MARS @ {COMPort}.");
            throw new Exception($"Failed to connect to MARS @ {COMPort}.");
        }
        AppLogger.LogInfo($"Connected to MARS @ {COMPort}.");
        //// Set control to NONE, calibrate and get version.
       
        AppLogger.LogInfo($"MARS SensorStream started.");
    }
    public void InitializeRobotDiagnostics()
    {
        ConnectToRobot.Connect(COMPort);

    }

    public void setUser(string user)
    {
        userID = user;
        UnityEngine.Debug.Log($" id : {userID}");
    }
    public void SetMovement(string name)
    {
        if (string.IsNullOrEmpty(name))
        {
            selectedMovement = null;
            //aanController = null;
            AppLogger.LogInfo($"Selected movment set to null.");
            return;
        }
        // Set the mechanism name.
        selectedMovement = new MarsMovement(name: name, side: trainingSide, sessno: currentSessionNumber);
        AppLogger.LogInfo($"Selected movement '{selectedMovement.name}'.");
        AppLogger.SetCurrentMovement(selectedMovement.name);
        AppLogger.LogInfo($"Trial numbers for ' {selectedMovement.name}' updated. Day: {selectedMovement.trialNumberDay}, Session: {selectedMovement.trialNumberSession}.");
    }
    public void SetGame(string game)
    {
        selectedGame = game;
    }
   
    public string trainingSide => userData?.rightHand == true ? "RIGHT" : "LEFT";

    // Check training size.
    public bool IsTrainingSide(string side) => string.Equals(trainingSide, side, StringComparison.OrdinalIgnoreCase);

}

public static class ConnectToRobot
{
    public static string _port;
    public static bool isMARS = false;
    public static bool isConnected = false;

    public static void Connect(string port)
    {
        _port = port;
        if (_port == null)
        {
            _port = "COM13";
            JediComm.InitSerialComm(_port);
        }
        else
        {
            JediComm.InitSerialComm(_port);
        }
        if (JediComm.serPort != null)
        {
            if (JediComm.serPort.IsOpen == false)
            {
                UnityEngine.Debug.Log(_port);
                JediComm.Connect();
            }
            isConnected = JediComm.serPort.IsOpen;
        }
    }
    public static void disconnect()
    {
        ConnectToRobot.isMARS = false;
        JediComm.Disconnect();
    }
}



