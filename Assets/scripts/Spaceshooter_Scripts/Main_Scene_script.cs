using NeuroRehabLibrary;
using System.Collections;
using System.Collections.Generic;
//using UnityEditor.SearchService;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Main_Scene_script : MonoBehaviour
{
    private GameSession currentGameSession;
    public static bool changeScene = false;
    public readonly string nextScene = "space_shooter_level";
    // Start is called before the first frame update
    void Start()
    {
        // Attach mars button event
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        StartNewGameSession();
    }

    // Update is called once per frame
    void Update()
    {

    
     // Check if it time to switch to the next scene
        if (changeScene == true)
        {
            LoadTargetScene();
            changeScene = false;
        }
    }

    public void onMarsButtonReleased()
{
    AppLogger.LogInfo("Mars button released.");
    changeScene = true;

}

    private void LoadTargetScene()
    {
        AppLogger.LogInfo($"Switching to the next scene '{nextScene}'.");
        SceneManager.LoadScene(nextScene);
    }
void StartNewGameSession()
    {
        currentGameSession = new GameSession
        {
            GameName = "Tuk-Tuk",
            Assessment = 0 // Example assessment value, 
                           //If this script for calibration and assessment then Assessment=1. 
        };
        SessionManager.Instance.StartGameSession(currentGameSession);
        SetSessionDetails();
    }

    public void SetSessionDetails()
    {
        string device = "MARS"; // Set the device name
        string assistMode = "Null"; // Set the assist mode
        string assistModeParameters = "Null"; // Set the assist mode parameters
        string deviceSetupLocation = DataManager.filePathforConfig;
        SessionManager.Instance.SetDevice(device, currentGameSession);
        SessionManager.Instance.SetAssistMode(assistMode, assistModeParameters, currentGameSession);
        SessionManager.Instance.SetDeviceSetupLocation(deviceSetupLocation, currentGameSession);
    }
    void EndCurrentGameSession()
    {
        if (currentGameSession != null)
        {
            string trialDataFileLocation = "pass_trial_data_location";
            string gameParameter = "pass_game_parameter";
            SessionManager.Instance.SetGameParameter(gameParameter, currentGameSession);
            SessionManager.Instance.SetTrialDataFileLocation(trialDataFileLocation, currentGameSession);
            SessionManager.Instance.EndGameSession(currentGameSession);
        }
    }

    public void onClick_gotoLevel()
    {
        SceneManager.LoadScene("space_shooter_level");
    }
    public void onclick_gotochoose()
    {
        SceneManager.LoadScene("chooseMovementScene");
    }
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
}
