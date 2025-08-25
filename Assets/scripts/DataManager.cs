using System;
using System.Linq;
using System.IO;
using System.Data;
using UnityEngine;
using System.Text;

/*
 * Summary Data Class
 */
public struct DaySummary
{
    public string Day { get; set; }
    public string Date { get; set; }
    public float MoveTime { get; set; }
}
public class DataManager : MonoBehaviour
{
    public static readonly string userIdPath =
       AppData.Instance.userID != null
       ? Path.Combine(Application.dataPath, "data", AppData.Instance.userID)
       : Application.dataPath;

    public static string basePath = FixPath(Path.Combine(userIdPath, "data"));

   
    public static readonly string directoryPath = Application.dataPath + "/data";

   
    static string dirPathRawData;
    public static string dirPathROMData;
    public static string sessionDirPath { get; private set; }
    public static string configFilePath {  get; private set; }
    public static string sessionFilePath { get; private set; }
    public static string assessFilePath { get; private set; }
    public static string logDirPath { get; private set; }
    public static string logPath { get; private set; }
    public static string dynLimParaFilePath { get; private set; }

    public static string filePathUploadStatus = Application.dataPath + "/uploadStatus.txt";

  
    public static string[] SESSIONFILEHEADER = new string[] {
        "SessionNumber", "DateTime",
        "TrialNumberDay", "TrialNumberSession", "TrialType", "TrialStartTime", "TrialStopTime", "TrialRawDataFile",
        "Movement",
        "GameName", "GameParameter", "GameSpeed",
        "AssistMode", "DesiredSuccessRate", "SuccessRate","","","MoveTime"
    };
    // Raw data header.
    public static string[] RAWFILEHEADER = new string[]
    {
        "DeviceRunTime", "PacketNumber", "Status", "ErrorString",
        "Limb", "Calibration", "LimbKinParam", "limbDynParam",
        "Target", "Desired", "Control",
        "Angle1", "Angle2", "Angle3", "Angle4",
        "ImuAngle1", "ImuAngle2", "ImuAngle3","ImuAngle4",
        "Force", "Torque",
        "EndPointX", "EndPointY", "EndPointZ",
        "Phi1", "Phi2", "Phi3",
        "GamePlayerX", "GamePlayerY", "GameTargetX", "GameTargetY", "GameState"

    };
   
    public static string[] RAWFILEHEADER_ = new string[] {
        "angle1","angle2","angle3","angle4","playerx","playery","targetx,targety","gamestate"
    };
    public static string DATETIMEFORMAT = "yyyy-MM-dd HH:mm:ss";

    public static string GetRomFileName(string Movement, string Mode) => FixPath(Path.Combine(dirPathROMData, $"{Movement}-{Mode}-rom.csv"));
    public static string GetTrialRawDataFileName(
        int sessNo,
        int trialNo,
        string game,
        string movement) => FixPath(Path.Combine(dirPathRawData, $"raw-sess{sessNo:D2}-trial{trialNo:D3}-{game}-{movement}.csv"));
    public static void createFileStructure()
    {
        dirPathROMData = basePath + "/rom";
        sessionDirPath = basePath + "/sessions";
        dirPathRawData = basePath + "/rawdata";
        logPath = basePath + "/applog";
        dynLimParaFilePath = FixPath(Path.Combine(dirPathROMData, "DYNLIMPARAM.csv"));
        sessionFilePath = FixPath(Path.Combine(sessionDirPath, "sessions.csv"));
        assessFilePath = dirPathROMData + "/assessment.csv";
        Directory.CreateDirectory(basePath);
        Directory.CreateDirectory(sessionDirPath);
        Directory.CreateDirectory(dirPathRawData);
        Directory.CreateDirectory(dirPathROMData);
        Debug.Log("Directory created at: " + basePath);
        
    }

    public static string FixPath(string path) => path.Replace("\\", "/");

    public static void setUserId(string userID)
    {
        basePath = FixPath(Path.Combine(Application.dataPath, "data", AppData.Instance.userID, "data"));
        configFilePath = basePath + "/configdata.csv";
    }

    public static void CreateSessionFile(string device, string location, string[] header = null)
    {

        // Ensure the Sessions.csv file has headers if it doesn't exist
        if (!File.Exists(sessionFilePath))
        {
            header ??= SESSIONFILEHEADER;
            using (var writer = new StreamWriter(sessionFilePath, false, Encoding.UTF8))
            {
                // Write the preheader details
                writer.WriteLine($":Device: {device}");
                writer.WriteLine($":Location: {location}");
                writer.WriteLine(String.Join(",", header));
            }
            AppLogger.LogWarning("Sessions.csv file not founds. Created one.");
        }
    }
    public static DataTable loadCSV(string filePath)
    {
        if (!File.Exists(filePath))
        {
            return null;
        }
        DataTable dTable = new DataTable();
        var lines = File.ReadAllLines(filePath);
        if (lines.Length == 0) return null;

        // Ignore all preheaders that start with ':'
        int i = 0;
        while (lines[i].StartsWith(":")) i++;
        // Only preheader lines are present
        if (i >= lines.Length) return null;
        lines = lines.Skip(i).ToArray();
        // Nothing to read
        if (lines.Length == 0) return null;

        // Read and parse the header line
        var headers = lines[0].Split(',');
        foreach (var header in headers)
        {
            dTable.Columns.Add(header);
        }

        // Read the rest of the data lines
        for (i = 1; i < lines.Length; i++)
        {
            var row = dTable.NewRow();
            var fields = lines[i].Split(',');
            for (int j = 0; j < headers.Length; j++)
            {
                row[j] = fields[j];
            }
            dTable.Rows.Add(row);
        }
        return dTable;
    }
  
}




// Start is called before the first frame update
public enum LogMessageType
 {
        INFO,
        WARNING,
        ERROR
 }
public static class AppLogger
{
    private static string logFilePath;
    private static StreamWriter logWriter = null;
    private static readonly object logLock = new object();
    public static string currentScene { get; private set; } = "";
    public static string currentMechanism { get; private set; } = "";
    public static string currentGame { get; private set; } = "";

    public static bool DEBUG = true;
    public static string InBraces(string text) => $"[{text}]";

    public static bool isLogging
    {
        get
        {
            return logFilePath != null;
        }
    }

    public static string StartLogging(string scene)
    {
        // Start Log file only if we are not already logging.
        if (isLogging)
        {
            return null;
        }
        if (!Directory.Exists(DataManager.logPath))
        {
            Directory.CreateDirectory(DataManager.logPath);
        }
        string _dtstr = DateTime.Now.ToString("dd-MM-yyyy-HH-mm-ss");
        logFilePath = Path.Combine(DataManager.logPath, $"{_dtstr}-application.log");
      
        // Create the log file and write the header.
        logWriter = new StreamWriter(logFilePath, true, Encoding.UTF8);
        currentScene = scene;
        LogInfo("Created MARS log file.");
        return _dtstr;
    }

    public static void SetCurrentScene(string scene)
    {
        if (isLogging)
        {
            currentScene = scene;
            LogInfo($"Scene set to '{currentScene}'.");
        }
    }

    public static void SetCurrentMovement(string mechanism)
    {
        Debug.Log(mechanism);
        if (isLogging)
        {
            currentMechanism = mechanism;
            LogInfo($"Mars movement set to '{currentMechanism}'.");
        }
    }

    public static void SetCurrentGame(string game)
    {
        if (isLogging)
        {
            currentGame = game;
            LogInfo($"PLUTO game set to '{currentGame}'.");
        }
    }

    public static void StopLogging()
    {
        if (logWriter != null)
        {
            LogInfo("Closing log file.");
            logWriter.Close();
            logWriter = null;
            logFilePath = null;
            currentScene = "";
        }
    }

    public static void LogMessage(string message, LogMessageType logMsgType)
    {
        lock (logLock)
        {
            if (logWriter != null)
            {
                string _user = AppData.Instance.userData != null ? AppData.Instance.userData.hospNumber : "";
                string _msg = $"{DateTime.Now:dd-MM-yyyy HH:mm:ss} {logMsgType,-7} {InBraces(_user),-10} {InBraces(currentScene),-12} {InBraces(currentMechanism),-8} {InBraces(currentGame),-8} >> {message}";
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
