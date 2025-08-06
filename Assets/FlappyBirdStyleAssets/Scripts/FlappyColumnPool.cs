using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FlappyColumnPool : MonoBehaviour
{
    enum AssessStates
    {
        DAY = 1,
        EVE = 2,
        NIGHT = 3
    };

    public int _state; 
    public static FlappyColumnPool instance;
    public int columnPoolSize = 5;
    private GameObject[] columns;
    public GameObject[] columnPrefab;
    public GameObject[] backgrounds;
    public float columnMin = -5.3f;
    public float ColumnMax = 1.3f;
    private Vector2 objectPoolPosition = new Vector2(-15,-25);
    private float timeSinceLastSpawn = 3;
    public float spawnRate = 4;
    private float spawnXposition = 16;
    private int CurrentColumn = 0;
    private GameObject[] top;
    private GameObject[] bottom;


    public  int difficultyLevel =10;
    bool setup;

    public float prevSpawnTime;

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
       // _state = 0;

        setup = false;
        


    }

    // Update is called once per frame
    void Update()
    {
        prevSpawnTime += Time.deltaTime;
        if (!setup)
        {
            // Debug.Log(AppData.startGameLevel);
            //_state = (AppData.startGamePerformace)>0? AppData.startGamePerformace: 0;
           
            //FlappyColumnPool.instance.difficultyLevel = FlappyGameControl.instance.startGameLevelRom;
            columns = new GameObject[columnPoolSize];
            for (int i = 0; i < columnPoolSize; i++)
            {
                columns[i] = (GameObject)Instantiate(columnPrefab[_state], objectPoolPosition, Quaternion.identity);
            }
            top = GameObject.FindGameObjectsWithTag("Top");

            chooseBackground();
            //FlappyColumnPool.instance.difficultyLevel = 6;

            //foreach (GameObject g in top)
            //{
            //    g.transform.localPosition = new Vector3(g.transform.localPosition.x, Mathf.Clamp((10 - difficultyLevel) * .25f, 0, 0), 0);
            //}
            //bottom = GameObject.FindGameObjectsWithTag("Bottom");

            //foreach (GameObject g in bottom)
            //{
            //    g.transform.localPosition = new Vector3(g.transform.localPosition.x, -Mathf.Clamp((10 - difficultyLevel) * .25f, 0,0), 0);
            //}
           // FlappyGameControl.instance.scrollSpeed = -2 - FlappyGameControl.instance.startGameLevelSpeed * .1f;
            setup = true;
        }
        // FB_spawnTargets.instance.trailDuration = 10f / -FlappyGameControl.instance.scrollSpeed;

        //FlappyGameControl.instance.scrollSpeed = -2 - FlappyGameControl.instance.startGameLevelSpeed * .1f;
    }

    public void chooseBackground()
    {
        foreach (GameObject obj in backgrounds)
        {
            obj.SetActive(false);
        }
        backgrounds[_state].SetActive(true);
    }
    public void spawnColumn()
    {
        FlappyGameControl.instance.RandomAngle();
        if (!FlappyGameControl.instance.gameOver && prevSpawnTime > 2)
        {
            prevSpawnTime = 0;
            // timeSinceLastSpawn = 0;
            //  float spawnYposition = Random.Range(columnMin, ColumnMax);

            //   Debug.Log(CurrentColumn);

            columns[CurrentColumn].transform.position = new Vector2(BirdControl.rb2d.transform.position.x+ spawnXposition, FlappyGameControl.instance.ypos);
            columns[CurrentColumn].tag = "Target";
            if(CurrentColumn == 0)
            {
                columns[columnPoolSize - 1].tag = "Untagged";
            }
            else
            {
                columns[CurrentColumn - 1].tag = "Untagged";

            }
                       
            //FB_spawnTargets.instance.trailDuration = Mathf.Clamp((BirdControl.rb2d.transform.position.x + -columns[CurrentColumn].transform.position.x) / FlappyGameControl.instance.scrollSpeed,2,4);
            CurrentColumn += 1;
            if (CurrentColumn >= columnPoolSize)
            {
                CurrentColumn = 0;
            }
            
        }
    }
}
