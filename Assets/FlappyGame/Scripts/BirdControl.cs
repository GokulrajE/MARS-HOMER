
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using System.Text;

public class BirdControl : MonoBehaviour
{

    public FlappyGameControl FGC;
    
    public static BirdControl instance;

    public static Rigidbody2D rb2d;

    public static float playSize;
 
    public Image life1;
    public Image life2;
    public Image life3;

    public float spriteBlinkingTimer = 0.0f;
    public float spriteBlinkingMiniDuration = 0.1f;
    public float spriteBlinkingTotalTimer = 0.0f;
    public float spriteBlinkingTotalDuration = 2f;
    public bool startBlinking = false;


    public float speed = 0.001f;
    public float tilt;
    public static int collustionCount;
    public int totLife = 3;
    public int lifeCounter = 3;
    public static int hitCount = 0;
    public static bool reduceSpeed;
    public int currentLife;

    public static float maxY;
    public static float minY;
    public static float maxYUnity = 3, minYUnity = -6;
    public static float unityValY;


    public int[] DEPENDENT = new int[] { 0, -1, 1 };

    void Start()
    {

        collustionCount = 0;
        currentLife = 0;
      
        rb2d = GetComponent<Rigidbody2D>();

        playSize = 2.3f + 5.5f;
        reduceSpeed = false;

        maxY = -(Mathf.Abs(MovementSceneHandler.initialAngle) + 20);
        minY = -(Mathf.Abs(MovementSceneHandler.initialAngle) - 20);

    }

    // Update is called once per frame

    private void Update()
    {

        if (startBlinking == true)
        {
            hitCount = collustionCount;

            if (collustionCount < totLife)
            {
                SpriteBlinkingEffect();
            }
            else
            {
                lifeCounter = lifeCounter - 1;
                FlappyGameControl.instance.playerLifeFinished();
                collustionCount = 0;
                life1.enabled = true;
                life2.enabled = true;
                life3.enabled = true;
           
                if (lifeCounter == 0)
                {
               
                    reduceSpeed = true;
                    lifeCounter = 3;
              
                }
                else
                {
                    reduceSpeed = false;
                
                }

            }

        }


    }


    void FixedUpdate()
    {
        float moveVertical = Input.GetAxis("Vertical");
        Vector3 movement = new Vector3(0.0f, 0.0f, moveVertical);
        GetComponent<Rigidbody2D>().velocity = movement * speed;

        //move the game object based on MarsAngle

        unityValY = -Mathf.Clamp(Angle2ScreenZ(MarsComm.angle1), minYUnity, maxYUnity);
      
        GetComponent<Rigidbody2D>().position = new Vector3
        (
            -6f,
            (float)unityValY,
            0.0f
        );
       
        GetComponent<Rigidbody2D>().transform.rotation = Quaternion.Euler(0.0f, 0.0f, GetComponent<Rigidbody2D>().velocity.x * -tilt);
    }

    public float Angle2ScreenZ(float angleZ)
    {
        float playSizeZ = 6 - (-6);
        return Mathf.Clamp(-6 + (angleZ - maxY) * (playSizeZ) / (minY - maxY), -1.2f * playSizeZ, 1.2f * playSizeZ);
    }


    public void SpriteBlinkingEffect()
    {
        spriteBlinkingTotalTimer += Time.deltaTime;
        if (spriteBlinkingTotalTimer >= spriteBlinkingTotalDuration)
        {
            startBlinking = false;
            spriteBlinkingTotalTimer = 0.0f;
            this.gameObject.GetComponent<SpriteRenderer>().enabled = true; 
            return;
        }

        spriteBlinkingTimer += Time.deltaTime;
        if (spriteBlinkingTimer >= spriteBlinkingMiniDuration)
        {
            spriteBlinkingTimer = 0.0f;
            if (this.gameObject.GetComponent<SpriteRenderer>().enabled == true)
            {
                this.gameObject.GetComponent<SpriteRenderer>().enabled = false;  //make changes
            }
            else
            {
                this.gameObject.GetComponent<SpriteRenderer>().enabled = true;   //make changes
            }
        }
    }


    private void OnCollisionEnter2D(Collision2D collision)
    {
        FGC.playerHitMountain();
        startBlinking = true;
        collustionCount++;
        // Debug.Log(collision_count+" :collision");
        if (collustionCount == 1)
        {
            life1.enabled = false;
        }
        else if (collustionCount == 2)
        {
            life2.enabled = false;
        }
        else if (collustionCount == 3)
        {
            life3.enabled = false;
        }


    }


}