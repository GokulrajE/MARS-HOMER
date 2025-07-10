using UnityEngine;
using UnityEngine.UI;
using TMPro;
using UnityEngine.SceneManagement;
using System.Collections;
using System.IO;
using System;
using UnityEngine.Rendering.Universal;
using System.Linq;


public class MovementSceneHandler : MonoBehaviour
{
    //ui related variables
    public GameObject movementSelectGroup;
    public Button nextButton;
    public Button exit;
    public static float initialAngle;
    private string nextScene = "calibratioScene";
    private string exitScene = "SummaryScene";
    private string assessmentScene = "weightCalibrationScene";
    public static float shAng;
    //flags
    private static bool changeScene = false;
    private bool toggleSelected = false;
    public GameObject MessageBox;
    //public TMP MesssageText;
    public TextMeshProUGUI gainMessageText;
    public TextMeshProUGUI DeactivateMessageText;
    public Slider supportIndicator;
    public bool ACTIVATE = false;
    public bool DEACTIVATE = false;

    void Start()
    {
        
        // Initialize if needed
        //if (AppData.Instance.userData.dTableConfig == null)
        //{
        //    // Inialize the logger
        //    AppLogger.StartLogging(SceneManager.GetActiveScene().name);
        //    // Initialize.
        //    Debug.Log("calling");
        //    AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
        //    //AppData.InitializeRobot();
        //}
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
       
        // Attach PLUTO button event
        MarsComm.OnButtonReleased += OnPlutoButtonReleased;

        //checking time scale 
        if (Time.timeScale == 0)
        {
            Time.timeScale = 1;
        }
        exit.onClick.AddListener(OnExitButtonClicked);
        nextButton.onClick.AddListener(OnNextButtonClicked);
        UpdateMovementToggleButtons();
        StartCoroutine(DelayedAttachListeners());
        nextButton.gameObject.SetActive(false); // Hide
        supportIndicator.value = 0;

    }

    void Update()
    {
        if(!File.Exists($"{DataManager.directoryAssessmentData}/{DataManager.SupportCalibrationFileName}"))
            //SceneManager.LoadScene(assessmentScene);

        //To initiate the Mars
        //if (MarsComm.desThree < AppData.ArmSupportController.MARS_ACTIVATED && ACTIVATE)
        //    AppData.ArmSupportController.initiate();
     
        ////To Deactivate the Mars
        //if(MarsComm.desThree >= AppData.ArmSupportController.MARS_ACTIVATED && DEACTIVATE)
        //{ 
        //    MarsComm.onclickRealease();
        //    if (MarsComm.desThree == 0)
        //    {
        //        DEACTIVATE = false;
        //    }
        //}
           

        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.A))
        {
            SceneManager.LoadScene(assessmentScene);

            //To check for last Assessment DATE

            //if (!File.Exists(DataManager.filePathAssessmentData))
            //{
            //    AppLogger.LogInfo("Assessment Mode Activated");
            //    SceneManager.LoadScene(assessmentScene);
            //}
            //else if (AppData.returnLastAssesment() > 7)
            //{
            //    AppLogger.LogInfo("Assessment Mode Activated");
            //    SceneManager.LoadScene(assessmentScene);
            //}
            //else
            //{
            //    AppLogger.LogWarning("Assessment mode cannot be open often");
            //}
           
            
        }
        // Check if a scene change is needed.
        if (changeScene == true)
        {
            shAng = MarsComm.angleOne;
            LoadNextScene();
            changeScene = false;
        }
       //updateGUI();
       
    }
    //public void updateGUI()
    //{
    //    if (MarsComm.desThree == AppData.ArmSupportController.MARS_ACTIVATED)//2005
    //    {
    //        ACTIVATE = false;
    //        gainMessageText.text = "READY TO ACTIVATE SUPPORT";
    //    }
    //    if (MarsComm.desThree == AppData.ArmSupportController.ROBOT_ACTIVE_WITH_MARS)//2006
    //    {
           
    //        gainMessageText.text = $"GAIN - {AppData.ArmSupportController.getGain()} %";
    //        supportIndicator.value = MarsComm.desOne;
    //        nextButton.gameObject.SetActive(true);  // Show
    //    }
    //    if (MarsComm.desThree == AppData.ArmSupportController.SEND_ARM_WEIGHT)//2004
    //    {
    //        gainMessageText.text = "ACTIVATING...";
    //        nextButton.gameObject.SetActive(false);  // hide
    //    }
    //    if(MarsComm.desThree<=2003)
    //    {
    //        gainMessageText.text = "ACTIVATE-MARS";//2003 OR 0
    //        nextButton.gameObject.SetActive(false);  // hide
    //    }
    //}
    private void UpdateMovementToggleButtons()
    {
        foreach (Transform child in movementSelectGroup.transform)
        {
            Toggle toggleComponent = child.GetComponent<Toggle>();
            bool isPrescribed = AppData.Instance.userData.movementMoveTimePrsc[toggleComponent.name] > 0;
            // Hide the component if it has no prescribed time.
            toggleComponent.interactable = isPrescribed;
            toggleComponent.gameObject.SetActive(isPrescribed);
            // Update the time trained in the timeLeft component of toggleCompoent.
            Transform timeLeftTransform = toggleComponent.transform.Find("timeLeft");
            if (timeLeftTransform != null)
            {
                // Get the TextMeshPro component from the timeLeft GameObject
                TextMeshProUGUI timeLeftText = timeLeftTransform.GetComponent<TextMeshProUGUI>();
                if (timeLeftText != null)
                {
                    // Set the text to your desired value
                    timeLeftText.text = $"{AppData.Instance.userData.getTodayMoveTimeForMovement(toggleComponent.name)} / {AppData.Instance.userData.movementMoveTimePrsc[toggleComponent.name]} min";
                }
                else
                {
                    Debug.LogError("TextMeshProUGUI component not found in timeLeft GameObject.");
                }
            }
            else
            {
                Debug.LogError("timeLeft GameObject not found in " + toggleComponent.name);
            }
        }
    }


    IEnumerator DelayedAttachListeners()
    {
        yield return new WaitForSeconds(1f);  
        AttachToggleListeners();
    }

    void AttachToggleListeners()
    {
        foreach (Transform child in movementSelectGroup.transform)
        {
            Toggle toggleComponent = child.GetComponent<Toggle>();
            if (toggleComponent != null)
            {
                toggleComponent.onValueChanged.AddListener(delegate { CheckToggleStates(); });
            }
        }
    }

    void CheckToggleStates()
    {
        string selectedMovement;
        foreach (Transform child in movementSelectGroup.transform)
        {
            Toggle toggleComponent = child.GetComponent<Toggle>();
            if (toggleComponent != null && toggleComponent.isOn)
            {
                ////for tuk-tuk only
                initialAngle = MarsComm.angleOne;
                toggleSelected = true;
                selectedMovement = child.name;
                nextScene = AppData.selectGame[MarsDefs.getMovementIndex(selectedMovement)];
                AppData.selectedGame = nextScene;
                Debug.Log(nextScene);
                AppLogger.LogInfo($"Selected '{selectedMovement}'.");
                break;
            }
        }
    }
    public void onclickActivateMarsWithFullSupport()
    {
        //AppData.ArmSupportController.UseFullWeightSupport();
    }
    public void onclickActivateMarsWithHalfSupport()
    {
        //AppData.ArmSupportController.UseHalfWeightSupport();
    }
    public void onclickActivateMarsWithNoSupport()
    {
        //AppData.ArmSupportController.UseNoWeightSupport();
    }
    public void initiateSupportSystem()
    {
        ACTIVATE = true;
    }
    public void OnPlutoButtonReleased()
    {
        //check support is activated or not
        //if (MarsComm.desThree != AppData.ArmSupportController.ROBOT_ACTIVE_WITH_MARS)
        //    return;

        if (toggleSelected)
        {


            changeScene = true;
            toggleSelected = false;
        }
        else
        {
            Debug.LogWarning("Select at least one toggle to proceed.");
        }
    }

    void LoadNextScene()
    {
        AppLogger.LogInfo($"Switching scene to '{nextScene}'.");
        SceneManager.LoadScene(nextScene);

    }

    IEnumerator LoadSummaryScene()
    {
        AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(exitScene);

        while (!asyncLoad.isDone)
        {
            yield return null;
        }
    }
    public void onclickDeactivateMars()
    {
        if (MarsComm.SUPPORT > 0.10f)
        {
            DeactivateMessageText.text = "To Deacitvate, Activate NS 0%...";
            return;
        }
        DEACTIVATE = true;
        
    }
    private void OnExitButtonClicked()
    {
        //if (MarsComm.desThree>=AppData.ArmSupportController.MARS_ACTIVATED)
        //{
        //    DeactivateMessageText.text = "To quit, Deactivate Mars...";
        //    return;
        //}
           
        StartCoroutine(LoadSummaryScene());
    }
    private void OnNextButtonClicked()
    {
        if (toggleSelected)
        {
            LoadNextScene();
            toggleSelected = false;
        }
    }
    private void OnDestroy()
    {
        if (JediComm.isMars) 
        {
            MarsComm.OnButtonReleased -= OnPlutoButtonReleased;
        }
    }
    private void OnApplicationQuit()
    {
        //MarsComm.OnButtonReleased -= onMarsButtonReleased;
    }
}

