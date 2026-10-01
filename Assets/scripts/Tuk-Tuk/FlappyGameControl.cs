
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
// using Michsky.UI.ModernUIPack;
using Unity.VisualScripting;
using TMPro;


public class FlappyGameControl : MonoBehaviour
{
    public AudioClip[] winClip;
    public AudioClip[] hitClip;
    public AudioClip[] bgmClip;
    public AudioSource eventAudioSource;
    public AudioSource bgAudioSource;
    public TextMeshProUGUI ScoreText;
    public static FlappyGameControl Instance { get; private set; }
    public GameObject GameOverText;
    public GameObject[] pauseObjects, finishObjects;
    // public ProgressBar timerObject;

    bool birdDied = false;
    public bool gameOver = false;
    public float scrollSpeed = 0f;
    private int score;
    public BirdControl bc;

    enum AssessStates
    {
        DAY = 1,
        EVE = 2,
        NIGHT = 3
    };
    private GameObject[] detailObjects;

    public int _state;
    public int columnPoolSize = 5;
    private float MOVEDURATION =4f;
    private GameObject[] columns;
    public GameObject[] columnPrefab;
    public GameObject[] backgrounds;
    public Vector2 objectPoolPosition = new Vector2(-15, -25);
    private float spawnXposition = 16;
    private int CurrentColumn = 0;
    private GameObject[] top;
    private GameObject[] bottom;
    public GameObject StartButton, ResumeButton, PauseButton, ExitButton;
    public GameObject SuccessRateBanner;

    public GameObject promLeft, promRight, targetPointer;
    public Text prevSR, currSR,HS;
    bool setup;
    float prevSpawnTime;
    // Target and player positions
    // Target and player positions
    public Vector3? targetPosition { get; private set; }
    public Vector3 playerPosition { get; private set; }

    public Vector3 playerGamePosition {  get; private set; }   
    public Vector3? targetGamePosition { get; private set; }
    public Vector3? targetEndPointPosition { get; set; }

    public GameObject targetObject;
    private  GameObject target;
    private float PLAYSIZE;
    private float triaTimeLeft;
    private float targetTime;
    public int nTargets = 0;
    public int nSuccess = 0;
    public int nFailure = 0;
     public Text status, gameSpeedViewer;
    public enum GameStates
    {
        WAITING = 0,
        START,
        STOP,
        PAUSED,
        SPAWNTARGET,
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

        }
    }
    // Bunch of event flags
    public bool isGameStarted { get; private set; } = false;
    public bool isGameFinished { get; private set; } = false;
    public bool isGamePaused { get; private set; } = false;
        public bool isGamePlaying => gameState == GameStates.MOVE
            || gameState == GameStates.SPAWNTARGET
            || gameState == GameStates.SUCCESS
            || gameState == GameStates.FAILURE
            ;

    public bool isBallSpawned { get; private set; } = false;
    public bool isTargetHit { get; private set; } = false;
    public bool isTargetMissed { get; private set; } = false;
    public bool restartGame { get; private set; } = false;
   

    // Target and player positions.
    private float[] arom;
    private float[] prom, aprom;
    private float targetAngle;
    // private float targetPosition;
    public GameObject celebrationPanel;

    public GameObject aromLeft;
    public GameObject aromRight;
    private GameObject targetTemp;
    public GameObject HSC; //HighScoreCanvas
    public TextMeshProUGUI score1, timeLeftText;
    private float lastHighScore, eventDelayTimer = 0f, gameSpeed;
    private bool runOnce = false, changeScene = false;
    public Image loadingImage;
    public GameObject reminderPanel;

    private float targetPos;


    public GameObject gameSpeedControl, gameOverPanel;
    private GameSpeedController gsc = null;
    bool speedControlsVisible = false;
    public TextMeshProUGUI  finalScore;
    
    // public GameObject celebrationPanel;
    public TextMeshProUGUI scoreComparisonTxt;
    public TextMeshProUGUI yesterdayScoreTxt;
    public TextMeshProUGUI todayScoreTxt;
    public TextMeshProUGUI starCount;
    public GameObject GameOverStar, starLabel;
    public GameObject star;
    public int _starCount;
    private int[] scores;
    private bool gameSpeedChanged = false;
    private float gameDuration;
    
    public GameObject pauseImage;
    public GameObject startImage;


    void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
        }
        else if (Instance != null)
        {
            Destroy(gameObject);
        }

        float fullHeight = Camera.main.orthographicSize * 2f; // Full camera height in world units
        PLAYSIZE  = fullHeight * 0.8f; // 80% of the camera height
        
    }

    private void InitializeGame()
    {
        // reminderPanel = GameObject.FindGameObjectWithTag("ReminderPanel");
        if(AppData.Instance.selectedGame.isAchievedToday())starLabel.GetComponent<Image>().color = Color.white;

        gameOverPanel.SetActive(false);
        // Intialize game logic variables
        gameState = GameStates.WAITING;
        // Clear even flags.
        isGameStarted = false;
        isGameFinished = false;
        isGamePaused = false;
        isBallSpawned = false;
        isTargetHit = false;
        isTargetMissed = false;

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
        


        // Attach event handler for Mars button release.
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        updateStarCount();
        scores = MarsGameDefs.TukTuk.GetScores();
        Debug.Log($"{scores[0]}/{scores[1]}");

        AppLogger.LogInfo($"scores - yesterDayScore:{scores[1]} | TodayScore{scores[0]}");

    }

        

    public void changeGameSpeed(bool increase)
    {
        float _rs = AppData.Instance.selectedGame.reachSpeed;
        AppData.Instance.selectedGame.reachSpeed = _rs + (increase ? MarsGameDefs.REACH_SPEED_DELTA : -MarsGameDefs.REACH_SPEED_DELTA);
        AppData.Instance.annotation = $"RS:{AppData.Instance.selectedGame.reachSpeed:F3} | GS:{AppData.Instance.selectedGame.gameParameter:F3}";
        gameSpeedChanged = true;
    }
    
    public float AngleToScreen(float angle) =>  ( -3f + (angle - aprom[0]) * (PLAYSIZE) / (aprom[1] - aprom[0]));
    void Start()
    {
        detailObjects = GameObject.FindGameObjectsWithTag("detailViewer");
        pauseObjects = GameObject.FindGameObjectsWithTag("ShowOnPause");
        finishObjects = GameObject.FindGameObjectsWithTag("ShowOnFinish");

        setup = false;
        InitializeGame();
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

    public void updateStarCount()
    {
        starCount.text = $"{AppData.Instance.selectedGame.cummulativeStars.ToString("D2")}";
    }

    void Update()
    {
        MarsComm.sendHeartbeat();
      

        if (isGamePaused && gameState != GameStates.PAUSED) pauseGame();
        else if (!isGamePaused && gameState == GameStates.PAUSED) resumeGame();
           
        
            
        ScoreText.text = $"Score:{nSuccess}";
        

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
            gameSpeed = AppData.Instance.selectedGame.gameSpeed;
            UpdateScrollSpeed();

        }
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.G))
        {
            gameSpeedControl.SetActive(!gameSpeedControl.activeSelf);
        }

        if (!setup)
        {
            int y = UnityEngine.Random.Range(0, 3);
            _state = 0;
            columns = new GameObject[columnPoolSize];
            for (int i = 0; i < columnPoolSize; i++)
            {
                columns[i] = (GameObject)Instantiate(columnPrefab[_state], objectPoolPosition, Quaternion.identity);
            }
            top = GameObject.FindGameObjectsWithTag("Top");

            chooseBackground();
            setup = true;
        }
    }
    void FixedUpdate()
    {
        
        // Handle the current game state.
        RunGameStateMachine();

        // Update player and target positions
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
                targetGamePosition = target.transform.position;

                targetEndPointPosition = new Vector3(0,
                                                     BirdControl.Instance.unityYToRobotY(target.transform.position.y),
                                                     BirdControl.Instance.unityXToRobotZ(target.transform.position.x)
                                                     );
               
            }
        }
        prevSpawnTime += Time.deltaTime;
    }
    

    public void chooseBackground()
    {
        foreach (GameObject obj in backgrounds)
        {
            obj.SetActive(false);
        }
        backgrounds[_state].SetActive(true);
    }
    
    public void Reload()
    {
        SceneManager.LoadSceneAsync(SceneManager.GetActiveScene().name);
    }
    public void decreaseGameSpeed()
    {

        UpdateScrollSpeed();
       
    }
    private void UpdateScrollSpeed()
    {
        // Use finer scaling for scroll speed at lower increments
        float scrollFactor =  1f;
        scrollSpeed =  - (scrollFactor * gameSpeed);
    }

    public void spawnColumn()
    {
      
            prevSpawnTime = 0;
            targetPos = UnityEngine.Random.Range(-2.5f, 5.5f);
            Debug.Log("Column Spawned 2" + targetPos);
            Debug.Log($"Column Spawned 3: x:{BirdControl.rb2d.transform.position.x + spawnXposition},0,0");

            nTargets++;
            columns[CurrentColumn].transform.position = new Vector3(BirdControl.rb2d.transform.position.x + spawnXposition, targetPos, 0);
            columns[CurrentColumn].tag = "Target";
             // Debug.Log($"{(BirdControl.rb2d.transform.position.x + spawnXposition, targetPosition, 0)}");
           
            if (CurrentColumn == 0)
            {
                columns[columnPoolSize - 1].tag = "Untagged";
            }
            else
            {
                columns[CurrentColumn - 1].tag = "Untagged";

            }

            CurrentColumn += 1;

            if (CurrentColumn >= columnPoolSize)
            {
                CurrentColumn = 0;
            }

    }

   
    
    public void ExitGame()
    {
        if (gameState != GameStates.WAITING && gameState != GameStates.STOP)
        {
            Time.timeScale = 1;
            isGamePaused = false;
            GameOver();
          
        }
        SceneManager.LoadScene("CHOOSEMOVE");
    }
    private void resumeGame()
    {
        gameState = _prevGameState;
        Time.timeScale = 1f;
        pauseImage.SetActive(isGamePaused);
        ExitButton.SetActive(true);
    }

    private void pauseGame()
    {
        gameState = GameStates.PAUSED;
        pauseImage.SetActive(isGamePaused);
       
        ExitButton.SetActive(false);
        Time.timeScale = 0f;
    }


     private IEnumerator ShowForSeconds(GameObject obj, float seconds)
    {
        obj.SetActive(true);
        loadingImage.gameObject.SetActive(true);
        loadingImage.fillAmount = 0f;

        float elapsed = 0f;
        while (elapsed < seconds)
        {
            elapsed += Time.deltaTime;
            loadingImage.fillAmount = Mathf.Clamp01(elapsed / seconds);
            yield return null;
        }
        obj.SetActive(false);
        loadingImage.gameObject.SetActive(false);
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }

    public void showPaused()
    {
        foreach (GameObject g in pauseObjects)
        {
            g.SetActive(true);
        }
    }

    public void hidePaused()
    {
        foreach (GameObject g in pauseObjects)
        {
            g.SetActive(false);
        }
        // SuccessRateBanner.SetActive(false);
    }
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

    public void targetPass() {
        Debug.Log($"{targetTime} targetTime");
        isTargetHit = true;
        isTargetMissed = false;
        nSuccess++;
        
        
    }

    public void targetHit() {
        Debug.Log($"{targetTime} targetTime");
        isTargetHit = false;
        isTargetMissed = true;
        nFailure++;
    }

    public void BirdDied()
    {
        birdDied = true;
        gameOver = true;
    }

    public void BirdScored()
    {
        if (triaTimeLeft < 0 && !birdDied)
        {
            gameOver = true;
            score = 0;
          
            BirdDied();
        }
        else
        {
            if (!BirdControl.Instance.startBlinking )
            {
               
                int index = UnityEngine.Random.Range(0, winClip.Length);
                eventAudioSource.clip = winClip[index];

                if (score != 0)eventAudioSource.Play();

                targetPass();
            }
            else
            {
                int index = UnityEngine.Random.Range(0, hitClip.Length);
                eventAudioSource.clip = hitClip[index];
                eventAudioSource.Play();
               
                targetHit();

            }
        }
    }


    public void startGame()
    {
        reminderPanel.SetActive(false);
        startImage.SetActive(false);
        // Spawing the ball.
        gameSpeed = AppData.Instance.selectedGame.gameSpeed;
        UpdateScrollSpeed();
       
        // Initialize game variables.
        gameDuration = MarsGameDefs.GAMEDURATION[AppData.Instance.selectedGame.name];

        triaTimeLeft = gameDuration;
        // Reset score related variables.
        nTargets = 0;
        nSuccess = 0;
        nFailure = 0;
        AppData.Instance.StartNewTrial();
        gameState = GameStates.SPAWNTARGET;

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
    
    public bool IsGamePlaying()
    {
        return gameState != GameStates.WAITING 
            && gameState != GameStates.PAUSED
            && gameState != GameStates.STOP;
    }

    private void RunGameStateMachine()
    {
        // Act according to the current game state.
        bool isTimeUp = triaTimeLeft <= 0;
        // Run the game timer
        if (isGamePlaying&&!isTimeUp) triaTimeLeft -= Time.deltaTime;
        timeLeftText.text = $"Timer:{(int)triaTimeLeft}s";
      
        switch (gameState)
        {
            case GameStates.WAITING:
                // Check of game has been started.
                if (isGameStarted) gameState = GameStates.START;
                break;
            case GameStates.START:
                // Start the game.
                startGame();
                gameState = GameStates.SPAWNTARGET;
                break;
            case GameStates.SPAWNTARGET:
                if (eventDelayTimer <= 0f && !runOnce)
                {
                    targetTime = 0;
                    spawnColumn();
                    runOnce = true;
                    eventDelayTimer = 0.05f;
                }
                else
                {
                    eventDelayTimer -= Time.deltaTime;
                    if (eventDelayTimer <= 0f)
                    {
                        gameState = GameStates.MOVE;   
                    }
                }               
                break;
            case GameStates.MOVE:
                // Wait for the user to success or fail.
                if (isTargetHit) gameState = GameStates.SUCCESS;
                if (isTargetMissed) gameState = GameStates.FAILURE;
                if (isTimeUp)
                {
                    nFailure++;
                    gameState = GameStates.STOP;
                }
                eventDelayTimer = 0.05f;
                break;
            case GameStates.SUCCESS:
            case GameStates.FAILURE:
                eventDelayTimer -= Time.deltaTime;
                if (eventDelayTimer <= 0f)
                {
                    gameState = (isTimeUp || gameOver) ? GameStates.STOP : GameStates.SPAWNTARGET;
                    isTargetHit = false;
                    isTargetMissed = false;
                    runOnce = false;
                }
             
                break;
            case GameStates.PAUSED:
                break;
            case GameStates.STOP:
                // Trial complete.
                GameOver();
                break;
        }
    }
 
     public void GameOver()
    {
        if (!isGameFinished)
        {
            // Compute game time
            int gameTime = (int)(gameDuration - triaTimeLeft);
            AppData.Instance.gameTime = gameTime;
            // Stop the current game trial
            if ((scores[0] + nSuccess) > scores[1] && !AppData.Instance.selectedGame.isAchievedToday())
            {
                AppData.Instance.selectedGame.updateCummulativeStars();
                celebrationPanel.SetActive(true);
            }

            AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);

            if (!celebrationPanel.gameObject.activeSelf)
            {
                gameOverPanel.SetActive(true);
                GameOverStar.SetActive(AppData.Instance.selectedGame.isAchievedToday());
                yesterdayScoreTxt.text = $"{scores[1]:D4}";
                todayScoreTxt.text = $"{(scores[0] + nSuccess):D4}";
            }
            if (celebrationPanel.gameObject.activeSelf)
            {
                updateStarCount();
                scoreComparisonTxt.text = $"{(scores[0] + nSuccess).ToString("D3")}";
            }
        }
        timeLeftText.text = "Time: 0s";
        // Set game over state
       
        isGameFinished = true;
        //IF GAME PRESCRIBED TIME FINISHED , MOVE TO CHOOSEMOVEMENT SCENE TO PLAY FOR ANOTHER MOVEMENT
        bool isRequiredTrialsCompleted = AppData.Instance.selectedMovement.trialNumberDay == AppData.Instance.userData.moveTimePrsc[AppData.Instance.selectedMovement.name];
        if (isRequiredTrialsCompleted) { SceneManager.LoadSceneAsync("CHOOSEMOVE"); }
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

    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
    

}
