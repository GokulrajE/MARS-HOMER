using System;
using System.Linq;
using System.IO;
using System.Data;
using UnityEngine;
using System.Text;
using UnityEditor.VersionControl;
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

   
    static string directoryPathRawData;
    public static string directoryAssessmentData;
    public static string directoryPathSession { get; private set; }
    public static string filePathforConfig ;
    public static string filePathSessionData { get; private set; }
    public static string filePathAssessmentData { get; private set; }
    public static string logDirPath { get; private set; }
    public static string logPath { get; private set; }


    public static string filePathUploadStatus = Application.dataPath + "/uploadStatus.txt";
    public static string SupportCalibrationFileName = "SupportCalibration.csv";
    public static string[] ROMWithSupportFileNames = new string[]
    {
      "FullWeightSupport.csv",
      "HalfWeightSupport.csv",
      "NoWeightSupport.csv"
    };
    public static string[] SESSIONFILEHEADER = new string[] {
        "SessionNumber", "DateTime",
        "TrialNumberDay", "TrialNumberSession", "TrialType", "TrialStartTime", "TrialStopTime", "TrialRawDataFile",
        "Movement",
        "GameName", "GameParameter", "GameSpeed",
        "AssistMode", "DesiredSuccessRate", "SuccessRate", "CurrentControlBound", "NextControlBound","MoveTime"
    };

    public static string DATEFORMAT = "yyyy-MM-dd HH:mm:ss";

    public static string GetRomFileName(string mechanism) => FixPath(Path.Combine(directoryAssessmentData, $"{mechanism}-rom.csv"));
    public static void createFileStructure()
    {
        directoryAssessmentData = basePath+ "/rom";
        directoryPathSession = basePath + "/sessions";
        directoryPathRawData = basePath + "/rawdata";
        logPath = basePath + "/applog";
        filePathSessionData = FixPath(Path.Combine(directoryPathSession, "sessions.csv"));
        filePathAssessmentData = directoryAssessmentData + "/assessment.csv";

     
        Directory.CreateDirectory(basePath);
        //Directory.CreateDirectory(directoryPathConfig);
        Directory.CreateDirectory(directoryPathSession);
        Directory.CreateDirectory(directoryPathRawData);
        Directory.CreateDirectory(directoryAssessmentData);
          
        //File.Create(filePathSessionData).Dispose(); // Ensure the file handle is released
        //File.Create(filePathAssessmentData).Dispose(); // Ensure the file handle is released
        Debug.Log("Directory created at: " + basePath);
        
        //writeHeader(filePathSessionData);
    }
    public static string FixPath(string path) => path.Replace("\\", "/");
    public static void setUserId(string userID)
    {
        basePath = FixPath(Path.Combine(Application.dataPath, "data", AppData.Instance.userID, "data"));
        filePathforConfig = basePath + "/configdata.csv";
    }
    public static void CreateSessionFile(string device, string location, string[] header = null)
    {

        // Ensure the Sessions.csv file has headers if it doesn't exist
        if (!File.Exists(filePathSessionData))
        {
            header ??= SESSIONFILEHEADER;
            using (var writer = new StreamWriter(filePathSessionData, false, Encoding.UTF8))
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
        // if (!File.Exists(logFilePath)) File.Create(logFilePath);

        // Create the log file and write the header.
        logWriter = new StreamWriter(logFilePath, true, Encoding.UTF8);
        currentScene = scene;
        LogInfo("Created PLUTO log file.");
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

    public static void SetCurrentMechanism(string mechanism)
    {
        Debug.Log(mechanism);
        if (isLogging)
        {
            currentMechanism = mechanism;
            LogInfo($"PLUTO mechanism set to '{currentMechanism}'.");
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
//public static class AppLogger
//{
//    public static readonly string directoryPath = Application.dataPath + "/data";
//    private static string logFilePath;
//    private static StreamWriter logWriter = null;
//    private static readonly object logLock = new object();
//    public static string currentScene { get; private set; } = "";
//    public static string currentMechanism { get; private set; } = "";
//    public static string currentGame { get; private set; } = "";
//    public static bool isLogging
//    {
//        get
//        {
//            return logFilePath != null;
//        }
//    }
//    public static void StartLogging(string scene)
//    {
//        // Start Log file only if we are not already logging.
//        if (isLogging)
//        {
//            return;
//        }

//        if (!Directory.Exists(directoryPath + "/applog"))
//        {
//            Directory.CreateDirectory(directoryPath + "/applog");
//        }

//        // Not logging right now. Create a new one.
//        logFilePath = directoryPath + $"/applog/log-{DateTime.Now:dd-MM-yyyy-HH-mm-ss}.log";
//        if (!File.Exists(logFilePath))
//        {
//            using (File.Create(logFilePath)) { }
//        }
//        logWriter = new StreamWriter(logFilePath, true);
//        currentScene = scene;
//        LogInfo("Created PLUTO log file.");
//    }

//    public static void SetCurrentScene(string scene)
//    {
//        if (isLogging)
//        {
//            currentScene = scene;
//        }
//    }

//    public static void SetCurrentMechanism(string movement)
//    {
//        if (isLogging)
//        {
//            currentMechanism = movement;
//        }
//    }

//    public static void SetCurrentGame(string game)
//    {
//        if (isLogging)
//        {
//            currentGame = game;
//        }
//    }

//    public static void StopLogging()
//    {
//        if (logWriter != null)
//        {
//            LogInfo("Closing log file.");
//            logWriter.Close();
//            logWriter = null;
//            logFilePath = null;
//            currentScene = "";
//        }
//    }

//    public static void LogMessage(string message, LogMessageType logMsgType)
//    {
//        lock (logLock)
//        {
//            if (logWriter != null)
//            {
//                logWriter.WriteLine($"{DateTime.Now:dd-MM-yyyy HH:mm:ss} {logMsgType,-7} [{currentScene}] [{currentMechanism}] [{currentGame}] {message}");
//                logWriter.Flush();
//            }
//        }
//    }

//    public static void LogInfo(string message)
//    {
//        LogMessage(message, LogMessageType.INFO);
//    }

//    public static void LogWarning(string message)
//    {
//        LogMessage(message, LogMessageType.WARNING);
//    }

//    public static void LogError(string message)
//    {
//        LogMessage(message, LogMessageType.ERROR);
//    }
//}

