using UnityEngine;
using System.Collections;

public class BallController : MonoBehaviour {

	//speed of the ball
	public static float speed = 1.5F;
     
	//the initial direction of the ball
	private Vector2 spawnDir;

	//ball's components
	Rigidbody2D rig2D;
    // Use this for initialization

        // Audio clip ballCollision,Win, Loose
    public AudioClip[] audioClips;
    int rand= 3;
    float threshold = 2;

    void Start () {
		//setting balls Rigidbody 2D
		rig2D = this.gameObject.GetComponent<Rigidbody2D>();

		//generating random number based on possible initial directions
		int rand = Random.Range(1,4);

		//setting initial direction
		if(rand == 1){
			spawnDir = new Vector2(1,1);
		} else if(rand == 2){
			spawnDir = new Vector2(1,-1);
		} else if(rand == 3){
			spawnDir = new Vector2(-1,-1);
		} else if(rand == 4){
			spawnDir = new Vector2(-1,1);
		}

		//moving ball in initial direction and adding speed
		rig2D.velocity = (spawnDir*speed);
		
	}
	
	// Update is called once per frame
	void Update () {
       
       
    

    }
    void playAudio(int clipNumber)
    {
        AudioSource audio = GetComponent<AudioSource>();
        audio.clip = audioClips[clipNumber];
        audio.Play();

    }

    void OnCollisionEnter2D(Collision2D col) {
        //calculate enc1
        playAudio(0);
        //tag check
        if (col.gameObject.tag == "Enemy") {

			float y = launchAngle(transform.position,
			                    col.transform.position,
			                    col.collider.bounds.size.y);
			
			//set enc1 and speed
			Vector2 d = new Vector2(1, y).normalized;
			rig2D.velocity = d * speed * 1.5F;
		}

		if (col.gameObject.tag == "Player") {
            //calculate enc1
           // playAudio(0);
            float y = launchAngle(transform.position,
			                    col.transform.position,
			                    col.collider.bounds.size.y);

			//set enc1 and speed
			Vector2 d = new Vector2(-1, y).normalized;
			rig2D.velocity = d * speed * 1.5F;
		}
	}

	//calculates the enc1 the ball hits the paddle at
	float launchAngle(Vector2 ballPos, Vector2 paddlePos,
	                float paddleHeight) {
		return 0.2f*Mathf.Sign(ballPos.y - paddlePos.y)+ (ballPos.y - paddlePos.y) / paddleHeight;
	}

 
}
