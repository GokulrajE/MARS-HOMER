using System.Collections;
using System.Collections.Generic;
using System.IO;
using Unity.VisualScripting;
using UnityEngine;

public class Unlock_Level_Powerups : MonoBehaviour
{
    // Start is called before the first frame update
    private spaceShooterGameContoller gm;

    private int requiredScore = 1000;

    private PlayerScore playerscore;


    void Start()
    {
        gm = FindObjectOfType<spaceShooterGameContoller>();
        playerscore = FindObjectOfType<PlayerScore>();
    }

    // Update is called once per frame
    void Update()
    {
        //NewSpaceshipPanel();

    }
    public void NewSpaceshipPanel()
    {
        if (playerscore.currentScore >= requiredScore)
        {
           
            gm.UnlockShipPanel();
           
        }

    }
}
