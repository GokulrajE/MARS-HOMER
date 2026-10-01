using UnityEngine;
using UnityEngine.SceneManagement;
using TMPro;
using UnityEngine.UI;
using System.ComponentModel;
using System.Security.Policy;


public class pongGameController : MonoBehaviour {

    public static pongGameController Instance;

    GameObject[] finishObjects;
	public BoundController rightBound;
	public BoundController leftBound;
    public Text timerTxt, pointCounter;
    public Text gameSpeedTxt;
    public GameObject exitBtn;
    public GameObject gameSpeedControl;
    public TextMeshProUGUI cummulativeScoreTxt;
    public bool isPaused  = false;
    public bool buttonPressed = false;
    public bool playerWon, enemyWon;
    public AudioClip[] audioClips; // winlevel loose
    public AudioClip[] bgmClip;
    public AudioSource bgAudioSource;
    public GameObject reminderPanel;
    public GameObject pauseImage;
    public GameObject startImage;
    public int enemyScore, playerScore;
    public float gameTimeLeft,
                eventDelayTimer,
                gameDuration,
                gameSpeed;
    public EnemyController enemy;
    public BallController ballSpeed;
    // Game score related variables.
    public int nTargets = 0;
    public int nSuccess = 0;
    public int nFailure = 0;

    public GameObject celebrationPanle;
    public TextMeshProUGUI scoreComparisonTxt;
    public TextMeshProUGUI yesterdayScoreTxt;
    public TextMeshProUGUI todayScoreTxt;
    public TextMeshProUGUI starCount;
    public GameObject GameOverStar;
    public GameObject star;
    public int _starCount;
    private int[] scores;
    

    // Target and player positions
    public Vector3? targetPosition { get; private set; }
    public Vector3 playerPosition { get; private set; }

    public Vector3 playerGamePosition {  get; private set; }   
    public Vector3? targetGamePosition { get; private set; }
    public Vector3? targetEndPointPosition { get; set; }

    public GameObject targetObject;
    private  GameObject target;

    private bool gameSpeedChanged = false;
    public float targetTime;

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
    private GameStates _prevGameState = GameStates.WAITING;
    public GameStates gameState
    {
        get => _gameState;
        private set
        {
            _prevGameState = _gameState;
            _gameState = value;
            //AppLogger.LogInfo($"Game state changed from {_prevGameState} to {_gameState}.");
        }
    }

    public bool isGameStarted { get; private set; } = false;
    public bool isGameFinished { get; private set; } = false;
    public bool isGamePaused { get; private set; } = false;
    public bool isBallSpawned { get; private set; } = false;
    public bool isBallHitted { get; private set; } = false;
    public bool isBallMissed { get; private set; } = false;
    public bool restartGame { get; private set; } = false;

    public bool isGamePlaying => gameState == GameStates.MOVE
            || gameState == GameStates.SPAWNBALL
            || gameState == GameStates.SUCCESS
            || gameState == GameStates.FAILURE
            ;
               

    public void Awake() => Instance = this;
    
    void Start ()
    {
        MarsComm.sendHeartbeat();
        // Get the objects to show/hide on pausing or finishing the game.
       
		finishObjects = GameObject.FindGameObjectsWithTag("ShowOnFinish");
        hideFinished();

        // Initialize game state.
        gameState = GameStates.WAITING;

        // Read session data.
        AppData.Instance.userData.readParseSessionData(DataManager.sessionFile);

        // Initialize the game GUI.
        startImage.SetActive(true);

        // Initialize the game speed controller.
        initializeGameSpeedController();
        gameSpeedControl.SetActive(false);
        

        //switch the Player based on TrainingSide is Left
        if (AppData.Instance.userData.limb == 2)
        {
            GameObject player = GameObject.FindGameObjectWithTag("Player");
            GameObject Enemy = GameObject.FindGameObjectWithTag("Enemy");
            player.transform.position = new Vector3(-6, 0, 0);
            Enemy.transform.position = new Vector3(7, 0, 0);
        }

        // Attach event handler for Mars button release.
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        updateStarCount();
        scores = MarsGameDefs.PingPong.GetScores();
        Debug.Log($"{scores[0]}/{scores[1]}");
        if (MarsGameDefs.PingPong.IsAchievedToday()) star.GetComponent<Image>().color = Color.white;
        AppLogger.LogInfo($"scores - yesterDayScore:{scores[1]} | TodayScore{scores[0]}");
    }
    public void updateStarCount()
    {
        starCount.text = $"{AppData.Instance.selectedGame.cummulativeStars.ToString("D2")}";
    }

    void Update()
    {
        MarsComm.sendHeartbeat();
        // Check if the game is paused or to be paused/resumed.
        if (isGamePaused && gameState != GameStates.PAUSED) pauseGame();
        else if (!isGamePaused && gameState == GameStates.PAUSED) resumeGame();
        // Update the point counter.
        if (isGamePlaying)
        {
            pointCounter.text = AppData.Instance.userData.limb == 1?enemyScore + "\t\t\t" + playerScore: playerScore + "\t\t\t" + enemyScore;
            timerTxt.text = "Time:" + Mathf.CeilToInt(gameTimeLeft).ToString() + "s";
        }

        // Check if the game is to be restarted.
        if (restartGame)
        {
            Reload();
            restartGame = false;
        }

        // Update game speed.
        if (gameSpeedChanged)
        {
            gameSpeedChanged = false;
            BallController.instance.ballSpeed = AppData.Instance.selectedGame.gameSpeed;
            gameSpeed = AppData.Instance.selectedGame.gameSpeed;
        }
        
        // Check of the game speed controller is to be shown.
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.G))
        {
            gameSpeedControl.SetActive(!gameSpeedControl.activeSelf);
        }
    }

    public void FixedUpdate()
    {
        MarsComm.sendHeartbeat();

        // Run the state machine
        RunStateMachine();


        if (isGamePlaying)
        {
            playerGamePosition = GameObject.FindGameObjectWithTag("Player").transform.position;
            target = GameObject.FindGameObjectWithTag("Target");
            if (target == null)
            {
                targetGamePosition = null;
                targetEndPointPosition = null;
            }
            else
            {
                targetGamePosition =  target.transform.position;
                targetEndPointPosition = new Vector3(0, 
                                                     PongPlayerController.unityYToRobotY(target.transform.position.y), 
                                                     PongPlayerController.unityXToRobotZ(target.transform.position.x)
                                                     );
            }
        }
    }
    
    public void RunStateMachine()
    {
        // Check if the trial time is up.
        bool isTimeUp = gameTimeLeft < 0;

        // Update the trial timer if the game is playing.
        if (isGamePlaying && nTargets > 0 && isActiveAndEnabled&&!isTimeUp) gameTimeLeft -= Time.deltaTime;
        
       
        switch (gameState)
        {
            case GameStates.WAITING:
              
                if (isGameStarted) gameState = GameStates.START;
                break;
            case GameStates.START:
               
                startGame();
                break;
            case GameStates.SPAWNBALL:
                gameState = GameStates.MOVE;
                break;
            case GameStates.MOVE:
                targetTime += Time.fixedDeltaTime;
                if (isBallHitted)
                {
                    nSuccess++;
                    gameState = GameStates.SUCCESS;
                    eventDelayTimer = 0.05f;
                }
                else if (isBallMissed)
                {
                    nFailure++;
                    gameState = GameStates.FAILURE;
                    eventDelayTimer = 0.05f;
                }
                break;
            case GameStates.PAUSED:
                break;
            case GameStates.SUCCESS:
            case GameStates.FAILURE:
                eventDelayTimer -= Time.deltaTime;
                if (eventDelayTimer <= 0f)
                {
                    isBallHitted = false;
                    isBallMissed = false;
                    gameState = isTimeUp ? GameStates.STOP : GameStates.SPAWNBALL;
                    eventDelayTimer = 0.05f;
                }
                break;
            case GameStates.STOP:
                gameOver();
                break;
        }

    }

    public void startGame()
    {
        // Disable the reminder panel if it is showing.
        if (reminderPanel.activeSelf) reminderPanel.SetActive(false);

        // Start the new trial.
        AppData.Instance.StartNewTrial();
        
        // Set bgm based on location
        switch (AppData.Instance.userData.GetDeviceLocation())
        {
            case "Ranipet":
                bgAudioSource.clip = bgmClip[0];
                bgAudioSource.Play();
                break;
            case "Manipal":
                bgAudioSource.clip = bgmClip[1];
                bgAudioSource.Play();
                break;
            case "Ludhiana":
                bgAudioSource.clip = bgmClip[2];
                bgAudioSource.Play();
                break;
            default:
                bgAudioSource.clip = bgmClip[0];
                bgAudioSource.Play();
                break;
        }
        
        // Set the trial duration
        gameDuration = MarsGameDefs.GAMEDURATION[AppData.Instance.selectedGame.name];
        nTargets = 0;
        nSuccess = 0;
        nFailure = 0;
        
        // Trial Time
        gameTimeLeft = gameDuration;
        startImage.SetActive(false);
        // Spawing the ball.
        gameState = GameStates.SPAWNBALL;
        gameSpeed = AppData.Instance.selectedGame.gameSpeed;
    }

    public void gameOver()
    {
        if (!isGameFinished)
        {
            // Compute game time
            int gameTime = (int)(gameDuration - gameTimeLeft);
            AppData.Instance.gameTime = gameTime;
            // Stop the current game trial
            if ((scores[0] + nSuccess) > scores[1] && !AppData.Instance.selectedGame.isAchievedToday())
            {
                AppData.Instance.selectedGame.updateCummulativeStars();
                celebrationPanle.SetActive(true);
            }

            AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);

            if (!celebrationPanle.gameObject.activeSelf)
            {
                showFinished();
                GameOverStar.SetActive(AppData.Instance.selectedGame.isAchievedToday());
                yesterdayScoreTxt.text = $"{scores[1]:D4}";
                todayScoreTxt.text = $"{(scores[0] + nSuccess):D4}";
            }
            if (celebrationPanle.gameObject.activeSelf)
            {
                updateStarCount();
                scoreComparisonTxt.text = $"{(scores[0] + nSuccess).ToString("D3")}";
            }
            
        }
        timerTxt.text = "Time: 0s";
        // Set game over state
       
        isGameFinished = true;

        //IF GAME PRESCRIBED TIME FINISHED , MOVE TO CHOOSEMOVEMENT SCENE TO PLAY FOR ANOTHER MOVEMENT
        bool isRequiredTrialsCompleted = AppData.Instance.selectedMovement.trialNumberDay == AppData.Instance.userData.moveTimePrsc[AppData.Instance.selectedMovement.name];
        if (isRequiredTrialsCompleted) { SceneManager.LoadSceneAsync("CHOOSEMOVE"); }
    }
    
    private void pauseGame()
    {
        gameState = GameStates.PAUSED;
        pauseImage.SetActive(isGamePaused);
       
        exitBtn.SetActive(false);
        Time.timeScale = 0;
    }

    private void initializeGameSpeedController()
    {
        // Hide game speed control initially
        gameSpeedControl.SetActive(false);

        GameSpeedController gsc = gameSpeedControl.GetComponent<GameSpeedController>();
        if (gsc == null) return;

        // Attach the buttons
        if (gsc.decreaseButton != null)
            gsc.decreaseButton.onClick.AddListener(() => changeGameSpeed(false));
        if (gsc.increaseButton != null)
            gsc.increaseButton.onClick.AddListener(() => changeGameSpeed(true));

        // Set the initial game speed
        //gsc.gameSpeedText.text = $"{AppData.Instance.selectedGame.gameSpeed:F2}";
    }
    
    public void changeGameSpeed(bool increase)
    {
        float _rs = AppData.Instance.selectedGame.reachSpeed;
        AppData.Instance.selectedGame.reachSpeed = _rs + (increase ? MarsGameDefs.REACH_SPEED_DELTA : -MarsGameDefs.REACH_SPEED_DELTA);
        AppData.Instance.annotation = $"RS:{AppData.Instance.selectedGame.reachSpeed:F3} | GS:{AppData.Instance.selectedGame.gameParameter:F3}";
        gameSpeedChanged = true;
    }

    public void ExitGame()
    {
        if (gameState != GameStates.WAITING && gameState != GameStates.STOP)
        {
            Time.timeScale = 1;
            isPaused = false;
            gameOver();
        }
        SceneManager.LoadScene("CHOOSEMOVE");
    }
    
    private void resumeGame()
    {
        gameState = _prevGameState;
        Time.timeScale = 1;
      
        pauseImage.SetActive(isGamePaused);
        exitBtn.SetActive(true);
    }

    public void BallReturned()
    {
        //Debug.Log($"{targetTime} targetTime");
        targetTime = 0;
        isBallHitted = false;
        isBallMissed = false;
        nTargets++;
        //Debug.Log(nTargets);
        enemyScore++;
    }

    public void BallHitted()
    {
        //Debug.Log($"{targetTime} targetTime");
        targetTime = 0;
        isBallHitted = true;
        isBallMissed = false;
        playerScore++;
    }

    public void BallMissed()
    {
        if (isBallHitted) return;
        isBallMissed = true;
    }

    public void onMarsButtonReleased()
    {
        // Act according to the current game state.
        if (gameState == GameStates.WAITING)
        {
            // Start the game.
            isGameStarted = true;
            isGamePaused = false;
            return;
        }
        else if (gameState != GameStates.STOP)
        {
            // Pause the game if it is currently playing.
            //pausegame = true;
            isGamePaused = !isGamePaused;
            return;
        }
        // Check if game is done. Then this is a request to restart the game.
        else if (gameState == GameStates.STOP)
        {
            // Restart the game.
            restartGame = true;
            return;
        }

    }
    
    public void Reload()
    {
        playerScore = enemyScore = 0;
        SceneManager.LoadSceneAsync(SceneManager.GetActiveScene().name);
    }

 //   public void showPaused()
 //   {
 //       foreach(GameObject g in pauseObjects)
 //       {
 //           g.SetActive(true);
 //       }
 //   }

	//public void hidePaused()
	//{
	//	foreach(GameObject g in pauseObjects)
	//	{
	//		g.SetActive(false);
	//	}
	//}

	public void showFinished()
    {
        foreach (GameObject g in finishObjects)
        {
            g.SetActive(true);
        }
    }

    public void hideFinished()
    {
        foreach (GameObject g in finishObjects)
        {
            g.SetActive(false);
        }
    }
    
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
}
