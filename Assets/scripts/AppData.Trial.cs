
using System;
using System.Data;
using System.IO;
using System.Linq;
using System.Runtime.Remoting.Messaging;
using System.Text;
using UnityEngine;

/*
 * HOMER MARS Application Data Class.
 * Implements all the functions for running game trials.
 */
public partial class AppData
{
    private int _rawDataFlushCounter = 0;
    private const int RAW_DATA_FLUSH_INTERVAL = 500; // ~5 seconds at 100Hz

    // Trail Detials
    public float gameTime { get; set; } = 0;
    // public float gameSpeed { get => selectedGame.gameSpeed; }
    // Start a new trial.
    public void StartNewTrial()
    {
        trialStartTime = DateTime.Now;
        trialStopTime = null;
        selectedMovement.NextTrial();
        
        // Set the trial data files.
        StartRawDataLogging();

        // Write trial details to the log file.
        string _tdetails = string.Join(" | ",
            new string[] {
                $"Start Time: {trialStartTime:yyyy-MM-ddTHH:mm:ss}",
                $"Trial#Day: {selectedMovement.trialNumberDay}",
                $"Trial#Sess: {selectedMovement.trialNumberSession}",
                $"TrialRawDataFile: {trialRawDataFile.Split('/').Last()}"
        });
        AppLogger.LogInfo($"StartNewTrial | {_tdetails}");
    }

    public void StopTrial(int nTargets, int nSuccess, int nFailure)
    {
        trialStopTime = DateTime.Now;
        nTargets = (nTargets == 0) ? 1 : nTargets;
        successRate = Math.Clamp(100 * nSuccess / nTargets, 0, 100);

        // Update targets, hits and misses.
        selectedGame.UpdateTargetsHitsMisses(nTargets, nSuccess, nFailure);

        // Write trial information to the session details file.
        WriteTrialToSessionsFile();

        // Compute the new speed based on the current performance.
        float currReachSpeed = selectedGame.reachSpeed;
        float currGameSpeed = selectedGame.gameSpeed;
        float adaptRate = GetReachSpeedAdaptationRate(successRate, currReachSpeed);
        selectedGame.reachSpeed = adaptRate * currReachSpeed;
        
        string _tdetails = string.Join(" | ",
            new string[] {
                $"Start Time: {trialStartTime:yyyy-MM-ddTHH:mm:ss}",
                $"Stop Time: {trialStopTime:yyyy-MM-ddTHH:mm:ss}",
                $"Trial#Day: {selectedMovement.trialNumberDay}",
                $"Trial#Sess: {selectedMovement.trialNumberSession}",
                $"NTargets: {selectedGame.currentTargets}",
                $"NSuccess: {selectedGame.currentHits}",
                $"NFailure: {selectedGame.currentMisses}",
                $"Trial SR: {successRate}",
                $"CuTargets: {selectedGame.cummulativeTargets}",
                $"CuHits: {selectedGame.cummulativeHits}",
                $"CuMisses: {selectedGame.cummulativeMisses}",
                $"Current Reach Speed: {currReachSpeed}m/s",
                $"New Reach Speed: {selectedGame.reachSpeed}m/s",
                $"Current Game Speed: {currGameSpeed}",
                $"New Game Speed: {selectedGame.gameSpeed}",
                $"TrialRawDataFile: {trialRawDataFile.Split('/').Last()}"
        });
        AppLogger.LogInfo($"StopTrial | {_tdetails}");
        
        // Stop Raw and AAN real-time data logging.
        WriteTrialDataToRawDataFile();
        MarsComm.OnNewMarsData -= OnNewMarsRawDataLogging;
        trialRawDataFile = null;
        Instance.selectedGame.resetstarCount();
        awsManager.changeUploadStatus(awsManager.status[0]);
        neurodash.OnSessionEnd();
    }

    private void WriteTrialToSessionsFile()
    {
        
        // Build the trial row.
        string[] trialRow = new string[] {
            $"{currentSessionNumber}",                              // SessionNumber
            startTime.ToString(DataManager.DATETIMEFORMAT),         // DateTime
            $"{selectedMovement.trialNumberDay}",                   // TrialNumberDay
            $"{selectedMovement.trialNumberSession}",               // TrialNumberSession
            trialStartTime.ToString(DataManager.DATETIMEFORMAT),    // TrialStartTime
            trialStopTime?.ToString(DataManager.DATETIMEFORMAT),    // TrialStopTime
            trialRawDataFile.Split("/data/")[1],                    // TrialRawDataFile
            $"{selectedMovement.name}",                             // Movement
            $"{userData.trainingPlaneAngle}",                       // TrainingPlaneAngle
            $"{selectedGame.name}",                                 // Game  
            $"{selectedGame.reachSpeed}",                           // ReachSpeed
            $"{selectedGame.gameParameter}",                        // GameParameter
            $"{selectedGame.gameDuration}",                         // GameDuration
            $"{successRate}",                                       // SuccessRate
             Instance.gameTime.ToString(),                           // GameTime
            $"{selectedGame.currentTargets}",                       // CurrentTargets
            $"{selectedGame.currentHits}",                          // CurrentHits
            $"{selectedGame.currentMisses}",                        // CurrentMisses
            $"{selectedGame.cummulativeTargets}",                   // CummulativeTargets
            $"{selectedGame.cummulativeHits}",                      // CummulativeHits
            $"{selectedGame.cummulativeMisses}",                    // CummulativeMisses
            $"{selectedGame.currentStar}",                          // CurrentStarcounts
            $"{selectedGame.cummulativeStars}",                     // CummulativeStarCounts
            $"{trialRawDataFile.Split('/').Last()}"                 // RawDataFileName
        };

        // Write the trial row to the session file.
        using (StreamWriter sw = new StreamWriter(DataManager.sessionFile, true, Encoding.UTF8))
        {
            // Write the trial row to the session file.
            sw.WriteLine(string.Join(",", trialRow));
        }
    }

    public void StartRawDataLogging()
    {
        //// Set the file name.
        trialRawDataFile = DataManager.GetTrialRawDataFileName(
            currentSessionNumber,
            selectedMovement.trialNumberDay,
            Instance.selectedGame.name,
            Instance.selectedMovement.name);

        //// Initialize the string builders.
        rawDataString = new StringBuilder();
        _rawDataFlushCounter = 0;
        // Write pre-header and header information
        rawDataString.AppendLine($":Device: MARS");
        rawDataString.AppendLine($":Location: {userData.GetDeviceLocation()}");
        rawDataString.AppendLine($":User    : {userID}");
        rawDataString.AppendLine($":Movement: {selectedMovement.name}");
        rawDataString.AppendLine($":Game: {selectedGame.name}");
        rawDataString.AppendLine($":TrialType: ");
        rawDataString.AppendLine($":TrialStartTime: {trialStartTime:yyyy-MM-ddTHH:mm:ss}");
        rawDataString.AppendLine($":TrialNumberDay: {selectedMovement.trialNumberDay}");
        // Screen/Robot limits string
        float[] _screenLimits = MarsGameDefs.SCREEN_LIMITS[selectedGame.name];
        string _limitstr = string.Join(",", new string[] {
            $"{_screenLimits[0]:F6}",
            $"{_screenLimits[1]:F6}",
            $"{_screenLimits[2]:F6}",
            $"{_screenLimits[3]:F6}"
        });
        rawDataString.AppendLine($":ScreenLimits: {_limitstr}");
        _limitstr = string.Join(",", new string[] {
            $"{Instance.selectedMovement.currentArom.leftAdjusted.x:F6}",
            $"{Instance.selectedMovement.currentArom.rightAdjusted.x:F6}",
            $"{Instance.selectedMovement.currentArom.bottomAdjusted.y:F6}",
            $"{Instance.selectedMovement.currentArom.topAdjusted.y:F6}"
        });
        rawDataString.AppendLine($":RobotLimits: {_limitstr}");
        rawDataString.AppendLine(string.Join(",", DataManager.RAWFILEHEADER));
        //Make annotation empty
        AppData.Instance.annotation = "";
        // Attach the event handler for data logging.
        MarsComm.OnNewMarsData += OnNewMarsRawDataLogging;
    }
 
    public void OnNewMarsRawDataLogging()
    {
        lock (rawDataLock)
        {
            if (rawDataString == null)
            {
                Debug.LogWarning("rawDataString is null, skipping logging.");
                return;
            }
            Vector3 _playerGamePos = GetGamePlayerPosition();
            Vector3 _targetGamePos = GetGameTargetPosition();
            Vector3 _targetEndPointPos = GetEndPointTargetPosition();
            rawDataString.Append($"{MarsComm.runTime},");                           // DeviceRunTime
            rawDataString.Append($"{MarsComm.packetNumber},");                      // PacketNumber
            rawDataString.Append($"{MarsComm.status},");                            // Status
            rawDataString.Append($"{MarsComm.controlType},");                       // ControlType
            rawDataString.Append($"{MarsComm.errorStatus},");                       // ErrorStatus
            rawDataString.Append($"{MarsComm.limb},");                              // Limb
            rawDataString.Append($"{MarsComm.calibration},");                       // Calibration
            rawDataString.Append($"{MarsComm.force},");                             // Force
            rawDataString.Append($"{MarsComm.target},");                            // Target
            rawDataString.Append($"{MarsComm.desired},");                           // Desired
            rawDataString.Append($"{MarsComm.control},");                           // Control
            rawDataString.Append($"{MarsComm.buttonState},");                       // Button
            rawDataString.Append($"{MarsComm.epPos.x},");                           // EndPointX
            rawDataString.Append($"{MarsComm.epPos.y},");                           // EndPointY
            rawDataString.Append($"{MarsComm.epPos.z},");                           // EndPointZ
            rawDataString.Append($"{MarsComm.epPosInThePlane.y},");                 // EndPointYPlaneY
            rawDataString.Append($"{MarsComm.epPosInThePlane.z},");                 // EndPointZPlaneZ
            rawDataString.Append($"{_targetEndPointPos.y},");                       // EndPointTargetY
            rawDataString.Append($"{_targetEndPointPos.z},");                       // EndPointTargetZ
            rawDataString.Append($"{MarsComm.errP},");                              // Error
            rawDataString.Append($"{MarsComm.errD},");                              // ErrorDiff
            rawDataString.Append($"{MarsComm.errI},");                              // ErrorSum
            rawDataString.Append($"{_playerGamePos.x},");                           // GamePlayerX
            rawDataString.Append($"{_playerGamePos.y},");                           // GamePlayerY
            rawDataString.Append($"{_targetGamePos.x},");                           // GameTargetX
            rawDataString.Append($"{_targetGamePos.y},");                           // GameTargetY
            rawDataString.Append($"{GetGameState()},");                             // GameState
            rawDataString.Append($"{GetTargetNumber()},");                          // GameTargetNumber
            rawDataString.Append($"{GetHitNumber()},");                             // GameHitNumber
            rawDataString.Append($"{GetMissNumber()},");                            // GameMissNumber
            rawDataString.Append($"{AppData.Instance.annotation},");                // Annotation
            rawDataString.Append($"{GetMiscellaneous()},");                          // Miscellaneous //Target Reach Time only for Ping-Pong Game
            rawDataString.Append($"{MarsComm.angle1},");
            rawDataString.Append($"{MarsComm.angle2},");
            rawDataString.Append($"{MarsComm.angle3},");
            rawDataString.Append($"{MarsComm.angle4}");

            rawDataString.Append("\n");
            if (trialRawDataFile != null && ++_rawDataFlushCounter >= RAW_DATA_FLUSH_INTERVAL)
                PeriodicFlushRawData();
        }
    }

    // Called from within rawDataLock — writes current buffer to disk and resets it.
    private void PeriodicFlushRawData()
    {
        if (trialRawDataFile == null || rawDataString == null) return;
        string _dir = Path.GetDirectoryName(trialRawDataFile);
        if (!Directory.Exists(_dir)) Directory.CreateDirectory(_dir);
        bool _append = File.Exists(trialRawDataFile);
        using (StreamWriter sw = new StreamWriter(trialRawDataFile, _append, Encoding.UTF8))
            sw.Write(rawDataString.ToString());
        rawDataString.Clear();
        _rawDataFlushCounter = 0;
    }

    // Safe to call from any scene (e.g. on robot disconnect) — flushes in-flight trial data.
    public void FlushRawDataToDisk()
    {
        lock (rawDataLock)
        {
            PeriodicFlushRawData();
        }
    }

    private void WriteTrialDataToRawDataFile()
    {
        AppLogger.LogInfo($"Writing to: {trialRawDataFile}");

        string _dir = Path.GetDirectoryName(trialRawDataFile);
        if (!Directory.Exists(_dir)) Directory.CreateDirectory(_dir);

        lock (rawDataLock)
        {
            bool _append = File.Exists(trialRawDataFile);
            using (StreamWriter sw = new StreamWriter(trialRawDataFile, _append, Encoding.UTF8))
            {
                sw.Write(rawDataString.ToString());
            }
            rawDataString.Clear();
            rawDataString = null;
            _rawDataFlushCounter = 0;
        }
    }

    // AROM assessment raw data logging function.
    public void StartRawDataAromDataLogging(string movement, string datetime)
    {
        // Set the file name.
        trialAromDataFile = DataManager.GetRomRawFileName(movement, datetime);

        // Initialize the string builders.
        rawDataString = new StringBuilder();
        // Write pre-header and header information
        rawDataString.AppendLine($":Device  : MARS");
        rawDataString.AppendLine($":Location: {userData.GetDeviceLocation()}");
        rawDataString.AppendLine($":User    : {userID}");
        rawDataString.AppendLine($":Movement: {selectedMovement.name}");
        rawDataString.AppendLine(string.Join(",", DataManager.RAWFILEHEADER));

        // Attach the event handler for data logging.
        MarsComm.OnNewMarsData += OnNewMarsRawDataLogging;
    }

    public void StopRawDataAromDataLogging()
    {
        AppLogger.LogInfo($"Writing AROM raw data to {trialAromDataFile}");
        string _dir = Path.GetDirectoryName(trialAromDataFile);

        // Create directory if it doesn't exist.
        if (!Directory.Exists(_dir)) Directory.CreateDirectory(_dir);

        // Write the raw data to file.
        lock (rawDataLock)  // locking
        {
            using (StreamWriter sw = new StreamWriter(trialAromDataFile, false, Encoding.UTF8))
            {
                sw.Write(rawDataString.ToString());
            }
            rawDataString.Clear();
            rawDataString = null;
        }
        MarsComm.OnNewMarsData -= OnNewMarsRawDataLogging;
        trialAromDataFile = null;
    }
    
    // Arm Weight assessment raw data logging function.
    public void StartRawDataArmWeightDataLogging(string datetime)
    {
        // Set the file name.
        trialArmWeightDataFile = DataManager.GetArmWeightRawFileName(datetime);

        // Initialize the string builders.
        rawDataString = new StringBuilder();
        // Write pre-header and header information
        rawDataString.AppendLine($":Device: MARS");
        rawDataString.AppendLine($":Location: {userData.GetDeviceLocation()}");
        rawDataString.AppendLine($":User    : {userID}");
        rawDataString.AppendLine($":Movement: MLAP");
        rawDataString.AppendLine(string.Join(",", DataManager.RAWFILEHEADER));

        // Attach the event handler for data logging.
        MarsComm.OnNewMarsData += OnNewMarsRawDataLogging;
    }

    public void StopRawDataArmWeightDataLogging()
    {
        AppLogger.LogInfo($"Writing Arm Weight raw data to {trialArmWeightDataFile}");
        string _dir = Path.GetDirectoryName(trialArmWeightDataFile);

        // Create directory if it doesn't exist.
        if (!Directory.Exists(_dir)) Directory.CreateDirectory(_dir);

        // Write the raw data to file.
        lock (rawDataLock)  // locking
        {
            using (StreamWriter sw = new StreamWriter(trialArmWeightDataFile, false, Encoding.UTF8))
            {
                sw.Write(rawDataString.ToString());
            }
            rawDataString.Clear();
            rawDataString = null;
        }
        MarsComm.OnNewMarsData -= OnNewMarsRawDataLogging;
        trialArmWeightDataFile = null;
    }

    private Vector3 GetGamePlayerPosition()
    {
       if(selectedGame == null) return Vector3.zero;
        switch (selectedGame.name)
        {
            case "SS":
                return SpaceShooterGameContoller.Instance != null
                    ? SpaceShooterGameContoller.Instance.playerGamePosition
                    : Vector3.zero;

            case "PP":
                return pongGameController.Instance != null
                    ? pongGameController.Instance.playerGamePosition
                    : Vector3.zero;

            case "DC":
                return DCGameController.Instance != null
                    ? DCGameController.Instance.playerGamePosition
                    : Vector3.zero;
            case "TT":
                return FlappyGameControl.Instance != null
                    ? FlappyGameControl.Instance.playerGamePosition
                     : Vector3.zero;
            case "TW":
                return TWGameController.Instance != null
                    ? TWGameController.Instance.playerGamePosition
                    : Vector3.zero;
            case "MC":
                return MCGameController.Instance != null
                    ? MCGameController.Instance.playerGamePosition
                    : Vector3.zero;

            default:
                return Vector3.zero;
        }
    }


    private Vector3 GetGameTargetPosition()
    {
        if (selectedGame == null) return Vector3.zero;
        switch (selectedGame.name)
        {
            case "SS":
                return SpaceShooterGameContoller.Instance != null
                    ? SpaceShooterGameContoller.Instance.targetGamePosition ?? Vector3.zero
                    : Vector3.zero;

            case "PP":
                return pongGameController.Instance != null
                    ? pongGameController.Instance.targetGamePosition ?? Vector3.zero
                    : Vector3.zero;

            case "DC":
                return DCGameController.Instance != null
                    ? DCGameController.Instance.targetGamePosition ?? Vector3.zero
                    : Vector3.zero;
            case "TT":
                return FlappyGameControl.Instance != null
                    ? FlappyGameControl.Instance.targetGamePosition ?? Vector3.zero
                    : Vector3.zero;
            case "TW":
                return TWGameController.Instance != null
                    ? TWGameController.Instance.targetGamePosition ?? Vector3.zero
                    : Vector3.zero;
            case "MC":
                return MCGameController.Instance != null
                    ? MCGameController.Instance.targetGamePosition ?? Vector3.zero
                    : Vector3.zero;
            default:
                return Vector3.zero;
        }
    }


    private Vector3 GetEndPointTargetPosition()
    {
        if (selectedGame == null) return Vector3.zero;
        switch (selectedGame.name)
        {
            case "SS":
                return SpaceShooterGameContoller.Instance != null
                    ? SpaceShooterGameContoller.Instance.targetEndPointPosition ?? Vector3.zero
                    : Vector3.zero;

            case "PP":
                return pongGameController.Instance != null
                    ? pongGameController.Instance.targetEndPointPosition ?? Vector3.zero
                    : Vector3.zero;

            case "DC":
                return DCGameController.Instance != null
                    ? DCGameController.Instance.targetEndPointPosition ?? Vector3.zero
                    : Vector3.zero;
            case "TT":
                return FlappyGameControl.Instance != null
                    ? FlappyGameControl.Instance.targetEndPointPosition ?? Vector3.zero
                    : Vector3.zero;

            case "TW":
                return TWGameController.Instance != null
                    ? TWGameController.Instance.targetEndPointPosition ?? Vector3.zero
                    : Vector3.zero;
            case "MC":
                return MCGameController.Instance != null
                    ? MCGameController.Instance.targetEndPointPosition ?? Vector3.zero
                    : Vector3.zero;
            default:
                return Vector3.zero;
        }
    }

    //Target Time in Ping pong
    private string GetMiscellaneous()
    {
        if (selectedGame == null) return "";
        switch (selectedGame.name)
        {
            case "SS":
                return "";

            case "PP":
                return pongGameController.Instance.targetTime.ToString("F2");

            case "DC":
                return "";
            case "TT":
                return "";

            case "TW":
                return TWGameController.Instance.TargetArea;

            case "MC":
                return "";
            default:
                return "";
        }
    }

    private string GetGameState()
    {
        if (selectedGame == null) return "";
        //// Get the game state.
        if (selectedGame.name == "SS")
        {
            return SpaceShooterGameContoller.Instance!=null? SpaceShooterGameContoller.Instance.gameState.ToString():"";
        }
        else if (selectedGame.name == "PP")
        {
            return pongGameController.Instance!=null?pongGameController.Instance.gameState.ToString():"";
        }

        else if (selectedGame.name == "DC")
        {
            return DCGameController.Instance != null ? DCGameController.Instance.gameState.ToString() : "";
        }
        else if (selectedGame.name == "TT")
        {
            return FlappyGameControl.Instance != null ? FlappyGameControl.Instance.gameState.ToString() : "";
        }
        else if(selectedGame.name == "TW")
        {
            return TWGameController.Instance != null ? TWGameController.Instance.gameState.ToString() : "";
        }
        else if (selectedGame.name == "MC")
        {
            return MCGameController.Instance != null ? MCGameController.Instance.gameState.ToString() : "";
        }
        return "";
    }
    private string GetTargetNumber()
    {
        if (selectedGame == null) return "";
        //// Get the game state.
        if (selectedGame.name == "SS")
        {
            return SpaceShooterGameContoller.Instance != null ? SpaceShooterGameContoller.Instance.nTargets.ToString() : "";
        }
        else if (selectedGame.name == "PP")
        {
            return pongGameController.Instance != null ? pongGameController.Instance.nTargets.ToString() : "";
        }

        else if (selectedGame.name == "DC")
        {
            return DCGameController.Instance != null ? DCGameController.Instance.nTargets.ToString() : "";
        }
        else if (selectedGame.name == "TT")
        {
            return FlappyGameControl.Instance != null ? FlappyGameControl.Instance.nTargets.ToString() : "";
        }
        else if (selectedGame.name == "TW")
        {
            return TWGameController.Instance != null ? TWGameController.Instance.nTargets.ToString() : "";
        }
        else if (selectedGame.name == "MC")
        {
            return MCGameController.Instance != null ? MCGameController.Instance.nTargets.ToString() : "";
        }
        return "";
    }
    private string GetHitNumber()
    {
        if (selectedGame == null) return "";
        //// Get the game state.
        if (selectedGame.name == "SS")
        {
            return SpaceShooterGameContoller.Instance != null ? SpaceShooterGameContoller.Instance.nSuccess.ToString() : "";
        }
        else if (selectedGame.name == "PP")
        {
            return pongGameController.Instance != null ? pongGameController.Instance.nSuccess.ToString() : "";
        }

        else if (selectedGame.name == "DC")
        {
            return DCGameController.Instance != null ? DCGameController.Instance.nSuccess.ToString() : "";
        }
        else if (selectedGame.name == "TT")
        {
            return FlappyGameControl.Instance != null ? FlappyGameControl.Instance.nSuccess.ToString() : "";
        }
        else if (selectedGame.name == "TW")
        {
            return TWGameController.Instance != null ? TWGameController.Instance.nSuccess.ToString() : "";
        }
        else if (selectedGame.name == "MC")
        {
            return MCGameController.Instance != null ? MCGameController.Instance.nSuccess.ToString() : "";
        }
        return "";
    }
    private string GetMissNumber()
    {
        if (selectedGame == null) return "";
        //// Get the game state.
        if (selectedGame.name == "SS")
        {
            return SpaceShooterGameContoller.Instance != null ? SpaceShooterGameContoller.Instance.nFailure.ToString() : "";
        }
        else if (selectedGame.name == "PP")
        {
            return pongGameController.Instance != null ? pongGameController.Instance.nFailure.ToString() : "";
        }

        else if (selectedGame.name == "DC")
        {
            return DCGameController.Instance != null ? DCGameController.Instance.nFailure.ToString() : "";
        }
        else if (selectedGame.name == "TT")
        {
            return FlappyGameControl.Instance != null ? FlappyGameControl.Instance.nFailure.ToString() : "";
        }
        else if (selectedGame.name == "TW")
        {
            return TWGameController.Instance != null ? TWGameController.Instance.nFailure.ToString() : "";
        }
        else if (selectedGame.name == "MC")
        {
            return MCGameController.Instance != null ? MCGameController.Instance.nFailure.ToString() : "";
        }
        return "";
    }
    // Returns (targets, hits, misses) from whichever game is currently running.
    private (int targets, int hits, int misses) GetCurrentGameStats()
    {
        if (selectedGame == null) return (1, 0, 0);
        switch (selectedGame.name)
        {
            case "SS": return SpaceShooterGameContoller.Instance != null
                ? (SpaceShooterGameContoller.Instance.nTargets,
                   SpaceShooterGameContoller.Instance.nSuccess,
                   SpaceShooterGameContoller.Instance.nFailure)
                : (1, 0, 0);
            case "PP": return pongGameController.Instance != null
                ? (pongGameController.Instance.nTargets,
                   pongGameController.Instance.nSuccess,
                   pongGameController.Instance.nFailure)
                : (1, 0, 0);
            case "DC": return DCGameController.Instance != null
                ? (DCGameController.Instance.nTargets,
                   DCGameController.Instance.nSuccess,
                   DCGameController.Instance.nFailure)
                : (1, 0, 0);
            case "TT": return FlappyGameControl.Instance != null
                ? (FlappyGameControl.Instance.nTargets,
                   FlappyGameControl.Instance.nSuccess,
                   FlappyGameControl.Instance.nFailure)
                : (1, 0, 0);
            case "TW": return TWGameController.Instance != null
                ? (TWGameController.Instance.nTargets,
                   TWGameController.Instance.nSuccess,
                   TWGameController.Instance.nFailure)
                : (1, 0, 0);
            case "MC": return MCGameController.Instance != null
                ? (MCGameController.Instance.nTargets,
                   MCGameController.Instance.nSuccess,
                   MCGameController.Instance.nFailure)
                : (1, 0, 0);
            default: return (1, 0, 0);
        }
    }

    // Called when Bluetooth disconnects mid-game.
    // Stops the trial using whatever data was recorded so far, then the caller navigates to SUMMARY.
    public void StopTrialOnDisconnect()
    {
        if (trialRawDataFile == null) return;
        AppLogger.LogWarning("StopTrialOnDisconnect: Bluetooth lost — saving trial data.");
        var (t, h, m) = GetCurrentGameStats();
        StopTrial(t, h, m);
    }

    public void reloadSessionDetails() => Instance.userData.readParseSessionData(DataManager.sessionFile);
}
