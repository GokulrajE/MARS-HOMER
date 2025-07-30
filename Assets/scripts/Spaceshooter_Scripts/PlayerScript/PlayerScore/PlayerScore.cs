using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using TMPro;
using Unity.VisualScripting.AssemblyQualifiedNameParser;
using UnityEngine;
using UnityEngine.SocialPlatforms.Impl;
using UnityEngine.UI;

public class PlayerScore : MonoBehaviour
{
    // Start is called before the first frame update
    public static PlayerScore Instance { get; private set; }
    public TextMeshProUGUI ScoreText;
    public int currentScore;
    private string F_path = Path.Combine(Application.dataPath, "Patient_Data", "ScoreManager.csv");
    public int currTrialScore;
    private int currentLevel;

    private void Awake()
    {
        Instance = this;
    }
    void Start()
    {
        if (File.Exists(F_path))
        {
            string[] lines = File.ReadAllLines(F_path);
            string[] values = lines[0].Split(',');
            if (values.Length >= 2)
            {
                int.TryParse(values[0], out currentScore); ;
                int.TryParse(values[1], out currentLevel);
            }

            // String scores = currentScore.ToString();
            ScoreText.text = $"Score: {currTrialScore}";
        }

    }

    // Update is called once per frame
    void Update()
    {

    }
    public void AddScore()
    {

        if (!File.Exists(F_path))
        {
            File.WriteAllText(F_path, "0,0");
        }
        if (File.Exists(F_path))
        {
            // string[] lines = File.ReadAllLines(F_path);

            currentScore += 5;
            currTrialScore += 5;
            ScoreText.text = $"Score: {currTrialScore}";
            string data = $"{currentScore},{currentLevel}";
            File.WriteAllText(F_path, data);
        }
    }
    public void AsteroidScore()
    {
        if (!File.Exists(F_path))
        {
            File.WriteAllText(F_path, "0,0");
        }
        if (File.Exists(F_path))
        {
            // string[] lines = File.ReadAllLines(F_path);

            currentScore += 1;
            currTrialScore += 1;
            ScoreText.text = $"Score: {currTrialScore}";
            string data = $"{currentScore},{currentLevel}";
            File.WriteAllText(F_path, data);
        }

    }
    public void DeductScore(){
         if (!File.Exists(F_path))
        {
            File.WriteAllText(F_path, "0,0");
        }
        if (File.Exists(F_path))
        {
            // string[] lines = File.ReadAllLines(F_path);

            currentScore -= 5;
            currTrialScore -= 0;
            ScoreText.text = $"Score: {currTrialScore}";
            string data = $"{currentScore},{currentLevel}";
            File.WriteAllText(F_path, data);
        }
    }


}

