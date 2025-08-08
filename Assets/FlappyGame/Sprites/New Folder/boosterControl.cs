using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class boosterControl : MonoBehaviour
{
    float prevAng;
    float startAngle;
    // Start is called before the first frame update
    
    float time = 0;
    void Start()
    {
        
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        //transform.eulerAngles = new Vector3(0, 0, -12);
        //rb.AddTorque(AppData.plutoData.angle*10.0f);
       
        float currentAng = this.transform.position.y;//AppData.plutoData.angle;
        //Debug.Log("boost" +currentAng);
        float rotation = (this.transform.position.y - prevAng);
        if(Mathf.Abs(rotation) < 0.00011)
        {
            //Debug.Log(" smooth zero"+transform.eulerAngles.z); 
            if(time == 0)
            {
                startAngle = this.transform.eulerAngles.z < 180 ? this.transform.eulerAngles.z : this.transform.eulerAngles.z - 360;
                //Debug.Log(startAngle);
            }
            time += Time.deltaTime;


            this.transform.eulerAngles = new Vector3(0, 0, Mathf.SmoothStep(startAngle, 0, time*2f));
            
             
            
        }
        else
        {
           //Debug.Log(" rotating");
            time = 0;
            // transform.Rotate(0, 0, rotation*3f);
            this.transform.Rotate(0, 0, rotation*6f);

        }
        prevAng = currentAng;
        //rotates 50 degrees per second around z axis
        //Debug.Log( transform.eulerAngles.z<180? transform.eulerAngles.z: transform.eulerAngles.z-360);
        //Debug.Log(transform.localEulerAngles);





    }
}
