using UnityEngine;
using System.Collections;
using UnityEngine.SceneManagement;
using NeuroRehabLibrary;
using TMPro;
using UnityEngine.UI;

public class UIManager : MonoBehaviour {
    private GameSession currentGameSession;
    //public RockVR.Video.VideoCapture vdc;
    GameObject[] pauseObjects, finishObjects;
	public BoundController rightBound;
	public BoundController leftBound;

    public Image SupportSlider;
    public TextMeshProUGUI support;
    public bool isFinished;
    public bool paused  = false;
    public bool buttonPressed = false;
    public bool playerWon, enemyWon;
    public AudioClip[] audioClips; // winlevel loose
    public int winScore = 7;
    public int win;
    public int mt;
    public static float playerMoveTime;
    // Use this for initialization
    void Start () {
        //AppData.InitializeRobot();
        //SessionManager.Initialize(DataManager.directoryPathSession);
        //SessionManager.Instance.Login();
        MarsComm.OnButtonReleased += onMarsButtonReleased;
        pauseObjects = GameObject.FindGameObjectsWithTag("ShowOnPause");
		finishObjects = GameObject.FindGameObjectsWithTag("ShowOnFinish");
		hideFinished();
		
		StartNewGameSession();
	}
	
	// Update is called once per frame
	void Update () {
      

		if(BoundController.enemyScore >= winScore && !isFinished){
			isFinished = true;
			enemyWon = true;
            Camera.main.GetComponent<AudioSource>().Stop();
            win = -1;
            isFinished = true;
            
            playAudio(1);
			playerWon = false;
            EndCurrentGameSession();
            gameData.StopLogging();
           
        }
        else if (BoundController.playerScore >= winScore && !isFinished
            ){
            Camera.main.GetComponent<AudioSource>().Stop();
           
            playAudio(0);
			isFinished = true;
			enemyWon = false;
            win = 1;
			playerWon = true;
            EndCurrentGameSession();
            gameData.StopLogging();

        }
        
        if (isFinished){
            Time.timeScale = 0;
            showFinished();
		}
	
		//uses the p button to pause and unpause the game
		if((Input.GetKeyDown(KeyCode.P)) && !isFinished || buttonPressed && !isFinished)
		{
			pauseControl();
            buttonPressed = false;
		}


		if(Time.timeScale == 0  && !isFinished){
			//searches through pauseObjects for PauseText
			foreach(GameObject g in pauseObjects){

                if (g.name == "PauseText")
					//makes PauseText to Active
					g.SetActive(true);
			}
		} else {
			//searches through pauseObjects for PauseText
			foreach(GameObject g in pauseObjects){
				if(g.name == "PauseText")
					//makes PauseText to Inactive
					g.SetActive(false);
			}
		}

        if (!isFinished&&!paused)
        {
            playerMoveTime += Time.deltaTime;
            Debug.Log(playerMoveTime + "playermovetime");
           
        }
        updateMarsSupportUI();
	}
    public void updateMarsSupportUI()
    {
        //support.text = $"Support : {AppData.ArmSupportController.getGain()}%";
        SupportSlider.fillAmount = MarsComm.SUPPORT;
    }
    public void onMarsButtonReleased()
    {
        AppLogger.LogInfo("Mars button released.");
        buttonPressed = true;
      
    }
    void StartNewGameSession()
    {
        currentGameSession = new GameSession
        {
            GameName = "ping_pong",
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
        SessionManager.Instance.mechanism(MarsDefs.Movements[2], currentGameSession);

    }
    void EndCurrentGameSession()
    {
        if (currentGameSession != null)
        {
            string trialDataFileLocation = AppData.trialDataFileLocation;
            string gameParameter = "pass_game_parameter";
            SessionManager.Instance.SetGameParameter(gameParameter, currentGameSession);
            SessionManager.Instance.SetTrialDataFileLocation(trialDataFileLocation, currentGameSession);
            mt = (int)playerMoveTime;
            SessionManager.Instance.moveTime(mt.ToString(), currentGameSession);
            SessionManager.Instance.EndGameSession(currentGameSession);
        }
    }
    //Reloads the Level
    public void LoadScene(string sceneName)
	{
        EndCurrentGameSession();
        Application.LoadLevel(sceneName);
	}

	//Reloads the Level
	public void Reload(){
		
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
	}
    void playAudio(int clipNumber)
    {
        AudioSource audio = GetComponent<AudioSource>();
        audio.clip = audioClips[clipNumber];
        audio.Play();

    }
    //controls the pausing of the scene
    public void pauseControl(){
		if(Time.timeScale == 1)
		{
			Time.timeScale = 0;
			showPaused();
		} else if (Time.timeScale == 0){
			Time.timeScale = 1;
			hidePaused();
		}
	}
	
	//shows objects with ShowOnPause tag
	public void showPaused(){
		foreach(GameObject g in pauseObjects){
			g.SetActive(true);
		}
	}

	//hides objects with ShowOnPause tag
	public void hidePaused(){
		foreach(GameObject g in pauseObjects){
			g.SetActive(false);
		}
	}

	//shows objects with ShowOnFinish tag
	public void showFinished(){
      

        foreach (GameObject g in finishObjects){
			g.SetActive(true);
		}
	}
	
	//hides objects with ShowOnFinish tag
	public void hideFinished(){
		foreach(GameObject g in finishObjects){
			g.SetActive(false);
		}
	}
    private void OnDestroy()
    {
        MarsComm.OnButtonReleased -= onMarsButtonReleased;
    }


}
