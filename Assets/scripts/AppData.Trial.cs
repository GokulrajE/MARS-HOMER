
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using Unity.VisualScripting;


/*
 * HOMER PLUTO Application Data Class.
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
        //NEED TO CHECK WITH MARS
        // Dettach the event handler for data logging.
        // PlutoComm.OnNewPlutoData -= OnNewPlutoDataDataLogging;

        trialStopTime = DateTime.Now;
  
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
                $"Trial SR: ", 
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
        awsManager.changeUploadStatus(awsManager.status[0]);
    }

    private void WriteTrialToSessionsFile()
    {
        // Build the trial row.
        string[] trialRow = new string[] {
            // "SessionNumber"
            $"{currentSessionNumber}",
            // "DateTime"
            startTime.ToString(DataManager.DATEFORMAT),
            // "TrialNumberDay"
            $"{selectedMovement.trialNumberDay}",
            // "TrialNumberSession"
            $"{selectedMovement.trialNumberSession}",
            // "TrialType"
            $"{""}",
            // "TrialStartTime"
            trialStartTime.ToString(DataManager.DATEFORMAT),
            // "TrialStopTime"
            trialStopTime?.ToString(DataManager.DATEFORMAT),
            // "TrialRawDataFile"
            trialRawDataFile.Split("/data/")[1],
            // "Mechanism"
            selectedMovement.name, 
            // "GameName"
            selectedGame,
            // "GameParameter"
            null,
            // "GameSpeed"
            "",//speedData.gameSpeed.ToString(),
            // "AssistMode"
            //trialType == HomerTherapy.TrialType.SR85PCCATCH ? "ACTIVE" : "AAN",
            "",
            // "DesiredSuccessRate"
            $"",
            // "SuccessRate"
            $"",
            // "CurrentControlBound"
            "",//trialType == HomerTherapy.TrialType.SR85PCCATCH ? "0" : $"{_currControlBound:F3}",
            // "NextControlBound"
            "",//trialType == HomerTherapy.TrialType.SR85PCCATCH ?  "0": $"{aanController.currentCtrlBound:F3}",
            //gameTime
            Others.gameTime.ToString()
        };

        // Write the trial row to the session file.
        using (StreamWriter sw = new StreamWriter(DataManager.filePathSessionData, true, Encoding.UTF8))
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
        //rawDataString = new StringBuilder();
        //// Write pre-header and header information
        //rawDataString.AppendLine($":Device: PLUTO");
        //rawDataString.AppendLine($":Location: {userData.GetDeviceLocation()}");
        //rawDataString.AppendLine($":Mechanism: {selectedMovement.name}");
        //rawDataString.AppendLine($":Game: {selectedGame}");
        ////rawDataString.AppendLine($":TrialType: {trialType}");
        //rawDataString.AppendLine($":TrialStartTime: {trialStartTime:yyyy-MM-ddTHH:mm:ss}");
        //rawDataString.AppendLine($":TrialNumberDay: {selectedMovement.trialNumberDay}");
        //rawDataString.AppendLine($":AROM: [{selectedMovement.CurrentArom[0]:F3},{selectedMovement.CurrentArom[1]:F3}]");
        //rawDataString.AppendLine($":PROM: [{selectedMovement.CurrentProm[0]:F3},{selectedMovement.CurrentProm[1]:F3}]");
        //rawDataString.AppendLine($":APROM: [{selectedMovement.CurrentAProm[0]:F3},{selectedMovement.CurrentAProm[1]:F3}]");
        ////rawDataString.AppendLine($":DesiredSuccessRate: {desiredSuccessRate:F3}");
        ////rawDataString.AppendLine($":ControlBound: {_currControlBound:F3}");
        //rawDataString.AppendLine(string.Join(",", DataManager.RAWFILEHEADER));

        //// Attach the event handler for data logging.
        //PlutoComm.OnNewPlutoData += OnNewPlutoDataDataLogging;
    }

    public void OnNewMarsDataDataLogging()
    {
        lock (rawDataLock)
        {
            if (rawDataString == null)
            {
                UnityEngine.Debug.LogWarning("rawDataString is null, skipping logging.");
                return;
            }

            // Device data
            //rawDataString.Append($"{MarsComm.runTime:F6},");
            //rawDataString.Append($"{MarsComm.packetNumber},");
            //rawDataString.Append($"{MarsComm.status},");
            //rawDataString.Append($"{MarsComm.dataType},");
            //rawDataString.Append($"{MarsComm.errorStatus},");
            //rawDataString.Append($"{MarsComm.controlType},");
            //rawDataString.Append($"{MarsComm.calibration},");
            //rawDataString.Append($"{MarsComm.MOVEMENT[MarsComm.mechanism]},");
            //rawDataString.Append($"{MarsComm.button},");
            //rawDataString.Append($"{MarsComm.angle},");
            //rawDataString.Append($"{MarsComm.torque},");
            //rawDataString.Append($"{MarsComm.desired},");
            //rawDataString.Append($"{MarsComm.control},");
            //rawDataString.Append($"{MarsComm.controlBound},");
            //rawDataString.Append($"{MarsComm.controlDir},");
            //rawDataString.Append($"{MarsComm.target},");
            //rawDataString.Append($"{MarsComm.err},");
            //rawDataString.Append($"{MarsComm.errDiff},");
            //rawDataString.Append($"{MarsComm.errSum},");

            // Game Data
            rawDataString.Append($"{GetGamePlayerPosition()},");
            rawDataString.Append($"{GetGameTargetPosition()},");
            rawDataString.Append($"{GetGameState()},");
            //rawDataString.Append($"{aanController.targetPosition:F3},");
            //rawDataString.Append($"{aanController.initialPosition:F3},");
            //rawDataString.Append($"{aanController.state}");

            // End of line
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
        //if (selectedGame == "HAT")
        //{
        //    return $"{HatGameController.Instance.PlayerPosition.x:F3},{HatGameController.Instance.PlayerPosition.y:F3}";
        //}
        //else if (selectedGame == "PONG")
        //{
        //    return $"{PongGameController.Instance.PlayerPosition.x:F3},{PongGameController.Instance.PlayerPosition.y:F3}";
        //}
        //else if (selectedGame == "TUK")
        //{
        //    return $"{FlappyGameControl.Instance.PlayerPosition.x:F3},{FlappyGameControl.Instance.PlayerPosition.y:F3}";
        //}
        return ",";
    }

    private string GetGameTargetPosition()
    {
        //// Get the game target X position.
        //if (selectedGame == "HAT")
        //{
        //    if (HatGameController.Instance.TargetPosition.HasValue)
        //    {
        //        return $"{HatGameController.Instance.TargetPosition.Value.x:F3},{HatGameController.Instance.TargetPosition.Value.y:F3}";
        //    }
        //}
        //else if (selectedGame == "PONG")
        //{
        //    if (PongGameController.Instance.TargetPosition.HasValue) return $"{PongGameController.Instance.TargetPosition.Value.x:F3},{PongGameController.Instance.TargetPosition.Value.y:F3}";
        //}
        //else if (selectedGame == "TUK")
        //{
        //    if (FlappyGameControl.Instance.TargetPosition.HasValue) return $"{FlappyGameControl.Instance.TargetPosition.Value.x:F3},{FlappyGameControl.Instance.TargetPosition.Value.y:F3}";
        //}
        return ",";
    }

    private string GetGameState()
    {
        //// Get the game state.
        //if (selectedGame == "HAT")
        //{
        //    return $"{HatGameController.Instance.gameState}";
        //}
        //else if (selectedGame == "PONG")
        //{
        //    return $"{PongGameController.Instance.gameState}";
        //}
        //else if (selectedGame == "TUK")
        //{
        //    return $"{FlappyGameControl.Instance.gameState}";
        //}
        return "";
    }
}
