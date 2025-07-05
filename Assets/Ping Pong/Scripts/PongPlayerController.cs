using UnityEngine;
using System.Collections;
using System;
using System.IO;
using Unity.VisualScripting.Antlr3.Runtime;
using static AppData;
using System.Data;



public class PongPlayerController : MonoBehaviour
{
    public static PongPlayerController instance;

	public float speed = 10;
   
    static float topBound = 3.6F;
	static float bottomBound = -3.6F;
    Vector2 direction;

   
    public static float playSize;
    public static float[] rom;
    public static int[] DEPENDENT = new int[] {0,-1,1};
  

    public static int reps;
    int hand_use_pong;
    private string hospno;
    public int PongGameCount;

    public GameObject player;
    public float y_max, y_min,previousValue,yValue;
    public float time;

    void Start () {
        playSize = topBound - bottomBound;
        PongGameCount++;
        getAssessmentData();
    }

    public void getAssessmentData()
    {
        //marsUserData.dTableAssessment = DataManager.loadCSV($"{DataManager.directoryAssessmentData}/{DataManager.ROMWithSupportFileNames[(int)AppData.ArmSupportController.setsupportstate]}");
        //DataRow lastRow = marsUserData.dTableAssessment.Rows[marsUserData.dTableAssessment.Rows.Count - 1];
        //y_min = float.Parse((lastRow.Field<string>(AppData.miny)));
        //y_max = float.Parse((lastRow.Field<string>(AppData.maxy)));
        ////Debug.Log(zMaxMars + "," + zMaxMars + "," + yMaxMars + "," + yMinMars);
        //Debug.Log("working");
    }

    // Update is called once per frame
    void Update ()
    {
        
        Game();
        time += Time.deltaTime;
        //recordData();
        
    }

    
    private void OnCollisionEnter2D(Collision2D collision)
    {
        gameData.events = 3;
        Debug.Log("playerhit");
        if(collision.gameObject.tag == "Target")
        {
            //AppData.reps += 1;
            //Debug.Log(AppData.reps);
            
        }
    }
    private void OntriggerEnter2D(Collision2D collision)
    {
        Debug.Log("hello");
    }
    public void Game()
    {
        

        if (Mathf.Abs(MarsComm.angleOne) > (Mathf.Abs(MovementSceneHandler.initialAngle) - 20))
        {
            yValue = -Angle2ScreenZ((Mathf.Sin(3.14f / 180 * DEPENDENT[AppData.Instance.userData.uaLength] * MarsComm.angleOne) * (475 * Mathf.Cos(3.14f / 180 * DEPENDENT[AppData.Instance.userData.uaLength] * MarsComm.angleTwo) + 291 * Mathf.Cos(3.14f / 180 * DEPENDENT[AppData.Instance.userData.uaLength] * MarsComm.angleTwo + 3.14f / 180 * DEPENDENT[AppData.Instance.userData.uaLength] * MarsComm.angleThree))), y_min, y_max);
            this.transform.position = new Vector2(this.transform.position.x,yValue );
            //Debug.Log(Angle2ScreenZ((Mathf.Sin(3.14f / 180 * MarsComm.angleOne) * (475 * Mathf.Cos(3.14f / 180 * DEPENDENT[AppData.useHand] * MarsComm.angleTwo) + 291 * Mathf.Cos(3.14f / 180 * DEPENDENT[AppData.useHand] * MarsComm.angleTwo + 3.14f / 180 * DEPENDENT[AppData.useHand] * MarsComm.angleThree))), y_min, y_max));
            if (transform.position.y > topBound)
            {
                transform.position = new Vector3(transform.position.x, topBound, 0);
            }
            else if (transform.position.y < bottomBound)
            {
                transform.position = new Vector3(transform.position.x, bottomBound, 0);
            }
            player.GetComponent<SpriteRenderer>().color = new Color32(0, 255, 0, 255);
            if(yValue != previousValue) {
                gameData.events = 1;
                Debug.Log("playermoving");
                previousValue = yValue;
            }
        }
        else
        {
            player.GetComponent<SpriteRenderer>().color = new Color32(255, 255, 0, 255);
        }
        //PongData();
        //KeyboardControl();

    }


    public static float Angle2ScreenZ(float angleZ, float y_Min, float y_Max)
    {
        return Mathf.Clamp(bottomBound + (angleZ - y_Min) * ((playSize) / (y_Max - y_Min)), -3.6f * playSize, 3.6f * playSize);
    }

    
    private void KeyboardControl()
    {
        if (Input.GetKey(KeyCode.UpArrow))
        {
            gameData.events = 1;
            direction = Vector2.up;
            this.transform.Translate(direction * speed * Time.deltaTime);
        }
        else if (Input.GetKey(KeyCode.DownArrow))
        {
            gameData.events = 1;
            direction = Vector2.down;
            this.transform.Translate(direction * speed * Time.deltaTime);
        }
        else
        {
            direction = Vector2.zero;
        }
    }
}
