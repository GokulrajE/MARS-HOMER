using UnityEngine;

public class PongPlayerController : MonoBehaviour
{
    public static PongPlayerController instance;

	public float speed = 10;
    static float topBound = 3.6F;
	static float bottomBound = -3.6F;
    Vector2 direction;
    public static float playSize;
   
    public static int[] DEPENDENT = new int[] {0,-1,1};
    public float[] currRom;
    public GameObject player;

    public float yMax, yMin,unityValY;


    void Start () {

        playSize = topBound - bottomBound;
       
        //THIS SHOULD FETCH BASED ON THE MARSMODE
        currRom = AppData.Instance.selectedMovement.CurrentAromFWS;
        yMin = currRom[2];
        yMax = currRom[3];
    }



    // Update is called once per frame
    void Update ()
    {
        updatePlayerPosition();
       
    }

    
    private void OnCollisionEnter2D(Collision2D collision)
    {
        pongGameController.instance.BallHitted();
        pongGameController.instance.playerScore++;
       
    }
    
    public void updatePlayerPosition()
    {
        

        if (Mathf.Abs(MarsComm.angle1) > (Mathf.Abs(MovementSceneHandler.initialAngle) - 20))
        {
            unityValY = -Angle2ScreenZ(MarsKinDynamics.ForwardKinematicsExtended(MarsComm.angle1,MarsComm.angle2,MarsComm.angle3,MarsComm.angle4).y,
                                       yMin, 
                                       yMax);
            this.transform.position = new Vector2(this.transform.position.x,unityValY );
            
            if (transform.position.y > topBound)
            {
                transform.position = new Vector3(transform.position.x, topBound, 0);
            }
            else if (transform.position.y < bottomBound)
            {
                transform.position = new Vector3(transform.position.x, bottomBound, 0);
            }
            player.GetComponent<SpriteRenderer>().color = new Color32(0, 255, 0, 255);
         
        }
        else
        {
            player.GetComponent<SpriteRenderer>().color = new Color32(255, 255, 0, 255);
        }
      

    }


    public static float Angle2ScreenZ(float angleZ, float y_Min, float y_Max)
    {
        return Mathf.Clamp(bottomBound + (angleZ - y_Min) * ((playSize) / (y_Max - y_Min)), -3.6f * playSize, 3.6f * playSize);
    }

    
    private void KeyboardControl()
    {
        if (Input.GetKey(KeyCode.UpArrow))
        {
           
            direction = Vector2.up;
            this.transform.Translate(direction * speed * Time.deltaTime);
        }
        else if (Input.GetKey(KeyCode.DownArrow))
        {
            
            direction = Vector2.down;
            this.transform.Translate(direction * speed * Time.deltaTime);
        }
        else
        {
            direction = Vector2.zero;
        }
    }
}
