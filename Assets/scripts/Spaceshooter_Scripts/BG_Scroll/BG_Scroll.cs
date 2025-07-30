using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class BG_Scroll : MonoBehaviour
{
    // Start is called before the first frame update
    public float scroll_speed = 0.5f;
    private MeshRenderer mesh_Renderer;
    private spaceShooterGameContoller gameManager;
    private float y_scroll;


    void Awake()
    {
        mesh_Renderer = GetComponent<MeshRenderer>();
        
    }

    // Update is called once per frame
    void Update()
    {
        if (!spaceShooterGameContoller.Instance.isGamePaused 
            && !spaceShooterGameContoller.Instance.isGameFinished 
            && spaceShooterGameContoller.Instance.isGameStarted)
        {
            Scroll();
        }
    }
    void Scroll()
    {
        y_scroll = Time.time * scroll_speed;
        Vector2 offset = new Vector2(0f, y_scroll);
        mesh_Renderer.sharedMaterial.SetTextureOffset("_MainTex", offset);
    }
}
