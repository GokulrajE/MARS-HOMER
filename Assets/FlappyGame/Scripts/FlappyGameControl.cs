
using System;
using System.Collections;
using TMPro;
using Unity.Burst.Intrinsics;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;


public class FlappyGameControl : MonoBehaviour
{
    public static FlappyGameControl instance;

    public Text ScoreText;
    public GameObject GameOverText;
    public GameObject CongratulationsText;
    public GameObject[] pauseObjects;
    public GameObject start;
    public Text LevelText;
    public GameObject menuCanvas;
    public GameObject Canvas;
    public BirdControl bc;
    public Text durationText;
    public Text support;
    private GameObject targetTemp;
    public Vector3? TargetPosition { get; private set; }
    public Vector3 PlayerPosition { get; private set; }

    public float scrollSpeed;

    public float yPosition;
   
    
    private int score;
    public int playerLifeCount = 3;

    private int trialDuration = 0;
    private float triaTimeLeft = 0, 
                  eventDelayTimer;
    
    public static bool changeScene = false,
                       runOnce,
                       skipFirstPoint = false;

    public int nTargets = 0;
    public int nSuccess = 0;
    public int nFailure = 0;
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
    public GameStates gameState
    {
        get => _gameState;
        private set => _gameState = value;
    }
    private GameStates _prevGameState = GameStates.WAITING;

    // Bunch of event flags
    public bool isGameStarted { get; private set; } = false;
    public bool isGameFinished { get; private set; } = false;
    public bool isGamePaused { get; private set; } = false;
    public bool isTargetHit { get; private set; } = false;
    public bool isTargetMissed { get; private set; } = false;


    void Awake()
    {
        if (instance == null)
        {
            instance = this;
        }
        else if (instance != null)
        {
            Destroy(gameObject);
        }
    
    }


    // Start is called before the first frame update
    void Start()
    {
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
       
        gameState = GameStates.WAITING;
       
    }

    // Update is called once per frame
    void Update()
    {
        if (isGamePaused && gameState != GameStates.PAUSED) PauseGame();
        else if (!isGamePaused && gameState == GameStates.PAUSED) ResumeGame();

        if (changeScene)
        {
            onClickRestart();
        }
        
    }
    public void FixedUpdate()
    {
        MarsComm.sendHeartbeat();
        RunGameStateMachine();
        if(!isGameFinished) UpdateDuration();
        PlayerPosition = GameObject.FindGameObjectWithTag("Player").transform.position;
        targetTemp = GameObject.FindGameObjectWithTag("Target");
        TargetPosition = targetTemp != null ? targetTemp.transform.position : null;
    }
    private void RunGameStateMachine()
    {
        // Check if the game is to be paused or unpaused.
        if (isGamePaused) PauseGame();
        else if (gameState == GameStates.PAUSED) ResumeGame();

        
        if (IsGamePlaying()) triaTimeLeft -= Time.deltaTime;
        // Act according to the current game state.
        bool isTimeUp = triaTimeLeft <= 0;
        switch (gameState)
        {
            case GameStates.WAITING:
                showPaused();
                // Check of game has been started.
                if (isGameStarted) gameState = GameStates.START;
                break;
            case GameStates.START:
                hidePaused();
                // HideFinished();
                // Start the game.
                StartGame();
                gameState = GameStates.SPAWNTARGET;
                break;
            case GameStates.SPAWNTARGET:
                if (eventDelayTimer <= 0f && !runOnce)
                {
                    FlappyColumnPool.instance.spawnColumn();
                    nTargets++;
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
                if (isTargetMissed || isTimeUp) gameState = GameStates.FAILURE;
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
                        gameState = (isTimeUp || isGameFinished) ? GameStates.STOP : GameStates.SPAWNTARGET;
                        isTargetHit = false;
                        isTargetMissed = false;
                        runOnce = false;
                    }

                }
                break;
            case GameStates.PAUSED:
                break;
            case GameStates.STOP:
                // Trial complete.
                isGameFinished = true;
                GameOverText.SetActive(true);
                endGame();
                break;
        }
      
    }
    public bool IsGamePlaying()
    {
        return gameState != GameStates.WAITING
            && gameState != GameStates.PAUSED
            && gameState != GameStates.STOP;
    }
    public void StartGame()
    {
        isGameFinished = false;
        Canvas.SetActive(true);
        menuCanvas.SetActive(false);
        scrollSpeed = -2f;
        //timecoRoutine = SpawnTimer();
        trialDuration = 60;
        triaTimeLeft = trialDuration;
        //StartCoroutine(timecoRoutine);
        FlappyColumnPool.instance.prevSpawnTime = 2;
        AppData.Instance.StartNewTrial();

    }

    public void endGame()
    {
            float gameTime = trialDuration - triaTimeLeft;
            Others.gameTime = (gameTime < trialDuration) ? (int)gameTime : trialDuration;
            AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);
            gameState = GameStates.DONE;
    }

    public void PauseGame()
    {
        _prevGameState = gameState;
        gameState = GameStates.PAUSED;
        isGamePaused = true;
        Time.timeScale = 0;
        showPaused();
      
    }

    public void ResumeGame()
    {
        hidePaused();
        isGamePaused = false;
        gameState = _prevGameState;
        Time.timeScale = 1;  
    }
    public void targetHit()
    {
        isTargetHit = true;
        isTargetMissed = false;
        if (skipFirstPoint)
        {
            addScore();
            nSuccess++;
        }
        else skipFirstPoint = true;
       

    }

    public void playerHitMountain()
    {
        isTargetHit = false;
        isTargetMissed = true;
        nFailure++;
    }

    public void onMarsButtonReleased()
    {
        // This can mean different things depending on the game state.
        if (gameState == GameStates.WAITING) isGameStarted = true;
        else if (gameState != GameStates.DONE) isGamePaused = !isGamePaused;
        if(gameState == GameStates.DONE)
        {
            changeScene = true;
        }

    }

    //shows objects with ShowOnPause tag
    public void showPaused()
    {
      
        foreach (GameObject g in pauseObjects)
        {
            g.SetActive(true);
        }
    }

    //hides objects with ShowOnPause tag
    public void hidePaused()
    {
        
        foreach (GameObject g in pauseObjects)
        {
            g.SetActive(false);
        }
    }
    public void playerLifeFinished()
    {
      
        isGameFinished = true;
      
    }

    

    public void addScore()
    {
        if (!bc.startBlinking )
        {
            score += 1;
            
        }
        ScoreText.text = "Score: " + score.ToString();
    }
    

    public void RandomAngle()
    {
        yPosition = UnityEngine.Random.Range(-3f, 5.5f);
    }

    public void ShowGameMenu()
    {
        menuCanvas.SetActive(true);
        Canvas.SetActive(false);
        Time.timeScale = 0;
    }

    void UpdateDuration ()
	{
		durationText.text = "Time:" +(int)triaTimeLeft+"s";
	}

   
    public void onClickRestart()
    {
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }

    public void onClickQuit()
    {
        if (gameState != GameStates.DONE && gameState != GameStates.WAITING)
        {
            endGame();
        }
        SceneManager.LoadScene("CHOOSEMOVEMENT");
    }
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }

    public void OnApplicationQuit()
    {
        JediComm.Disconnect();
        Application.Quit();

    }

    
}
