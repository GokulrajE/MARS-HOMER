using System.Collections.Generic;
using System.Security.Principal;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;


public class MCGameController : MonoBehaviour
{
    public static MCGameController Instance;
    public int _starCount;
    public GameObject ballPrefab;
    private GameObject []currentTarget = new GameObject[4];
    public GameObject gameOverPanel;

    public TextMeshProUGUI timerText;
    public TextMeshProUGUI scoreText;
    public GameObject gameSpeedControl;
    public GameObject startImage;
    public GameObject PauseImage;
    public float spawnInterval = 2f;
    public int ballCurrentColorIndex;
    public int PlayerCurrectColotIndex;
    public GameObject wrong;
    public GameObject tick;
    public ParticleSystem shatteredParticlePrefeb;
    private ParticleSystem shatteredParticle;
    public Color32[] colors;
    public string[] ballColors = new string[] { "brown", "green", "red", "violet" };
    public AudioSource audioSource;
    public AudioClip success;
    public AudioClip failure;
    public AudioClip[] bgmClip;
    public AudioSource bgAudioSource;
    public Sprite[] sprites;
    public GameObject reminderPanel;
    public GameObject celebrationPanle;
    public TextMeshProUGUI scoreComparisonTxt;
    public TextMeshProUGUI yesterdayScoreTxt;
    public TextMeshProUGUI todayScoreTxt;
    public TextMeshProUGUI starCount;
    public GameObject GameOverStar;
    public GameObject star;
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
    private int[] scores;
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
        SPAWNBALLS,
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

    public Vector3 playerGamePosition { get; private set; }
    public Vector3? targetGamePosition { get; private set; }
    public Vector3? targetEndPointPosition { get; private set; }
    public GameObject targetObject;


    public bool debug;
    private void Awake()
    {
        Instance = this;
    }

    // Start is called before the first frame update
    void Start()
    {

        if (debug)
        {
            AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
            AppData.Instance.SetMovement("ML");
            AppData.Instance.SetGame("MC");
        }
        initUI();
        isGameStarted = false;
       

        // Get game duration
        gameDuration = MarsGameDefs.GAMEDURATION["MC"];

        // Initialize the game speed controller.
        initializeGameSpeedController();
        gameSpeedControl.SetActive(false);

      
        // Attach the MARS button callback.
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;

     
        AppLogger.LogInfo("Space Shooter Game initialized.");


        updateStarCount();
        scores = MarsGameDefs.MatchCatch.GetScores();
        Debug.Log($"{scores[0]}/{scores[1]}");
        if (MarsGameDefs.MatchCatch.IsAchievedToday()) star.GetComponent<Image>().color = Color.white;
        AppLogger.LogInfo($"scores - yesterDayScore:{scores[1]} | TodayScore{scores[0]}");
    }
    public void updateStarCount()
    {
        starCount.text = $"{AppData.Instance.selectedGame.cummulativeStars.ToString("D2")}";
    }

    

    // Update is called once per frame
    void Update()
    {
        if (debug) return;
        MarsComm.sendHeartbeat();
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
        RunStateMachine();
        // Update the player and target positions.
        if (IsGamePlaying())
        {
            playerGamePosition = GameObject.FindGameObjectWithTag("Player").transform.position;
            if (GameObject.FindGameObjectWithTag("Target") == null)
            {
                targetGamePosition = null;
                targetEndPointPosition = null;
            }
            else
            {
                targetGamePosition = GameObject.FindGameObjectWithTag("Target").transform.position;
                targetEndPointPosition = new Vector3
                (
                    0,
                    player.unityYToRobotY(GameObject.FindGameObjectWithTag("Target").transform.position.y),
                    player.unityXToRobotZ(GameObject.FindGameObjectWithTag("Target").transform.position.x)

                );

            }
        }
    }
    public void initUI()
    {
        gameOverPanel.SetActive(false);
        startImage.SetActive(true);
        PauseImage.SetActive(false);
    }
    public bool IsGamePlaying()
    {
        return gameState != GameStates.WAITING
            && gameState != GameStates.PAUSED
            && gameState != GameStates.STOP;
    }

    public void RunStateMachine()
    {
        //ui feedback
        tick.gameObject.SetActive(isSuccess);
        wrong.gameObject.SetActive(isFailure);

        bool isGamePlaying = gameState != GameStates.WAITING && gameState != GameStates.PAUSED && gameState != GameStates.STOP;
        bool isTimeUp = gameTimeLeft < 0;
        scoreText.text = "SCORE:" + nSuccess.ToString();
        if (isGamePlaying&&!isTimeUp)gameTimeLeft -= Time.deltaTime;
        
        switch (gameState)
        {
            case GameStates.WAITING:
                if (isGameStarted) gameState = GameStates.START;
                break;
            case GameStates.START:
                startGame();
                gameState = GameStates.SPAWNBALLS;
                eventDelayTimer = 0.05f;
                runOnce = false;
                break;
            case GameStates.SPAWNBALLS:
                if (!runOnce)
                {
                    SpawnBalls();
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
                
                if (isSuccess)
                {
                    gameState = GameStates.SUCCESS;
                    eventDelayTimer = 1f;
                    Vector3 spawnPos = player.Instance.transform.position + Vector3.up * 0.5f;

                    shatteredParticle = Instantiate(
                        shatteredParticlePrefeb,
                        spawnPos,
                        Quaternion.identity
                    );
                    var main = shatteredParticle.main;
                    main.startColor = new ParticleSystem.MinMaxGradient(colors[player.Instance.lastColorIndex]);
                    shatteredParticle.Play();
                    audioSource.PlayOneShot(success);
                    
                }
                if (isFailure)
                {
                    gameState = GameStates.FAILURE;
                    audioSource.PlayOneShot(failure);
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
                    isFailure = false;
                    isSuccess = false;
                    if(gameState == GameStates.SUCCESS) player.Instance.SetRandomColor();
                    gameState = isTimeUp ? GameStates.STOP:GameStates.SPAWNBALLS;
                   
                    if (shatteredParticle != null) Destroy(shatteredParticle.gameObject);
                    clearObjects();
                   
                    eventDelayTimer = 0.05f;
                    runOnce = false;
                }
                break;
            case GameStates.STOP:
                gameOver();
                break;
        }
    }
 
    float minDistance = 2f; // adjust as needed
  
    private List<float> lastXPositions = new List<float>();

    void SpawnBalls(int count = 4)
    {
        lastXPositions.Clear();
      
        // Make a list of color indices and shuffle it
        List<int> spriteIndices = new List<int>();
        
        for (int i = 0; i < ballColors.Length; i++)
            spriteIndices.Add(i);
        ShuffleList(spriteIndices);

        for (int i = 0; i < count; i++)
        {
            // Pick a unique X position
            float randomX;
            int attempts = 0;
            do
            {
                randomX = Random.Range(MarsGameDefs.MatchCatch.RIGHTLIMIT, MarsGameDefs.MatchCatch.LEFTLIMIT);
                attempts++;
            }
            while (IsTooClose(randomX) && attempts < 100); // avoid infinite loop

            lastXPositions.Add(randomX);

            Vector3 spawnPos = new Vector3(randomX, MarsGameDefs.MatchCatch.tarSTARTPOINT, 0);
            GameObject newBall = Instantiate(ballPrefab, spawnPos, Quaternion.identity);

            // Assign a unique color/sprite
            int colorIndex = spriteIndices[i % spriteIndices.Count];
            newBall.GetComponent<SpriteRenderer>().sprite = sprites[colorIndex];
            newBall.GetComponent<Ball>().setColorIndex(colorIndex);
           
            newBall.GetComponent<Ball>().setFallTime(AppData.Instance.selectedGame.gameParameter);
            //update targetPosition data
            if (player.Instance.lastColorIndex == colorIndex)
            {
                targetGamePosition = spawnPos;
                targetEndPointPosition = new Vector3
                (
                   0,
                   player.unityYToRobotY(spawnPos.y),
                   player.unityXToRobotZ(spawnPos.x)

                );
            }
           
            currentTarget[i]=newBall;
        }
    }

    // Check if new X is too close to any previous X
    bool IsTooClose(float x)
    {
        foreach (float lastX in lastXPositions)
        {
            if (Mathf.Abs(x - lastX) < minDistance)
                return true;
        }
        return false;
    }

    // Simple Fisher�Yates shuffle
    void ShuffleList<T>(List<T> list)
    {
        for (int i = list.Count - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            T temp = list[i];
            list[i] = list[j];
            list[j] = temp;
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
            if (debug) return;
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
                todayScoreTxt.text = $"{(scores[0] + nSuccess):D4}";
            }
            if (celebrationPanle.gameObject.activeSelf)
            {
                //updateStarCount();
                scoreComparisonTxt.text = $"{(scores[0] + nSuccess).ToString("D3")}";
            }

            AppLogger.LogInfo($"Space Shooter Game Over. Time: {gametime}s | Targets: {nTargets} | Hits: {nSuccess} | Misses: {nFailure}");
        }
        timerText.text = "Time: 0s";
        // Set game over state
        isGameFinished = true;
        //IF GAME PRESCRIBED TIME FINISHED , MOVE TO CHOOSEMOVEMENT SCENE TO PLAY FOR ANOTHER MOVEMENT
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
        // Remove game over and start panel.
        gameOverPanel.SetActive(false);
        celebrationPanle.SetActive(false);
        startImage.SetActive(false);

        // Initialize targets, hits, and misses
        nSuccess = 0;
        nFailure = 0;
        nTargets = 0;

        // Trial success/failure.
        isFailure = false;
        isSuccess = false;

        // Set game duration.
        gameTimeLeft = gameDuration;
        // Start a new Trail
        if (debug) return;
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
        
        AppLogger.LogInfo($"Space Shooter Game started for movement '{AppData.Instance.selectedMovement.name}'. Game Speed: {AppData.Instance.selectedGame.gameParameter} | Duration: {gameDuration}s");

       
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



    void clearObjects()
    {
        for (int i = 0; i < currentTarget.Length; i++)
        {
            Destroy(currentTarget[i].gameObject);
        }
        if (shatteredParticle != null) Destroy(shatteredParticle.gameObject);
    }
}
