using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class FinalBossDestroyScript : MonoBehaviour
{
    public GameObject enemy; // Reference to the enemy GameObject
   
    private string F_path = Path.Combine(Application.dataPath, "Patient_Data", "ScoreManager.csv");
    private int currentLevel;
    private int currentScore;
    private spaceShooterGameContoller gm;
   
   void Start(){
       gm=FindObjectOfType<spaceShooterGameContoller>();
   }


    void Update()
    {
         
        // Check if the enemy is destroyed (null reference)
        if (enemy == null)
        {
            
            // Enable the panel
            gm.UnlockShipPanel();
            updateScore();

        }
    }
    private void updateScore(){
         if (File.Exists(F_path))
        {
            // string[] lines = File.ReadAllLines(F_path);

            currentLevel=10;
            currentScore=0;
            string data = $"{currentScore},{currentLevel}";
            File.WriteAllText(F_path, data);
        }
    }
}
