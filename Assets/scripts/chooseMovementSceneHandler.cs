using UnityEngine;
using UnityEngine.UI;
using TMPro;
using UnityEngine.SceneManagement;
using System.Collections;
using System.IO;
using System;
using UnityEngine.Rendering.Universal;


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
        if (AppData.Instance.userData.dTableConfig == null)
        {
            // Inialize the logger
            AppLogger.StartLogging(SceneManager.GetActiveScene().name);
            // Initialize.
            Debug.Log("calling");
            //AppData.InitializeRobot();
        }
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
       
        

        //checking time scale 
        if (Time.timeScale == 0)
        {
            Time.timeScale = 1;
        }

        AttachCallbacks();

        UpdateMovementToggleButtons();

        StartCoroutine(DelayedAttachListeners());

        nextButton.gameObject.SetActive(false); // Hide
        //supportIndicator.value = 0;

    }

    void Update()
    {
        //NEED TO CHECK
        if(!File.Exists($"{DataManager.directoryAssessmentData}/{DataManager.SupportCalibrationFileName}"))
          SceneManager.LoadScene(assessmentScene);

       

        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.A))
        {
            SceneManager.LoadScene(assessmentScene);

            
        }
        //Check if a scene change is needed.
        if (changeScene == true)
        {
            shAng = MarsComm.angle1;
            LoadNextScene();
            changeScene = false;
        }


    }
  
    public void AttachCallbacks()
    {
        // Attach PLUTO button event
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
        exit.onClick.AddListener(OnExitButtonClicked);
        nextButton.onClick.AddListener(OnNextButtonClicked);

    }
   
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
        foreach (Transform child in movementSelectGroup.transform)
        {
            Toggle toggleComponent = child.GetComponent<Toggle>();
            if (toggleComponent != null && toggleComponent.isOn)
            {
                //for tuk-tuk only
                //initialAngle = MarsComm.angle1;
                toggleSelected = true;
                AppData.Instance.SetMovement(child.name);
                nextScene = AppData.selectGame[MarsDefs.getMovementIndex(AppData.Instance.selectedMovement.name)];
                AppData.Instance.SetGame(nextScene);
                Debug.Log(nextScene);
                AppLogger.LogInfo($"Selected '{AppData.Instance.selectedMovement.name}'.");
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
    public void OnMarsButtonReleased()
    {
        // check support is activated or not
        //if (MarsComm.desThree != AppData.ArmSupportController.ROBOT_ACTIVE_WITH_MARS)
        //    return;

        //if (toggleSelected)
        //{
           

        //    changeScene = true;
        //    toggleSelected = false;
        //}
        //else
        //{
        //    Debug.LogWarning("Select at least one toggle to proceed.");
        //}
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
            MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
        }
    }
    private void OnApplicationQuit()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
}

