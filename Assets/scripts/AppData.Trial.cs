
using System;
using System.IO;
using System.Linq;
using System.Text;

/*
 * HOMER MARS Application Data Class.
 * Implements all the functions for running game trials.
 */
public partial class AppData
{
    // Start a new trial.
    public void StartNewTrial()
    {
         
        
        trialStartTime = DateTime.Now;
        trialStopTime = null;
        selectedMovement.NextTrail();
        
        // Set the trial data files.
        StartRawAndAanExecDataLogging();

        // Write trial details to the log file.
        string _tdetails = string.Join(" | ",
            new string[] {
                $"Start Time: {trialStartTime:yyyy-MM-ddTHH:mm:ss}",
                $"Trial#Day: {selectedMovement.trialNumberDay}",
                $"Trial#Sess: {selectedMovement.trialNumberSession}",
                $"TrialType: ",
                $"Desired SR: ",
                $"Current CB: ",
                $"TrialRawDataFile: {trialRawDataFile.Split('/').Last()}"
        });
        AppLogger.LogInfo($"StartNewTrial | {_tdetails}");
    }

    public void StopTrial(int nTargets, int nSuccess, int nFailure)
    {
        

        trialStopTime = DateTime.Now;
        nTargets = (nTargets == 0) ? 1 : nTargets;
        successRate = 100 * nSuccess / nTargets;

        // Write trial information to the session details file.
        WriteTrialToSessionsFile();
       
        string _tdetails = string.Join(" | ",
            new string[] {
                $"Start Time: {trialStartTime:yyyy-MM-ddTHH:mm:ss}",
                $"Stop Time: {trialStopTime:yyyy-MM-ddTHH:mm:ss}",
                $"Trial#Day: {selectedMovement.trialNumberDay}",
                $"Trial#Sess: {selectedMovement.trialNumberSession}",
                $"TrialType: ",
                $"NTargets: {nTargets}",
                $"NSuccess: {nSuccess}",
                $"NFailure: {nFailure}",
                $"Desired SR: ",
                $"Trial SR:{successRate} ", 
                $"Current CB:",//CHANGE FOR MARS
                $"Next CB: ",//CHANGE FOR MARS
                $"TrialRawDataFile: {trialRawDataFile.Split('/').Last()}"
        });
        AppLogger.LogInfo($"StopTrial | {_tdetails}");
        // Stop Raw and AAN real-time data logging.
        WriteTrialDataToRawDataFile();
        MarsComm.OnNewMarsData -= OnNewMarsDataDataLogging;
        trialRawDataFile = null;
        //set to upload the data to the AWS
        //awsManager.changeUploadStatus(awsManager.status[0]);
    }

    private void WriteTrialToSessionsFile()
    {
        // Build the trial row.
        string[] trialRow = new string[] {
            // "SessionNumber"
            $"{currentSessionNumber}",
            // "DateTime"
            startTime.ToString(DataManager.DATETIMEFORMAT),
            // "TrialNumberDay"
            $"{selectedMovement.trialNumberDay}",
            // "TrialNumberSession"
            $"{selectedMovement.trialNumberSession}",
            // "TrialType"
            $"{""}",
            // "TrialStartTime"
            trialStartTime.ToString(DataManager.DATETIMEFORMAT),
            // "TrialStopTime"
            trialStopTime?.ToString(DataManager.DATETIMEFORMAT),
            // "TrialRawDataFile"
            trialRawDataFile.Split("/data/")[1],
            // "Movement"
             $"{selectedMovement.name}",
            // "GameName"
            $"{selectedGame}",
            // "GameParameter"
            null,
            // "GameSpeed"
            "",//speedData.gameSpeed.ToString(),
            // "AssistMode"
            
            //trialType == HomerTherapy.TrialType.SR85PCCATCH ? "ACTIVE" : "AAN",
            $"{selectedMovement.MarsMode}",//need to change to transition control
            // "DesiredSuccessRate"
            $"",
            // "SuccessRate"
            $"{successRate}",
            // "CurrentControlBound"
            "",//trialType == HomerTherapy.TrialType.SR85PCCATCH ? "0" : $"{_currControlBound:F3}",
            // "NextControlBound"
            "",//trialType == HomerTherapy.TrialType.SR85PCCATCH ?  "0": $"{aanController.currentCtrlBound:F3}",
            //gameTime
            Others.gameTime.ToString()
        };

        // Write the trial row to the session file.
        using (StreamWriter sw = new StreamWriter(DataManager.sessionFilePath, true, Encoding.UTF8))
        {
            // Write the trial row to the session file.
            sw.WriteLine(string.Join(",", trialRow));
        }
    }

    //CHANGE FOR MARS
    public void StartRawAndAanExecDataLogging()
    {
        //// Set the file name.
        trialRawDataFile = DataManager.GetTrialRawDataFileName(
            currentSessionNumber,
            selectedMovement.trialNumberDay,
            Instance.selectedGame,
            Instance.selectedMovement.name);

        //// Initialize the string builders.
        rawDataString = new StringBuilder();
        // Write pre-header and header information
        rawDataString.AppendLine($":Device: PLUTO");
        rawDataString.AppendLine($":Location: {userData.GetDeviceLocation()}");
        rawDataString.AppendLine($":Mechanism: {selectedMovement.name}");
        rawDataString.AppendLine($":Game: {selectedGame}");
        rawDataString.AppendLine($":TrialType: ");
        rawDataString.AppendLine($":TrialStartTime: {trialStartTime:yyyy-MM-ddTHH:mm:ss}");
        rawDataString.AppendLine($":TrialNumberDay: {selectedMovement.trialNumberDay}");
        if(selectedMovement.name != "SFE")
        {
            rawDataString.AppendLine($":FWS-ROM: X-[{selectedMovement.CurrentAromFWS[0]:F3},{selectedMovement.CurrentAromFWS[1]:F3}],Y-[{selectedMovement.CurrentAromFWS[2]:F3},{selectedMovement.CurrentAromFWS[3]:F3}]");
            rawDataString.AppendLine($":HWS-ROM: X-[{selectedMovement.CurrentAromHWS[0]:F3},{selectedMovement.CurrentAromHWS[1]:F3}],Y-[{selectedMovement.CurrentAromHWS[2]:F3},{selectedMovement.CurrentAromHWS[3]:F3}]");
            rawDataString.AppendLine($":FWS-ROM: X-[{selectedMovement.CurrentAromNWS[0]:F3},{selectedMovement.CurrentAromNWS[1]:F3}],Y-[{selectedMovement.CurrentAromNWS[2]:F3},{selectedMovement.CurrentAromNWS[3]:F3}]");
        }
        
        rawDataString.AppendLine($":DesiredSuccessRate: ");
        rawDataString.AppendLine($":ControlBound: ");
        rawDataString.AppendLine(string.Join(",", DataManager.RAWFILEHEADER_));

        // Attach the event handler for data logging.
        MarsComm.OnNewMarsData += OnNewMarsDataDataLogging;
    }
    //"DeviceRunTime","PacketNumber","Status","ErrorString",
    //    "Limb","Calibration","LimbKinParam","limbDynParam",
    //    "Target","Desired","Control",
    //    "Angle1","Angle2","Angle3","Angle4",
    //    "ImuAngle1","ImuAngle2","ImuAngle3",
    //    "Force","Torque",
    //    "EndPointX","EndPointY","EndPointZ",
    //    "Phi1","Phi2","Phi3",
    //    "GamePlayerX","GamePlayerY","GameTargetX","GameTargetY","GameState"
    public void OnNewMarsDataDataLogging()
    {
        lock (rawDataLock)
        {
            if (rawDataString == null)
            {
                UnityEngine.Debug.LogWarning("rawDataString is null, skipping logging.");

                return;
            }
            rawDataString.Append($"{MarsComm.runTime},");
            rawDataString.Append($"{MarsComm.packetNumber},");
            rawDataString.Append($"{MarsComm.status},");
            rawDataString.Append($"{MarsComm.errorString},");
            rawDataString.Append($"{MarsComm.limb},");
            rawDataString.Append($"{MarsComm.calibration},");
            rawDataString.Append($"{MarsComm.limbKinParam},");
            rawDataString.Append($"{MarsComm.limbDynParam},");
            rawDataString.Append($"{MarsComm.target},");
            rawDataString.Append($"{MarsComm.desired},");
            rawDataString.Append($"{MarsComm.control},");
            rawDataString.Append($"{MarsComm.angle1},");
            rawDataString.Append($"{MarsComm.angle2},");
            rawDataString.Append($"{MarsComm.angle3},");
            rawDataString.Append($"{MarsComm.angle4},");
            rawDataString.Append($"{MarsComm.imu1Angle},");
            rawDataString.Append($"{MarsComm.imu2Angle},");
            rawDataString.Append($"{MarsComm.imu3Angle},");
            rawDataString.Append($"{MarsComm.imu4Angle},");
            rawDataString.Append($"{MarsComm.force},");
            rawDataString.Append($"{MarsComm.torque},");
            rawDataString.Append($"{MarsComm.xEndpoint},");
            rawDataString.Append($"{MarsComm.yEndpoint},");
            rawDataString.Append($"{MarsComm.zEndpoint},");
            rawDataString.Append($"{MarsComm.phi1},");
            rawDataString.Append($"{MarsComm.phi2},");
            rawDataString.Append($"{MarsComm.phi3},");
         
            // Game Data
            rawDataString.Append($"{GetGamePlayerPosition()},");
            rawDataString.Append($"{GetGameTargetPosition()},");
            rawDataString.Append($"{GetGameState()},");
        
            rawDataString.Append("\n");
        }
    }

    private void WriteTrialDataToRawDataFile()
    {
        AppLogger.LogInfo($"Writing to: {trialRawDataFile}");
        AppLogger.LogInfo($"File exists before write? {File.Exists(trialRawDataFile)}");

        string _dir = Path.GetDirectoryName(trialRawDataFile);
        if (!Directory.Exists(_dir)) Directory.CreateDirectory(_dir);

        lock (rawDataLock)  // locking
        {
            using (StreamWriter sw = new StreamWriter(trialRawDataFile, false, Encoding.UTF8))
            {
                sw.Write(rawDataString.ToString());
            }
            rawDataString.Clear();
            rawDataString = null;
        }
        AppLogger.LogInfo($"File exists before write? {File.Exists(trialRawDataFile)}");

    }

    //CHECK FOR MARS
    private string GetGamePlayerPosition()
    {
        // Get the game target X position.
        if (selectedGame == "space_shooter_home")
        {
            return $"{spaceShooterGameContoller.Instance.playerPosition.x:F3},{spaceShooterGameContoller.Instance.playerPosition.y:F3}";
        }
        else if (selectedGame == "pong_game")
        {
            return $"{pongGameController.instance.PlayerPosition.x:F3},{pongGameController.instance.PlayerPosition.y:F3}";
        }
        else if (selectedGame == "FlappyGame")
        {
            return $"{FlappyGameControl.instance.PlayerPosition.x:F3},{FlappyGameControl.instance.PlayerPosition.y:F3}";
        }
        return ",";
    }

    private string GetGameTargetPosition()
    {
        //// Get the game target X position.
        if (selectedGame == "space_shooter_home")
        {
            if (spaceShooterGameContoller.Instance.targetPosition.HasValue)
            {
                return $"{spaceShooterGameContoller.Instance.targetPosition.Value.x:F3},{spaceShooterGameContoller.Instance.targetPosition.Value.y:F3}";
            }
        }
        else if (selectedGame == "pong_game")
        {
            if (pongGameController.instance.TargetPosition.HasValue) return $"{pongGameController.instance.TargetPosition.Value.x:F3},{pongGameController.instance.TargetPosition.Value.y:F3}";
        }
        else if (selectedGame == "FlappyGame")
        {
            if (FlappyGameControl.instance.TargetPosition.HasValue) return $"{FlappyGameControl.instance.TargetPosition.Value.x:F3},{FlappyGameControl.instance.TargetPosition.Value.y:F3}";
        }
        return ",";
    }

    private string GetGameState()
    {
        //// Get the game state.
        if (selectedGame == "space_shooter_home")
        {
            return $"{spaceShooterGameContoller.Instance.gameState}";
        }
        else if (selectedGame == "pong_game")
        {
            return $"{pongGameController.instance.gameState}";
        }
        else if (selectedGame == "FlappyGame")
        {
            return $"{FlappyGameControl.instance.gameState}";
        }
        return "";
    }
}
