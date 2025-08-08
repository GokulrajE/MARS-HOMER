using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FlappyColumn : MonoBehaviour
      
{
    public AudioClip saw;

    float prevSpawnTime = 0;
    // Start is called before the first frame update
    void Start()
    {
    GetComponent<AudioSource>().playOnAwake = false;
    GetComponent<AudioSource>().clip = saw;
     }

    // Update is called once per frame
    void Update()
    {
        prevSpawnTime += Time.deltaTime;
        //Debug.Log(prevSpawnTime);


    }
    private void OnTriggerExit2D(Collider2D collision)
    {
       // Debug.Log("Trigger" + collision.gameObject.tag);
        if (collision.gameObject.tag == "Player" &&collision.GetComponent<BirdControl>() != null && prevSpawnTime > 1)
        {
            //  Debug.Log(this.gameObject.name);
            FlappyGameControl.instance.targetHit();
            prevSpawnTime = 0;
        
            

        }
       
    }

  
}
