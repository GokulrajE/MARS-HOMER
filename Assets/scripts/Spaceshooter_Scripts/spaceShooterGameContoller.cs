
using System.Collections;
using System.Collections.Generic;
using System.Data.Common;
using System.IO;
using TMPro;
using Unity.Burst.Intrinsics;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;


public class spaceShooterGameContoller : MonoBehaviour
{
    public static spaceShooterGameContoller Instance { get; private set; }
   
    public GameObject GameOverPanel;
    public Image SupportSlider;
    public TextMeshProUGUI support;
    public TextMeshProUGUI timerText;
    public TextMeshProUGUI angletext;
    public Text messTxt;
    public GameObject startImage;
    public GameObject PauseImage;
   
    public float gameDuration = 60f; // Game duration in seconds
    
    
    //level related variables
    private int finalScore;
    private int currentLevel;
    private string path = Path.Combine(Application.dataPath, "Patient_Data", "ScoreManager.csv");
    public GameObject newSpaceshipPanel;
    public bool Levelunlocked = false;

    private float timer;
    public static bool changeScene = false;
    private float eventDelayTimer = 0f, gameSpeed;
    private bool runOnce = false;

    // Game score related variables.
    public int nTargets = 0;
    public int nSuccess = 0;
    public int nFailure = 0;

    public bool isGameStarted { get; private set; } = false;
    public bool isGameFinished { get; private set; } = false;
    public bool isGamePaused { get; private set; } = false;
    public bool isSuccess { get; private set; } = false;
    public bool isFailure { get; private set; } = false;

    

    public void setisSuccess()
    {
        isSuccess = true;
    }
    public void setisFailure()
    {
        isFailure = true;
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
        private set => _gameState = value;
    }
    
    public void setGameState(GameStates gameState)
    {
        this.gameState = gameState;
    }
   
    public Vector3 playerPosition {  get; private set; }
   
    public Vector3? targetPosition { get; private set; }
    public GameObject targetObject;

  
    private void Awake()
    {
        if(Instance == null)
        {
            Instance = this;
        }
        else
        {
            Destroy(gameObject);
        }
    }
    void Start()
    {
        initUI();
        isGameStarted = false;
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
      
      
    }
 
    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();
        if (isGamePaused && gameState != GameStates.PAUSED) PauseGame();
        else if (!isGamePaused && gameState == GameStates.PAUSED) ResumeGame();

        if (timerText != null)
        {
            timerText.text = "Time:" + Mathf.CeilToInt(timer).ToString() + "s"; // Show remaining time
        }

        //Track Restart
        if (changeScene && gameState == GameStates.STOP)
        {
            restart();
            changeScene = false;
        }
        else
        {
            changeScene = false;
        }
    }

    private void FixedUpdate()
    {

        RunStateMachine();
        playerPosition = GameObject.FindGameObjectWithTag("Player").transform.position;
        targetObject = GameObject.FindGameObjectWithTag("Asteroid");
        targetPosition = targetObject != null ? targetObject.transform.position : null;
    }

   public void initUI()
    {
        messTxt.enabled = true;
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
        if(IsGamePlaying()) timer -= Time.deltaTime;
        bool isTimeUp = timer < 0; 
        switch (gameState)
        {
            case GameStates.WAITING:
                if (isGameStarted) gameState = GameStates.START;
                break;
            case GameStates.START:
                startGame();
                gameState = GameStates.SPAWNASTROID;
                break;
            case GameStates.SPAWNASTROID:
                if (AsteroidSpawner.Instance == null)
                    break;
                if (eventDelayTimer <= 0f && !runOnce)
                {
                    AsteroidSpawner.Instance.SpawnAsteroid();
                    nTargets++;
                    eventDelayTimer = 0.05f;
                    runOnce = true;
                }
                else
                {
                    eventDelayTimer -= Time.deltaTime;
                    if (eventDelayTimer <= 0f)
                    {
                        gameState = GameStates.MOVE;
                        runOnce = false;
                    }
                }
                break;
            case GameStates.MOVE:
                if (isSuccess) gameState = GameStates.SUCCESS;
                if(isFailure)gameState = GameStates.FAILURE;
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
                        isFailure = false;
                        isSuccess = false;
                        gameState = isTimeUp ? GameStates.STOP : GameStates.SPAWNASTROID;
                        runOnce = false;
                    }
                }
                break;
            case GameStates.STOP:
                GameOver();
                break;
        }

    }
   
    public void updateMarsSupportUI()
    {
        //support.text = $"Support : {AppData.ArmSupportController.getGain()}%";
        SupportSlider.fillAmount = MarsComm.SUPPORT;
    }
   
  
    public void onMarsButtonReleased()
    {
        //To pause and resume
        if (gameState == GameStates.WAITING) isGameStarted = true;
        else if (gameState != GameStates.STOP) isGamePaused = !isGamePaused;

        //To restart
        if (gameState == GameStates.STOP && isGameFinished)
        {
            changeScene = true;
        }

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

    private void savedata()
    {
        //using the currentscore variable in playerscore to append the player score in csv file when game ends
        int currentscores = PlayerScore.Instance.currentScore;
        string score = $"{currentscores},{currentLevel}";
        File.WriteAllText(path, score);

    }

    public void GameOver()
    {

        if (Levelunlocked == false && !isGameFinished)
        {

            GameOverPanel.SetActive(true);

            //cal gameTime
            int gametime = (int)gameDuration - (int)timer;
            Others.gameTime = gametime< gameDuration ? gametime: gameDuration;

            //stop trail
            AppData.Instance.StopTrial(nTargets,nSuccess,nFailure);

            savedata();
        }

        timerText.text = "Time:0s";
        isGameFinished = true; // Set game over state 

    }
    public void startGame()
    {
        //start new Trail
        AppData.Instance.StartNewTrial();

        nSuccess = 0;
        nFailure = 0;
        nTargets = 0;

        isFailure = false;
        isSuccess = false;

        timer = gameDuration; // Initialize timer 

        GameOverPanel.SetActive(false);
        startImage.SetActive(false);
        messTxt.enabled = false;
        if (File.Exists(path))
        {
            string[] lines = File.ReadAllLines(path);
            string[] values = lines[0].Split(','); // Split the line by commas
            if (values.Length >= 2)
            {
                int.TryParse(values[1], out currentLevel); // Parse the second value as currentLevel
            }
        }
       
    }

    public void restart()
    {
        string currentSceneName = SceneManager.GetActiveScene().name;
        AppLogger.LogInfo($"The Game is Restarted '{currentSceneName}'.");

        SceneManager.LoadScene(currentSceneName);
    }

    
    public void Back_to_ChooseLevel()
    {
        SceneManager.LoadScene("space_shooter_level");
    }
    public void UnlockShipPanel()
    {
        if (newSpaceshipPanel != null)
        {
            newSpaceshipPanel.SetActive(true);
            Levelunlocked = true;
            GameOver();

        }

    }
    public void secondlevel()
    {

        finalScore = 0;
        if (currentLevel <= 2)
        {
            currentLevel = 2;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level2");
    }
    public void thirdlevel()
    {
        finalScore = 0;
        if (currentLevel <= 3)
        {
            currentLevel = 3;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level3");

    }
    public void fourthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 4)
        {
            currentLevel = 4;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level4");

    }
    public void fifthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 5)
        {
            currentLevel = 5;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level5");

    }
    public void sixthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 6)
        {
            currentLevel = 6;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level6");

    }
    public void seventhlevel()
    {
        finalScore = 0;
        if (currentLevel <= 7)
        {
            currentLevel = 7;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level7");
    }
    public void eigthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 8)
        {
            currentLevel = 8;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level8");
    }
    public void ninthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 9)
        {
            currentLevel = 9;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level9");
    }
    public void tenthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 10)
        {
            currentLevel = 10;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level9");
    }
    private void OnApplicationQuit()
    {
        Application.Quit();
        ConnectToRobot.disconnect();
    }
}
