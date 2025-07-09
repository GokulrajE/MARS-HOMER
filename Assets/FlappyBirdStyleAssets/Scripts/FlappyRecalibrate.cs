using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Linq;

public class FlappyRecalibrate : MonoBehaviour
{
    List<Vector3> paths;
	float max_y;
	float min_y;

    float y_c;

    public static LineRenderer lr;
    public static List<Vector3> paths_draw;

    public float speed = 0.001f;
    public float tilt;

    // Start is called before the first frame update
    void Start()
    {
        paths = new List<Vector3>();
        paths = FlappyCalibrate.paths_pass;
        
        max_y = paths.Max(v => v.y);
        min_y = paths.Min(v => v.y);

        y_c = max_y-min_y;

        paths_draw = new List<Vector3>();
        
        lr = GetComponent<LineRenderer>();
        // lr.SetWidth(0.1f, 0.1f);
        lr.SetWidth(1.0f, 1.0f);
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    void FixedUpdate ()
	{		
        // float moveHorizontal = Input.GetAxis ("Horizontal");
		float moveVertical = Input.GetAxis ("Vertical");

		// Vector3 movement = new Vector3 (moveHorizontal, 0.0f, moveVertical);
        Vector3 movement = new Vector3 (0.0f, 0.0f, moveVertical);
		GetComponent<Rigidbody2D>().velocity = movement * speed;

        double y_value = ((Mathf.Cos(3.14f/180* MarsComm.angle1) * (333 * Mathf.Cos(3.14f / 180 * MarsComm.angle2) + 381 * Mathf.Cos(3.14f / 180 * MarsComm.angle2 + 3.14f / 180 * MarsComm.angle3))));
        double result_value = (-(y_value/y_c)*7.0);
		

        GetComponent<Rigidbody2D>().position = new Vector3
		(
			0.0f, 
			(float)result_value+1.0f,
            0.0f
		);
		
		GetComponent<Rigidbody2D>().transform.rotation = Quaternion.Euler (0.0f, 0.0f, GetComponent<Rigidbody2D>().velocity.x * -tilt);

		
		Vector3 xxx = GetComponent<Rigidbody2D>().position;
		Debug.Log("PlayerPosition: "+xxx);

        Vector3 to_draw_values = xxx;
        
        paths_draw.Add(to_draw_values);

        lr.positionCount = paths_draw.Count;
        lr.SetPositions (paths_draw.ToArray());
        lr.SetColors(Color.green,Color.green);
        lr.useWorldSpace = true;
		
	}


    public void onlick_game()
    {
        SceneManager.LoadScene("FlappyGame");
    }
}
