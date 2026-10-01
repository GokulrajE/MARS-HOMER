

using TMPro;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Audio;
using UnityEngine.SceneManagement;
using static UnityEngine.GraphicsBuffer;
using Color = UnityEngine.Color;
using Image = UnityEngine.UI.Image;

public class TWGameController : MonoBehaviour
{
    public static TWGameController Instance;
    // Game start/pause variables.
    public GameObject startImage;
    public GameObject PauseImage;

    // Timer and score related UI elements.
    public TextMeshProUGUI scoreTxt;
    public TextMeshProUGUI timerTxt;

    // Game over panel UI
    public GameObject gameOverPanel;

    // Game time completion reminder panel.
    public GameObject reminderPanel;

    // Start is called before the first frame update
    private GameObject targetObject;
    public GameObject targetPrefabB;
    public GameObject targetPrefabS;
    public Sprite[] stainSprites;
    public GameObject[] bigStains;
    private GameObject target;
    public ParticleSystem cleaningParticalPrefeb;
    private ParticleSystem cleaningPartical;
    public AudioSource audioSource;
    public AudioSource audioSourcewipping;
    public AudioClip[] bgmClip;
    public AudioSource bgAudioSource;
    public GameObject moneySprite;
    private GameObject money;
    public AudioClip playerWinAudio;

    public TextMeshProUGUI cummulativeScoreTxt;
    public GameObject celebrationPanle;
    public TextMeshProUGUI scoreComparisonTxt;
    public TextMeshProUGUI yesterdayScoreTxt;
    public TextMeshProUGUI todayScoreTxt;
    public TextMeshProUGUI starCount;
    public GameObject GameOverStar;
    public GameObject star;

    // Other game logic variables.
    private float gameTimeLeft;
    private float gameDuration = 60;
    private float eventDelayTimer = 1f;
    private bool runOnce = false;
    private float insideTargetTimer = 0f;
    public int[] scores;
    private bool restart = false;
    public float GameParameter { get; private set; }//Scrub size the real world
    public Vector3 playerGamePosition { get; private set; }
    public Vector3? targetGamePosition { get; private set; }
    public Vector3? targetEndPointPosition { get; private set; }

    public bool debug;
    private float PPUarea = 0.0001f;//ppu is 100
    // Game score related variables.
    public int nTargets = 0;
    public int nSuccess = 0;
    public int nFailure = 0;
    public string TargetArea;
    public bool isGameStarted { get; private set; } = false;
    public bool isGameFinished { get; private set; } = false;
    public bool isGamePaused { get; private set; } = false;
    public bool isSuccess { get; set; } = false;
    public bool isFailure { get; set; } = false;
    public bool isGamePlaying => gameState == GameStates.WAITFORCLEAN
            || gameState == GameStates.SPAWSTAIN
            || gameState == GameStates.PLAYERIN
            || gameState == GameStates.PLAYEREXIT
            || gameState == GameStates.SUCCESS
            || gameState == GameStates.FAILURE;
    public enum GameStates
    {
        WAITING = 0,
        START,
        STOP,
        PAUSED,
        SPAWSTAIN,
        WAITFORCLEAN,
        PLAYERIN,
        PLAYEREXIT,
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
    public enum StainSize
    {
        Small,
        Big
    }

    public LineRenderer lr;
    private void Awake()
    {
        Instance = this;
    }
    void Start()
    {
        if (debug)
        {
            AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
            AppData.Instance.SetMovement("MLAP");
            AppData.Instance.SetGame("TW");
        }

        initUI();

        lr = GetComponent<LineRenderer>();
        lr.positionCount = 5;

       

        // Attach event handler to Mars button release event.
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        updateStarCount();
        scores = MarsGameDefs.TableWiping.GetScores();
        Debug.Log($"{scores[0]}/{scores[1]}");
        AppLogger.LogInfo($"scores - yesterDayScore:{scores[1]} | TodayScore{scores[0]}");
        if (MarsGameDefs.TableWiping.IsAchievedToday()) star.GetComponent<Image>().color = Color.white;


        //Get the Scrub Size

        Debug.Log($"{AppData.Instance.userData.GetLastPlayedDateAndStarsForGame("TW").gameParameter}-" +
                  $"{AppData.Instance.userData.GetLastPlayedDateAndStarsForGame("TW").totalStars}-" +
                  $"{AppData.Instance.userData.GetLastPlayedDateAndStarsForGame("TW").date}");
    }

    public void updateStarCount()
    {
        starCount.text = $"{AppData.Instance.selectedGame.cummulativeStars.ToString("D2")}";
    }

    public void Update()
    {
        // Draw ROM quad for visualization using this controller's LineRenderer
        //TWPlayer.instance.DrawROMQuad(lr);

        // Check of the game speed controller is to be shown.
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.G))
        {
            isGameStarted = true;
        }
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.R))
        {
            restart = true;
        }
        if (restart)
        {
            SceneManager.LoadSceneAsync(SceneManager.GetActiveScene().name);
            restart = false;
        }
        if (debug) return;
        MarsComm.sendHeartbeat();
        if (isGamePaused && gameState != GameStates.PAUSED) PauseGame();
        else if (!isGamePaused && gameState == GameStates.PAUSED) ResumeGame();

    }

    // Update is called once per frame

    private void FixedUpdate()
    {

        // Run the statemachine
        RunStateMachine();
        if (debug) return;
        // Update player and target positions.
        if (isGamePlaying)
        {
            // Player game position.
            playerGamePosition = GameObject.FindGameObjectWithTag("Player").transform.position;
            if (target == null)
            {
                targetGamePosition = null;
                targetEndPointPosition = null;
            }
            else
            {
                targetGamePosition = target.transform.position;
                targetEndPointPosition = new Vector3(0,
                                                     TWPlayer.instance.unityYToRobotY(target.transform.position.y),
                                                     TWPlayer.instance.unityXToRobotZ(target.transform.position.x)
                                                     );
                TargetArea = $"{StainWipe2D.Instance.totalAreaPixels} | {StainWipe2D.Instance.erasedAreaPixels}";
            }
        }
    }

    public void initUI()
    {
        gameOverPanel.SetActive(false);
        startImage.SetActive(true);
        PauseImage.SetActive(false);
    }


    public void onMarsButtonReleased()
    {
        //To pause and resume
        if (gameState == GameStates.WAITING) isGameStarted = true;
        else if (gameState != GameStates.STOP) isGamePaused = !isGamePaused;

        //To restart
        if (gameState == GameStates.STOP && isGameFinished)
        {
            //gameState = GameStates.DONE;
            restart = true;
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

        isGamePaused = false;
        gameState = _prevGameState;
        Time.timeScale = 1f;
        PauseImage.SetActive(false);

    }

    public void gameOver()
    {

        if (!isGameFinished)
        {

            //cal gameTime
            int gametime = (int)gameDuration - (int)gameTimeLeft;
            AppData.Instance.gameTime = gametime < gameDuration ? gametime : gameDuration;
            //Stop the current game trial
            if ((scores[0] + nSuccess) > scores[1] && !AppData.Instance.selectedGame.isAchievedToday())
            {
                AppData.Instance.selectedGame.updateCummulativeStars();
                celebrationPanle.SetActive(true);
                GameParameter = math.clamp(GameParameter * 0.90f, MarsGameDefs.TableWiping.MIN_SCRUB_SIZE, MarsGameDefs.TableWiping.MAX_SCRUB_SIZE);
                AppData.Instance.selectedGame.gameParameter = GameParameter;
            }
            //test
            //Debug.Log("GAMAPARAMETER BEFORE" + GameParameter);
            //GameParameter = math.clamp(GameParameter * 0.80f, MarsGameDefs.TableWiping.MIN_SCRUB_SIZE, MarsGameDefs.TableWiping.MAX_SCRUB_SIZE);
            //Debug.Log("GAMAPARAMETER AFTER" + GameParameter);
            //AppData.Instance.selectedGame.gameParameter = GameParameter;
            gameOverPanel.SetActive(!celebrationPanle.gameObject.activeSelf);
            AppData.Instance.StopTrial(nTargets, nSuccess, nTargets - nSuccess);

            if (gameOverPanel.gameObject.activeSelf)
            {
                GameOverStar.SetActive(AppData.Instance.selectedGame.isAchievedToday());
                yesterdayScoreTxt.text = $"{scores[1]:D4}";
                todayScoreTxt.text = $"{(scores[0] + nSuccess):D4}";
            }
            if (celebrationPanle.gameObject.activeSelf)
            {
                updateStarCount();
                scoreComparisonTxt.text = $"{(scores[0] + nSuccess):D3}";
            }

        }
        isGameFinished = true; // Set game over state 
        //IF GAME PRESCRIBED TIME FINISHED , MOVE TO CHOOSEMOVEMENT SCENE TO PLAY FOR ANOTHER MOVEMENT
        bool isRequiredTrialsCompleted = AppData.Instance.selectedMovement.trialNumberDay == AppData.Instance.userData.moveTimePrsc[AppData.Instance.selectedMovement.name];
        if (isRequiredTrialsCompleted) { SceneManager.LoadSceneAsync("CHOOSEMOVE"); }
    }
   
    public void startGame()
    {
        // Hide the reminder panel.
        reminderPanel.SetActive(false);

        // Initialize the targets, hits and misses.
        nSuccess = 0;
        nFailure = 0;
        nTargets = 0;

        // Reset success and failure flags.
        isFailure = false;
        isSuccess = false;

        // Hide the start image.
        startImage.SetActive(false);
        gameDuration = MarsGameDefs.GAMEDURATION["TW"];
        gameTimeLeft = gameDuration;
        isGameStarted = true;

        // Define scrub size
        float unityWidth = MarsGameDefs.TableWiping.RIGHTLIMIT - MarsGameDefs.TableWiping.LEFTLIMIT;
        float unityHeight = MarsGameDefs.TableWiping.TOPLIMIT - MarsGameDefs.TableWiping.BOTTOMLIMIT;

        float robotWidth = TWPlayer.instance.zEndPointMax - TWPlayer.instance.zEndPointMin;
        float robotHeight = TWPlayer.instance.yEndPointMax - TWPlayer.instance.yEndPointMin;

        // m² per Unity unit²
        float areaScale = (robotHeight / unityHeight) *
                          (robotWidth / unityWidth);

        Debug.Log($"AREA SCALE {areaScale}");
        GameParameter = AppData.Instance.userData.GetLastPlayedDateAndStarsForGame("TW").gameParameter;

        AppData.Instance.selectedGame.gameParameter = GameParameter;

        if (debug) return;
        // Start the next new Trail
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
    }

    public void onClickExit()
    {
        if (gameState != GameStates.WAITING && gameState != GameStates.STOP)
        {
            gameOver();
        }
        isGamePaused = false;
        Time.timeScale = 1f;
        SceneManager.LoadScene("CHOOSEMOVE");
    }
    public void RunStateMachine()
    {
        // Decrement the gameTimeLeft if game is playing.
        bool isTimeUp = gameTimeLeft < 0;
        timerTxt.text = $"TIME : {(int)gameTimeLeft}";
        if (isGamePlaying && !isTimeUp) gameTimeLeft -= Time.deltaTime;

        if (isTimeUp)
        {
            clearObject();
            gameState = GameStates.STOP;
        }
        switch (gameState)
        {
            case GameStates.WAITING:
                if (isGameStarted) gameState = GameStates.START;


                break;
            case GameStates.START:
                startGame();
                gameState = GameStates.SPAWSTAIN;
                eventDelayTimer = 0.05f;
                runOnce = false;
                break;
            case GameStates.SPAWSTAIN:
                if (!runOnce)
                {
                    if (target != null) return;
                    // Spawn the new target.
                    spawnStain();
                    nTargets++;
                    eventDelayTimer = 0.5f;
                    runOnce = true;
                }
                else
                {
                    eventDelayTimer -= Time.deltaTime;
                    if (eventDelayTimer <= 0f)
                    {

                        runOnce = false;
                        gameState = GameStates.WAITFORCLEAN;
                    }
                }
                break;
            case GameStates.WAITFORCLEAN:
                if (StainWipe2D.Instance != null)
                {
                    //Debug.Log($"{StainWipe2D.Instance.erasedPixels}/{StainWipe2D.Instance.totalStainPixels}===={StainWipe2D.Instance.erasedPixels / StainWipe2D.Instance.totalStainPixels}");
                    if ((StainWipe2D.Instance.erasedPixels / StainWipe2D.Instance.totalStainPixels > 0.95f) && !runOnce)
                    {
                        money = Instantiate(moneySprite, target.transform.position, Quaternion.identity);

                        audioSource.PlayOneShot(playerWinAudio);
                        runOnce = true;
                        eventDelayTimer = 0.5f;
                        return;
                    }//for Money Animation
                    else if ((StainWipe2D.Instance.erasedPixels / StainWipe2D.Instance.totalStainPixels > 0.95f))
                    {
                        eventDelayTimer -= Time.deltaTime;
                        if (eventDelayTimer <= 0f)
                        {
                            nSuccess++;
                            eventDelayTimer = 0.5f;
                            scoreTxt.text = $"SCORE : {nSuccess}";
                            runOnce = false;
                            gameState = GameStates.SUCCESS;
                        }
                    }

                }
                break;
            case GameStates.PAUSED:
                break;
            case GameStates.SUCCESS:
                eventDelayTimer -= Time.deltaTime;
                if (eventDelayTimer <= 0f)
                {
                    isFailure = false;
                    isSuccess = false;
                    gameState = isTimeUp ? GameStates.STOP : GameStates.SPAWSTAIN;
                    clearObject();
                    runOnce = false;
                }
                break;
            case GameStates.STOP:
                gameOver();
                break;
            case GameStates.DONE:

                break;
        }
    }

    public void spawnStain()
    {
        (Vector2 epTarget, Vector2 gTarget) = TWPlayer.instance.GenerateNextRandomTarget();

        StainSize size = TWPlayer.instance.DecideStainSize(gTarget);

        target = Instantiate(
            size == StainSize.Big
                ? bigStains[UnityEngine.Random.Range(0, bigStains.Length)]
                : targetPrefabS,
            Vector3.zero,
            Quaternion.identity);

        SpriteRenderer sr = target.GetComponent<SpriteRenderer>();
        if (sr == null) return;

        if (size == StainSize.Small && stainSprites.Length > 0)
        {
            sr.sprite = stainSprites[UnityEngine.Random.Range(0, stainSprites.Length)];
        }

        // Get half size
        float halfWidth = sr.bounds.extents.x;
        float halfHeight = sr.bounds.extents.y;

        // Clamp to ROM bounds instead of static screen limits
        float romMinX = Mathf.Min(TWPlayer.instance.x1.x, TWPlayer.instance.x2.x, TWPlayer.instance.y1.x, TWPlayer.instance.y2.x);
        float romMaxX = Mathf.Max(TWPlayer.instance.x1.x, TWPlayer.instance.x2.x, TWPlayer.instance.y1.x, TWPlayer.instance.y2.x);
        float romMinY = Mathf.Min(TWPlayer.instance.x1.y, TWPlayer.instance.x2.y, TWPlayer.instance.y1.y, TWPlayer.instance.y2.y);
        float romMaxY = Mathf.Max(TWPlayer.instance.x1.y, TWPlayer.instance.x2.y, TWPlayer.instance.y1.y, TWPlayer.instance.y2.y);

        float clampedX = Mathf.Clamp(gTarget.x, romMinX + halfWidth, romMaxX - halfWidth);
        float clampedY = Mathf.Clamp(gTarget.y, romMinY + halfHeight, romMaxY - halfHeight);

        target.transform.position = new Vector3(clampedX, clampedY, 0);

        // Verify stain is within ROM quad
        TWPlayer.instance.IsPositionWithinROMQuad(new Vector2(clampedX, clampedY));
    }
    public void SetPlayerIn()
    {
        audioSourcewipping.Play();

        if (cleaningPartical == null)
        {
            cleaningPartical = Instantiate(
                cleaningParticalPrefeb,
                target.transform.position,
                Quaternion.identity
            );

            cleaningPartical.Play();
            return;
        }

        if (!cleaningPartical.isPlaying)
            cleaningPartical.Play();

    }


    public void SetPlayerOut()
    {
        audioSourcewipping.Stop();
        if (cleaningPartical != null && cleaningPartical.isPlaying)
        {
            cleaningPartical.Stop(true, ParticleSystemStopBehavior.StopEmitting);
        }
    }

    public void clearObject()
    {
        if (cleaningPartical != null)
        {
            Destroy(cleaningPartical.gameObject);
            cleaningPartical = null;
        }

        if (target != null)
        {
            Destroy(target);
            target = null;
        }
        if(money != null)
        {
            Destroy(money.gameObject);
            money = null;
        }
        
    }

}

