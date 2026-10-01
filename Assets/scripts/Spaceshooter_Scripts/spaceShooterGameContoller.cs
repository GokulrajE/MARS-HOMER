

using System.Diagnostics.Eventing.Reader;
using System.IO;
// using System.Numerics;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using static UnityEngine.GraphicsBuffer;
//using UnityEngine.UIElements;


public class SpaceShooterGameContoller : MonoBehaviour
{
    public static SpaceShooterGameContoller Instance { get; private set; }

    // List of scenes to change to.
    private readonly string robotCalibScene = "ROBOTCALIB";
    private readonly string marsSetUp = "MARSSETUP";
    public readonly string moveSelect = "CHOOSEMOVE";
    private int[] scores;
    public GameObject gameOverPanel;
    public AudioClip[] bgmClip;
    public AudioSource bgAudioSource;
    public TextMeshProUGUI timerText;
    public TextMeshProUGUI scoreText;
    public GameObject gameSpeedControl;
    public GameObject startImage;
    public GameObject PauseImage;
    public float smoothFactor = 5f;
    public GameObject newSpaceshipPanel;
    public GameObject reminderPanel;
    public GameObject celebrationPanle;
    public TextMeshProUGUI scoreComparisonTxt;
    public TextMeshProUGUI yesterdayScoreTxt;
    public TextMeshProUGUI todayScoreTxt;
    public TextMeshProUGUI starCount;
    public GameObject GameOverStar;
    public GameObject star;
    public int _starCount;
    
    public bool Levelunlocked = false;
    public float targetTime;
    private float gameTimeLeft;
    public static bool changeScene = false;
    private float eventDelayTimer = 0f; 
    // private float gameSpeed = 1f;
    private float targetSpeed;
  
    private bool runOnce = false;

    // Game score related variables.
    public int nTargets = 0;
    public int nSuccess = 0;
    public int nFailure = 0;

    public bool isGameStarted { get; private set; } = false;
    public bool isGameFinished { get; private set; } = false;
    public bool isSuccess { get; private set; } = false;
    public bool isGamePaused { get; private set; } = false;
    public bool isFailure { get; private set; } = false;
    private bool _targetResolved = false;

    public float gameDuration = MarsGameDefs.GAMEDURATION["SS"];
    public bool isInitialized { get; private set; } = false;

    public void setIsSuccess()
    {
        if (_targetResolved) return;
        _targetResolved = true;
        isSuccess = true;
        nSuccess++;
    }

    public void setIsFailure()
    {
        if (_targetResolved) return;
        _targetResolved = true;
        isFailure = true;
        nFailure++;
    }
    
    public enum GameStates
    {
        WAITING = 0,
        START,
        STOP,
        PAUSED,
        SPAWNASTROID,
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
            AppLogger.LogInfo($"Game state changed from {_prevGameState} to {_gameState}.");
        }
    }
 
    public Vector3 playerGamePosition {  get; private set; }   
    public Vector3? targetGamePosition { get; private set; }
    public Vector3? targetEndPointPosition { get; private set; }
    public GameObject targetObject;
    Vector3 gTarget;
    private void Awake()
    {
        MarsComm.sendHeartbeat();
        if (Instance == null) Instance = this;
        else Destroy(gameObject);
    }
    
    void Start()
    {
        MarsComm.sendHeartbeat();

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

        // If the robot is not calibrated go to the robot calib scene.
        if (MarsComm.CALIBRATION[MarsComm.calibration] == "NOCALIB")
        {
            SceneManager.LoadScene(robotCalibScene);
        }
        // If the robot is not in position control go to the mars setup scene.
        if (MarsComm.CONTROLTYPE[MarsComm.controlType] != "POSITION")
        {
            SceneManager.LoadScene(marsSetUp);
        }
        // Check if movement is selected.
        if (AppData.Instance.selectedMovement == null)
        {
            SceneManager.LoadScene(moveSelect);
        }
        else
        {
            // Reload session details to get the latest data.
            AppData.Instance.userData.readParseSessionData(DataManager.sessionFile);


            // Get game duration
            gameDuration = MarsGameDefs.GAMEDURATION["SS"];

            // Initialize the game speed controller.
            initializeGameSpeedController();
            gameSpeedControl.SetActive(false);

            // Initialize the game GUI.
            startImage.SetActive(true);
            PauseImage.SetActive(false);

            // Game start flag.
            isGameStarted = false;

            // Attach the MARS button callback.
            MarsComm.OnMarsButtonReleased += onMarsButtonReleased;

            // Initialize the player.
            GameObject.FindGameObjectWithTag("Player").GetComponent<SSPlayerController>().Initialize();
            GameObject.FindGameObjectWithTag("Player").GetComponent<SSPlayerFiringController>().Initialize();

            // Game ready to start.
            isInitialized = true;

            AppLogger.LogInfo("Space Shooter Game initialized.");
        }
        
        updateStarCount();
        scores = MarsGameDefs.Spaceshooter.GetScores();
        if (MarsGameDefs.Spaceshooter.IsAchievedToday()) star.GetComponent<Image>().color = Color.white;
        Debug.Log($"{scores[0]}/{scores[1]}");
        AppLogger.LogInfo($"scores - yesterDayScore:{scores[1]} | TodayScore{scores[0]}");
    }
    public void updateStarCount()
    {
        starCount.text = $"{AppData.Instance.selectedGame.cummulativeStars.ToString("D2")}";
    }
    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();

        // Nothing to do if not initialized
        if (!isInitialized) return;

        // Pause and Resume the game
        if (isGamePaused && gameState != GameStates.PAUSED) PauseGame();
        else if (!isGamePaused && gameState == GameStates.PAUSED) ResumeGame();

        // Update Timer (show remaining time)
        timerText.text = $"TIMER:{Mathf.CeilToInt(gameTimeLeft)}s";

        // Track Restart
        if (changeScene && gameState == GameStates.STOP)
        {
            restartGame();
            changeScene = false;
        }
        else
        {
            changeScene = false;
        }

        // Check of the game speed controller is to be shown.
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.G))
        {
            gameSpeedControl.SetActive(!gameSpeedControl.activeSelf);
        }
    }

    private void FixedUpdate()
    {
        // Nothing to do if not initialized
        if (!isInitialized) return;

        // Initialization is done.
        RunStateMachine();
        
        // Update the player and target positions.
        if (IsGamePlaying())
        {
            playerGamePosition = GameObject.FindGameObjectWithTag("Player").transform.position;
            if (GameObject.FindGameObjectWithTag("Asteroid") == null)
            {
                targetGamePosition = null;
                targetEndPointPosition = null;
            }
            else
            {
                targetGamePosition = GameObject.FindGameObjectWithTag("Asteroid").transform.position;
                targetEndPointPosition = new Vector3(
                0,
                    SSPlayerController.unityYToRobotY(GameObject.FindGameObjectWithTag("Asteroid").transform.position.y),
                    SSPlayerController.unityXToRobotZ(GameObject.FindGameObjectWithTag("Asteroid").transform.position.x)
                );
            }
        }
    }

    public bool IsGamePlaying()
    {
        return gameState != GameStates.WAITING
            && gameState != GameStates.PAUSED
            && gameState != GameStates.STOP;
    }

    public void RunStateMachine()
    {
        bool isGamePlaying = gameState != GameStates.WAITING && gameState != GameStates.PAUSED && gameState != GameStates.STOP;
        scoreText.text = "SCORE:" + nSuccess.ToString();
        bool isTimeUp = gameTimeLeft < 0;
        if (isGamePlaying&&!isTimeUp) gameTimeLeft -= Time.deltaTime;

        switch (gameState)
        {
            case GameStates.WAITING:
                if (isGameStarted) gameState = GameStates.START;
                break;
            case GameStates.START:
                startGame();
                gameState = GameStates.SPAWNASTROID;
                eventDelayTimer = 0.05f;
                runOnce = false;
                break;
            case GameStates.SPAWNASTROID:
                if (AsteroidSpawner.Instance == null) break;
                if (!runOnce)
                {
                    gTarget = AsteroidSpawner.Instance.SpawnAsteroid(
                        xMin: SSPlayerController.xScreenMin,
                        xMax: SSPlayerController.xScreenMax
                    );
                    // Update the game and endpoint target positions
                    targetGamePosition = gTarget;
                    targetEndPointPosition = new Vector3(
                        0,
                        SSPlayerController.unityYToRobotY(gTarget.y),
                        SSPlayerController.unityXToRobotZ(gTarget.x)
                    );
                    AsteroidFall.instance.setFallTime(AppData.Instance.selectedGame.gameParameter);
                   
                    nTargets++;
                    _targetResolved = false;
                    eventDelayTimer = 0.05f;
                    runOnce = true;
                }
                else
                {
                    eventDelayTimer -= Time.fixedDeltaTime;
                    if (eventDelayTimer <= 0f)
                    {
                        gameState = GameStates.MOVE;
                        runOnce = false;
                    }
                }
                break;
            case GameStates.MOVE:
                targetTime += Time.fixedDeltaTime;
                if (isSuccess)
                {
                    //Debug.Log($"{targetTime}targetTime");
                    gameState = GameStates.SUCCESS;
                    eventDelayTimer = 0.05f;
                    targetTime = 0f;
                }
                if (isFailure)
                {
                    
                    Debug.Log($"{targetTime}targetTime");
                    gameState = GameStates.FAILURE;
                    eventDelayTimer = 0.05f;
                    targetTime = 0f;
                }
                break;
            case GameStates.PAUSED:
                break;
            case GameStates.SUCCESS:
            case GameStates.FAILURE:
                eventDelayTimer -= Time.deltaTime;
                if (eventDelayTimer <= 0f)
                {
                    isFailure = false;
                    isSuccess = false;
                    gameState = isTimeUp ? GameStates.STOP : GameStates.SPAWNASTROID;
                    eventDelayTimer = 0.05f;
                    runOnce = false;
                }
                break;
            case GameStates.STOP:
                gameOver();
                break;
        }
    }

    public void onMarsButtonReleased()
    {
        // To pause, resume or restart the game.
        if (gameState == GameStates.WAITING) isGameStarted = true;
        else if (gameState != GameStates.STOP) isGamePaused = !isGamePaused;
        else if (gameState == GameStates.STOP && isGameFinished) changeScene = true;
    }
    
    public void PauseGame()
    {
        _prevGameState = gameState;
        gameState = GameStates.PAUSED;
        PauseImage.SetActive(true);
        isGamePaused = true;
        Time.timeScale = 0f;
    }

    public void ResumeGame()
    {
       
        Debug.Log($"prev GS :{_prevGameState}");
        isGamePaused = false;
        gameState = _prevGameState;
        Time.timeScale = 1f;
        PauseImage.SetActive(false);
       
    }

    public void gameOver()
    {
        if (!isGameFinished)
        {
            // Compute game time
            int gametime = (int)(gameDuration - gameTimeLeft);
            AppData.Instance.gameTime = gametime;
            // Stop the current game trial
            if ((scores[0] + nSuccess) > scores[1] && !AppData.Instance.selectedGame.isAchievedToday())
            {
                AppData.Instance.selectedGame.updateCummulativeStars();
                celebrationPanle.SetActive(true);
            }
            
            gameOverPanel.SetActive(!celebrationPanle.gameObject.activeSelf);
            AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);
            
            if (gameOverPanel.gameObject.activeSelf)
            {
                GameOverStar.SetActive(AppData.Instance.selectedGame.isAchievedToday());
                yesterdayScoreTxt.text = $"{scores[1]:D4}";
                todayScoreTxt.text = $"{(scores[0]+nSuccess):D4}";
            }
            if (celebrationPanle.gameObject.activeSelf)
            {
                updateStarCount();
                scoreComparisonTxt.text = $"{(scores[0] + nSuccess).ToString("D3")}";
            }
          
            AppLogger.LogInfo($"Space Shooter Game Over. Time: {gametime}s | Targets: {nTargets} | Hits: {nSuccess} | Misses: {nFailure}");
        }
        timerText.text = "Time: 0s";
        // Set game over state
        isGameFinished = true;
        bool isRequiredTrialsCompleted = AppData.Instance.selectedMovement.trialNumberDay == AppData.Instance.userData.moveTimePrsc[AppData.Instance.selectedMovement.name];
        if (isRequiredTrialsCompleted) { SceneManager.LoadSceneAsync("CHOOSEMOVE"); }
    }
    
    public void onClickExit()
    {
        if (gameState != GameStates.WAITING && gameState != GameStates.STOP)
        {
            gameOver();
        }
        gameState = GameStates.DONE;
        isGamePaused = false;
        Time.timeScale = 1f;
        SceneManager.LoadScene("CHOOSEMOVE");
    }
    
    public void startGame()
    {
        // Hide reminder panel if visible
        reminderPanel.SetActive(false);

        // Start a new Trail
        AppData.Instance.StartNewTrial();

        // Initialize targets, hits, and misses
        nSuccess = 0;
        nFailure = 0;
        nTargets = 0;

        // Trial success/failure.
        isFailure = false;
        isSuccess = false;

        // Set game duration.
        gameTimeLeft = gameDuration;
        AppLogger.LogInfo($"Space Shooter Game started for movement '{AppData.Instance.selectedMovement.name}'. Game Speed: {AppData.Instance.selectedGame.gameParameter} | Duration: {gameDuration}s");

        // Remove game over and start panel.
        gameOverPanel.SetActive(false);
        celebrationPanle.SetActive(false);
        startImage.SetActive(false);
        //Set bgm based on location
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
    }

    public void restartGame()
    {
        string currentSceneName = SceneManager.GetActiveScene().name;
        AppLogger.LogInfo($"The Game is Restarted '{currentSceneName}'.");
        SceneManager.LoadSceneAsync(currentSceneName);
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
    }
  
    private void OnApplicationQuit()
    {
        Application.Quit();
        ConnectToRobot.disconnect();
    }
}
