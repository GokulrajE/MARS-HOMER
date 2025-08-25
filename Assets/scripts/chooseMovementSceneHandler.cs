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
    public GameObject marsActivation;
    public Button nextButton;
    public Button exit;
    public static float initialAngle;
    private string nextScene;
    private string exitScene = "SUMMARY";
    private string assessmentScene = "ASSESSROM";
    public static float shAng;
    //flags
    private static bool changeScene = false;
    private bool toggleSelected = false;
    public Text message;
    public Text SetAWSMessage;
   
       
    //Game names
    public static string[] selectGame = { "space_shooter_home", "pong_game", "FlappyGame" };
    void Start()
    {

    
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
 

        AttachCallbacks();

        UpdateMovementToggleButtons();

        StartCoroutine(DelayedAttachListeners());

        nextButton.gameObject.SetActive(false); 


    }

    void Update()
    {
        MarsComm.sendHeartbeat();
        AppData.Instance.transitionControl.enable();
        marsActivation.SetActive(AppData.Instance.transitionControl.isEnable);
        message.gameObject.SetActive(MarsComm.CONTROLTYPE[MarsComm.controlType] == "AWS");
        SetAWSMessage.gameObject.SetActive(MarsComm.CONTROLTYPE[MarsComm.controlType] != "AWS");

        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.A))
        {
            if (AppData.Instance.selectedMovement == null)
            {
                message.text = "Please Select the Movement !!..";
                return;
            }

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
                toggleSelected = true;
                AppData.Instance.SetMovement(child.name);
                nextScene = selectGame[MarsDefs.getMovementIndex(AppData.Instance.selectedMovement.name)];
                AppData.Instance.SetGame(nextScene);
                if(AppData.Instance.selectedGame != selectGame[2])
                {
                    if (AppData.Instance.selectedMovement.CurrentAromFWS == null
                       || AppData.Instance.selectedMovement.CurrentAromHWS == null
                       || AppData.Instance.selectedMovement.CurrentAromNWS == null
                       )nextScene = assessmentScene;
                   
                }
                else
                {
                    initialAngle = MarsComm.angle1;
                }
                message.text = "Press Mars Button to move Next Scene";
                Debug.Log(nextScene);
                AppLogger.LogInfo($"Selected '{AppData.Instance.selectedMovement.name}'.");
                break;
            }
        }
    }
  
    public void OnMarsButtonReleased()
    {
        if (toggleSelected && MarsComm.CONTROLTYPE[MarsComm.controlType]=="AWS")
        {
            changeScene = true;
            toggleSelected = false;
        }
        else
        {
            //message.text = "Please Select the Movement !!..";
            Debug.LogWarning("Select at least one toggle to proceed.");
        }

        if (AppData.Instance.transitionControl.readyToChange)
        {
            AppData.Instance.transitionControl.setFWS();
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
   
    private void OnExitButtonClicked()
    {

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
      
            MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
        
    }
    private void OnApplicationQuit()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
}

