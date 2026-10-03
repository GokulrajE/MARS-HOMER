using System.Collections;
using System.Collections.Generic;
using System.IO;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;


public class SetUpMars : MonoBehaviour
{
    //ui related variables
    public Text instructionTxt;
    public TMP_Text statusTxt;
    public GameObject marsActivationGIF;
    public GameObject AttachArmGIF;
    public GameObject detachArmGIF;
    public Button goBackBtn;
   
    public readonly string robotCalibScene = "ROBOTCALIB";
    public readonly string nextScene = "CHOOSEMOVE";
    public readonly string summaryScene = "SUMMARY";

    public enum SETUPMARS
    {
        IDLE,
        ACTIVATE,
        ATTACHARM,
        SETTRAININGPLANEANGLE,
        DONE,
        SETDEACTIVATEMODE,
        DEACTIVATE
    }
    public SETUPMARS currentState = SETUPMARS.IDLE;

    public const float TARGET_REACH_ERROR = 10f; // Degrees
    private const float ARM_WEIGHT_ERROR = 15f;  //  Force

    // Start is called before the first frame update
    void Start()
    {
        MarsComm.sendHeartbeat();
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
        // Initialize AppData if needed
        if (AppData.Instance.userData == null)
        {
            AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
        }
        // Check if the directory exists
        if (!Directory.Exists(DataManager.basePath)) Directory.CreateDirectory(DataManager.basePath);
        if (!File.Exists(DataManager.configFile)) SceneManager.LoadScene("CONFIG");

        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");

        // IF the robot is not calibrated go to the robot calib scene.
        if (MarsComm.CALIBRATION[MarsComm.calibration] == "NOCALIB")
        {
            SceneManager.LoadScene(robotCalibScene);
        }
        
        //Handle Deactivate Mars
        if (AppData.Instance.userData.trainingPlaneAngle == 0) return;
        if (MarsComm.CONTROLTYPE[MarsComm.controlType] == "POSITION")
        {
            goBackBtn.gameObject.SetActive(true);
            goBackBtn.onClick.AddListener(onBack);
            AppLogger.LogInfo("MARS set to Deactivate Mode");
            currentState = SETUPMARS.SETDEACTIVATEMODE;
        }
       
       
    }

    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();
        if (!ConnectToRobot.isMARS)
        {
            currentState = SETUPMARS.DEACTIVATE;
        }
        updateGUI();
        runStateMachine();
    }
    public void runStateMachine()
    {
        if (currentState == SETUPMARS.DONE) return;
        statusTxt.text = $"{Mathf.Abs(MarsComm.angle1):F2} deg | {Mathf.Abs(MarsComm.force):F2} N";
        switch (currentState)
        {
            case SETUPMARS.IDLE:
                instructionTxt.text = "Press MARS Button To Activate";
                if (MarsComm.CONTROLTYPE[MarsComm.controlType] != "POSITION")
                    MarsComm.setControlType("POSITION");
                break;
            case SETUPMARS.ACTIVATE:
                instructionTxt.text = "........";
                if (MarsComm.CONTROLTYPE[MarsComm.controlType] == "POSITION")
                {
                    if (MarsComm.target == -90)
                    {
                        // Check if the target has been reached.
                        if (Mathf.Abs(MarsComm.angle1 - MarsComm.target) < TARGET_REACH_ERROR)
                        {
                            currentState = SETUPMARS.ATTACHARM;
                        }
                    }
                    else
                    {
                        MarsComm.setControlTarget(-90);
                    }
                }
                break;
            case SETUPMARS.ATTACHARM:
                if (MarsComm.force > MarsComm.ARM_WEIGHT_THRESHOLD)
                {
                    instructionTxt.text = $"Press MARS Button To Set TrainigPlane\n" +
                                          $"-- {Mathf.Abs(AppData.Instance.userData.trainingPlaneAngle).ToString("F0")} --";
                }
                else
                {
                    instructionTxt.text = "Please attach your hand with MARS";
                }
                break;
            case SETUPMARS.SETTRAININGPLANEANGLE:
                instructionTxt.text = $"Setting TrainingPlaneAngle : {Mathf.Abs(AppData.Instance.userData.trainingPlaneAngle).ToString("F0")}";
                if (MarsComm.target != AppData.Instance.userData.trainingPlaneAngle)
                    MarsComm.setControlTarget(AppData.Instance.userData.trainingPlaneAngle);
                if (MarsComm.target == AppData.Instance.userData.trainingPlaneAngle)
                {
                    // Check if the target has been reached.
                    if (Mathf.Abs(MarsComm.angle1 - MarsComm.target) < TARGET_REACH_ERROR)
                    {
                        AppLogger.LogInfo($"Setting MARS Position @ TrainingAngle {MarsComm.target}deg | Actual : {MarsComm.angle1}deg");
                        currentState = SETUPMARS.DONE;
                        instructionTxt.text = "";
                        AppLogger.LogInfo($"Switching  Scene to {nextScene}");
                        SceneManager.LoadScene(nextScene);
                    }
                }
                break;
            case SETUPMARS.SETDEACTIVATEMODE:
                if (MarsComm.force > ARM_WEIGHT_ERROR)
                {
                    instructionTxt.text = "Please remove your hand from MARS";
                }
                else
                {
                    instructionTxt.text = "Press the MARS button to move the robot arm down";
                }
                break;
            case SETUPMARS.DEACTIVATE:
                AppLogger.LogInfo($"Deativating MARS");

                JediComm.Disconnect();
                SceneManager.LoadScene(summaryScene);
                break;
        }
    }
    
    public void updateGUI()
    {
        instructionTxt.gameObject.SetActive(currentState != SETUPMARS.DONE);
        marsActivationGIF.SetActive(currentState == SETUPMARS.IDLE || currentState == SETUPMARS.ACTIVATE);
        AttachArmGIF.SetActive(currentState == SETUPMARS.ATTACHARM && MarsComm.force < ARM_WEIGHT_ERROR);
        detachArmGIF.SetActive(currentState==SETUPMARS.SETDEACTIVATEMODE&& MarsComm.force > ARM_WEIGHT_ERROR);
        
    }

    public void OnMarsButtonReleased()
    {
        switch (currentState)
        {
            case SETUPMARS.IDLE:
                AppLogger.LogInfo("Setting MARS Position @ -90");
                currentState = SETUPMARS.ACTIVATE;
                break;
            case SETUPMARS.ATTACHARM:
                if (MarsComm.force > MarsComm.ARM_WEIGHT_THRESHOLD)
                {
                    AppLogger.LogInfo($"Limb is not Attached with MARS  FORCE - {MarsComm.force}");
                    currentState = SETUPMARS.SETTRAININGPLANEANGLE;
                }
                else
                {
                    AppLogger.LogInfo($"Set MARS Position @ TrainingAngle - {AppData.Instance.userData.trainingPlaneAngle}");
                }
                break;
            case SETUPMARS.SETDEACTIVATEMODE:
                if(MarsComm.force > ARM_WEIGHT_ERROR)
                {
                    AppLogger.LogInfo($"Limb is Attached with MARS  FORCE - {MarsComm.force}"); 
                }
                else
                {
                    AppLogger.LogInfo("Ready To Deactivate");
                     AgentSession.Instance.StopSessionNow();
                    currentState = SETUPMARS.DEACTIVATE;
                }
                break;
        }
    }
    public void onBack()
    {
        if (currentState == SETUPMARS.DEACTIVATE) return;
        AppLogger.LogInfo($"Switching  Scene to {nextScene}");
        SceneManager.LoadScene(nextScene);
    }

    private void OnDestroy()
    {

        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;

    }

}
