
using System.Text;

using System.IO;
using System;


using Debug = UnityEngine.Debug;

using System.Data;
using System.Globalization;
using UnityEngine;

public partial class AppData
{

    private static readonly Lazy<AppData> _instance = new Lazy<AppData>(() => new AppData());

    public static AppData Instance => _instance.Value;


    static public readonly string comPort = "COM15";

    /*
   * SESSION DETAILS
   */
    public int currentSessionNumber { get; set; }
    public DateTime startTime { get; private set; }
    public DateTime? stopTime { get; private set; }
    public DateTime trialStartTime { get; set; }
    public DateTime? trialStopTime { get; set; }

    public string selectedGame { get; private set; } = null;
    static public string trialDataFileLocation;

    /*
    * Logging file names.
    */
    public string trialRawDataFile { get; private set; } = null;
    private StringBuilder rawDataString = null;
    private readonly object rawDataLock = new object();
    private StringBuilder aanExecDataString = null;

    public string userID { get; private set; } = null;

   
    

    /* DO OBJECT CREATION HERE */
    public MarsMovement selectedMovement {  get; private set; }

    public marsUserData userData;

    /* MOVE TO ANOTHER FILE*/
    //need to change
    public static string[] selectGame = { "FlappyGame", "space_shooter_home", "pong_menu" };
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
        

        // Intialize the Mars AAN logger.
        //MarsLogger.StartLogging(_dtstr);

        // Initialize the user data.
        UnityEngine.Debug.Log(DataManager.filePathforConfig);
        UnityEngine.Debug.Log(DataManager.filePathSessionData);

        userData = new marsUserData(DataManager.filePathforConfig, DataManager.filePathSessionData);
        // Selected mechanism and game.
        selectedMovement = null;
        selectedGame = null;

        // Get current session number.
        currentSessionNumber = userData.dTableSession.Rows.Count > 0 ?
            Convert.ToInt32(userData.dTableSession.Rows[userData.dTableSession.Rows.Count - 1]["SessionNumber"]) + 1 : 1;
        AppLogger.LogWarning($"Session number set to {currentSessionNumber}.");

        //set to upload the data to the AWS
        // awsManager.changeUploadStatus(awsManager.status[0]);
    }


    //waiting for MarsComm
    private void InitializeRobotConnection(bool doNotResetMov, string datetimestr = null)
    {
        //Initialize the MARS Comm logger.
        if (datetimestr != null)
        {
            MarsComLogger.StartLogging(datetimestr);
        }

        if (!ConnectToRobot.isMARS)
        {
            ConnectToRobot.Connect(comPort);
        }
        //// Check if the connection is successful.
        if (!ConnectToRobot.isConnected)
        {
            AppLogger.LogError($"Failed to connect to MARS @ {comPort}.");
            throw new Exception($"Failed to connect to MARS @ {comPort}.");
        }
        AppLogger.LogInfo($"Connected to PLUTO @ {comPort}.");
        //// Set control to NONE, calibrate and get version.
        //PlutoComm.sendHeartbeat();
        //PlutoComm.setControlType("NONE");

        // The following code is to ensure that this can be called from other scenes,
        // without having to go through the calibration scene.
        if (!doNotResetMov)
        {
            //PlutoComm.calibrate("NOMECH");
        }
        //PlutoComm.getVersion();
        // Start sensorstream.
        //PlutoComm.sendHeartbeat();
        //PlutoComm.setDiagnosticMode();
        // PlutoComm.startSensorStream();
        AppLogger.LogInfo($"PLUTO SensorStream started.");
    }
    public void InitializeRobotDiagnostics()
    {
        //DataManager.createFileStructure();
        ConnectToRobot.Connect(comPort);

        //userData = new marsUserData(DataManager.filePathforConfig, DataManager.filePathSessionData);

    }
    public static void sendToRobot(float[] data)
    {
        byte[] _data = new byte[16];
        Buffer.BlockCopy(data, 0, _data, 0, _data.Length);
        Debug.Log(_data.Length + "length");
        JediComm.SendMessage(_data);
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

    public static class Miscellaneous
    {
        public static string GetAbbreviatedDayName(DayOfWeek dayOfWeek)
        {
            return dayOfWeek.ToString().Substring(0, 3);
        }
    }
   

}

public static class gameData
{
    //game
    public static bool isGameLogging;
    public static string game;
    public static int gameScore;
    public static int reps;
    public static int playerScore;
    public static int enemyScore;
    public static string TargetPos = "0";
    public static string playerPos = "0";
    public static string enemyPos = "0";
    public static string playerHit = "0";
    public static string enemyHit = "0";
    public static string wallBounce = "0";
    public static string enemyFail = "0";
    public static string playerFail = "0";
    public static int winningScore = 3;
    public static float moveTime;
    public static readonly string[] instructions = new string[] { "1 - moving,2 - collidedWithcolumn,3 - Passedsuccessfully\n", "1 - moving,2 - AstroidHit,3 - playerHit\n", "1 - moving,2 - enemyHit,3 - playerHit\n" };
    public static int events ;
 
    private static DataLogger dataLog;
    private static string[] gameHeader = new string[] {
        "time","buttonState","angle1","angle2","angle3","angle4","force1","force2","des1","des2","des3"
        ,"playerPos","events","playerScore"
    };
    public static bool isLogging { get; private set; }
    static public void StartDataLog(string fname)
    {
        if (dataLog != null)
        {
            StopLogging();
            Debug.Log("datalognull");
        }
        // Start new logger
        if (fname != "")
        {
            //string instructionLine = instructions[Array.IndexOf(AppData.selectGame,AppData.selectedGame)];
            //string headerWithInstructions = instructionLine + String.Join(", ", gameHeader) + "\n";
            //dataLog = new DataLogger(fname, headerWithInstructions);
            isLogging = true;
            Debug.Log("logging file name is notempty");
        }
        else
        {
            Debug.Log("file name is empty");
            dataLog = null;
            isLogging = false;
        }
    }
    static public void StopLogging()
    {
        if (dataLog != null)
        {
            Debug.Log("Null log not");
            dataLog.stopDataLog(true);
            dataLog = null;
            isLogging = false;
        }
        else
            Debug.Log("Null log");
    }

    static public void LogData()
    {
            string[] _data = new string[] {
               MarsComm.currentTime.ToString(),
               MarsComm.buttonState.ToString(),
               MarsComm.angle1.ToString("G17"),
               MarsComm.angle2.ToString("G17"),
               MarsComm.angle3.ToString("G17"),
               MarsComm.angle4.ToString("G17"),
               MarsComm.force.ToString("G17"),
               MarsComm.calibBtnState.ToString("G17"),
               MarsComm.desOne.ToString("G17"),
               MarsComm.desTwo.ToString("G17"),
               MarsComm.desThree.ToString("G17"),
               playerPos,
               gameData.events.ToString("F2"),
               gameData.playerScore.ToString("F2"),
              
            };
            string _dstring = String.Join(", ", _data);
            _dstring += "\n";
            
            dataLog.logData(_dstring);
        
        Debug.Log("workign data log");
        
    }
}
public class DataLogger
{
    public string currFileName { get; private set; }
    public StringBuilder fileData;
    public bool stillLogging
    {
        get { return (fileData != null); }
    }

    public DataLogger(string filename, string header)
    {
        currFileName = filename;

        fileData = new StringBuilder(header);
    }

    public void stopDataLog(bool log = true)
    {
        if (log)
        {
            File.AppendAllText(currFileName, fileData.ToString());
        }
        currFileName = "";
        fileData = null;
    }

    public void logData(string data)
    {
        if (fileData != null)
        {
            fileData.Append(data);
        }
    }
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



