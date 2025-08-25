using UnityEngine;
using UnityEngine.SceneManagement;
using TMPro;
using UnityEngine.UI;


public class pongGameController : MonoBehaviour {

    public static pongGameController instance;

    GameObject[] pauseObjects, finishObjects;
	public BoundController rightBound;
	public BoundController leftBound;

    public Image SupportSlider;
    public TextMeshProUGUI support;
    public Text timerTxt, pointCounter;
    public GameObject exitBtn;

    public bool isPaused  = false;
    public bool buttonPressed = false;
    public bool playerWon, enemyWon;
    public AudioClip[] audioClips; // winlevel loose

    public int enemyScore, playerScore;
    public float trialTimeLeft, eventDelayTimer ,trialDuration;

    // Game score related variables.
    public int nTargets = 0;
    public int nSuccess = 0;
    public int nFailure = 0;

    // Target and player positions
    public Vector3? TargetPosition { get; private set; }
    public Vector3 PlayerPosition { get; private set; }

    //pong game events and related variables.
    public enum GameStates
    {
        WAITING = 0,
        START,
        STOP,
        PAUSED,
        SPAWNBALL,
        MOVE,
        SUCCESS,
        FAILURE,
        DONE
    }
    private GameStates _gameState;
    public GameStates gameState
    {
        get => _gameState;
        private set => _gameState = value;
    }
    private GameStates _prevGameState = GameStates.WAITING;

    public bool isGameStarted { get; private set; } = false;
    public bool isGameFinished { get; private set; } = false;
    public bool isGamePaused { get; private set; } = false;
    public bool isBallSpawned { get; private set; } = false;
    public bool isBallHitted { get; private set; } = false;
    public bool isBallMissed { get; private set; } = false;
  
    public bool runOnce = false;

    public void Awake()
    {
        instance = this;
    }
    void Start () {
       
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        pauseObjects = GameObject.FindGameObjectsWithTag("ShowOnPause");
		finishObjects = GameObject.FindGameObjectsWithTag("ShowOnFinish");
		hideFinished();
        gameState = GameStates.WAITING;
		
	}
	
	void Update () {


        pointCounter.text = enemyScore + "\t\t\t" +playerScore;
        if (timerTxt != null)
        {
            timerTxt.text = "Time:" + Mathf.CeilToInt(trialTimeLeft).ToString() + "s"; // Show remaining time
        }

        //uses p or marsButton to pause and unpause the game

        if ((Input.GetKeyDown(KeyCode.P) && !isGameFinished) || (buttonPressed && !isGameFinished))
        {
            if(gameState == GameStates.WAITING && buttonPressed)
            {
                isGameStarted = true;
                buttonPressed = false;
                return;
            }
            if (!isPaused)
            {
                pauseGame();
            }
            else
            {
                resumeGame();
               
            }
            buttonPressed = false;
        }
        if ((isGameFinished && Input.GetKeyDown(KeyCode.P)) || (isGameFinished && buttonPressed && gameState == GameStates.STOP))
        {
            Reload();
            buttonPressed = false;
        }

        updateMarsSupportUI();
	}
    public void FixedUpdate()
    {
        MarsComm.sendHeartbeat();
        RunStateMachine();
        if (IsGamePlaying())
        {
            TargetPosition = GameObject.FindGameObjectWithTag("Target").transform.position;
            PlayerPosition = GameObject.FindGameObjectWithTag("Player").transform.position;
        }
    }
    public void RunStateMachine()
    {
        if (isGamePaused) pauseGame();
        else if (gameState == GameStates.PAUSED) resumeGame();
        if (IsGamePlaying())trialTimeLeft -= Time.deltaTime;
      
        bool isTimeUp = trialTimeLeft < 0;
        switch (gameState)
        {
            case GameStates.WAITING:
                showPaused();
                if (isGameStarted) gameState = GameStates.START;
                break;
            case GameStates.START:
                hidePaused();
                startGame();
                break;
            case GameStates.SPAWNBALL:
                nTargets++;
                gameState = GameStates.MOVE;
                break;
            case GameStates.MOVE:
                if (isBallHitted) gameState = GameStates.SUCCESS;
                if (isBallMissed) gameState = GameStates.FAILURE;
                break;
            case GameStates.PAUSED:
                Debug.Log(isGamePaused);
                break;
            case GameStates.SUCCESS:
            case GameStates.FAILURE:
                if (eventDelayTimer <= 0f)
                {
                    eventDelayTimer = 0.05f;
                }
                else
                {
                    eventDelayTimer -= Time.deltaTime;
                    if (eventDelayTimer <= 0f)
                    {
                        // Wait for the gamestate to be logged.
                        isBallHitted = false;
                        isBallMissed = false;
                        gameState = isTimeUp ? GameStates.STOP : GameStates.SPAWNBALL;
                        runOnce = false;
                    }
                }
                break;
            case GameStates.STOP:
                endGame();
                break;
        }

    }

    public void startGame()
    {
        AppData.Instance.StartNewTrial();
        trialDuration = 60f;
        nTargets = 0;
        nSuccess = 0;
        nFailure = 0;
        //Trial Time
        trialTimeLeft = trialDuration;
        gameState = GameStates.SPAWNBALL;
    }
    public void endGame()
    {
        if (!isGameFinished)
        {
            Debug.Log(nTargets);
            Debug.Log(nSuccess);
            Debug.Log(nFailure);
            showFinished();
            float gameTime = trialDuration - trialTimeLeft;
            Others.gameTime = (gameTime < trialDuration) ?(int) gameTime : trialDuration;
            AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);
        }
     
       isGameFinished = true;
    }
    private void pauseGame()
    {
        _prevGameState = gameState;
        gameState = GameStates.PAUSED;
        Time.timeScale = 0;
        isGamePaused = true;
        isPaused = true;
        showPaused();
        exitBtn.SetActive(false);
    }
    public void ExitGame()
    {

        if (gameState == GameStates.STOP || gameState == GameStates.WAITING)
        {
                
            SceneManager.LoadScene("CHOOSEMOVEMENT");
        }
        else
        {
            gameState = GameStates.STOP;
            endGame();
            SceneManager.LoadScene("CHOOSEMOVEMENT");
        }
        
    }
    private void resumeGame()
    {
        gameState = _prevGameState;
        Time.timeScale = 1;
        isGamePaused = false;
        isPaused = false;
        hidePaused();
        exitBtn.SetActive(true);
       
    }
    public bool IsGamePlaying()
    {
        return gameState != GameStates.WAITING
            && gameState != GameStates.PAUSED
            && gameState != GameStates.STOP;
    }
    public void BallHitted()
    {
        isBallHitted = true;
        isBallMissed = false;
        nSuccess++;
    }

    public void BallMissed()
    {
        isBallHitted = false;
        isBallMissed = true;
        nFailure++;
    }
    public void updateMarsSupportUI()
    {
        //support.text = $"Support : {AppData.ArmSupportController.getGain()}%";
        //SupportSlider.fillAmount = MarsComm.SUPPORT;
    }
    public void onMarsButtonReleased()
    {
        AppLogger.LogInfo("Mars button released.");
        buttonPressed = true;
      
    }
    public void Reload()
    {
        playerScore = enemyScore = 0;
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }

    public void showPaused(){
		foreach(GameObject g in pauseObjects){
			g.SetActive(true);
		}
	}


	public void hidePaused(){
		foreach(GameObject g in pauseObjects){
			g.SetActive(false);
		}
	}

	public void showFinished(){

        foreach (GameObject g in finishObjects){
			g.SetActive(true);
		}
	}
	
	public void hideFinished(){
		foreach(GameObject g in finishObjects){
			g.SetActive(false);
		}
	}
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }


}
