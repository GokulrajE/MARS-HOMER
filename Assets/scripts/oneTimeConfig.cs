using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class OneTimeConfig : MonoBehaviour
{
    public TMP_InputField nameField;
    public TMP_InputField ageField;
    public TMP_InputField hospitalIdField;
    public TMP_InputField startDateField;
    public TMP_InputField endDateField;

    public TMP_InputField sfeField;
    public TMP_InputField sabad;
    public TMP_InputField elfe;
    public Button Done;
    public TMP_Dropdown affectedSideDropdown;

    public TextMeshProUGUI totalDurationText;
    public Animator animator; // Assign UI element’s Animator in Inspector
    [SerializeField]private AudioSource audioSource;
    public string upperArmLength = "250";
    public string foreArmLength = "150";
    
    private void Start()
    {
        // Automatically set startDateField and endDateField
        DateTime startDate = DateTime.Now;
        DateTime endDate = startDate.AddDays(30);

        startDateField.text = startDate.ToString("dd-MM-yyyy");
        endDateField.text = endDate.ToString("dd-MM-yyyy");
        sfeField.onValueChanged.AddListener(delegate { UpdateTotalDuration(); });
        sabad.onValueChanged.AddListener(delegate { UpdateTotalDuration(); });
        elfe.onValueChanged.AddListener(delegate { UpdateTotalDuration(); });

        if (audioSource == null)
        {
            Debug.LogError("AudioSource not found on " + gameObject.name);
        }
        if (audioSource != null && audioSource.clip != null)
        {
            Debug.Log("Playing Audio: " + audioSource.clip.name);
            audioSource.ignoreListenerPause = true;

        }
        else
        {
            Debug.LogError("Audio Source or Clip is missing!");
        }
        Done.gameObject.SetActive(false);
    }
    private void Update()
    {
        if (string.IsNullOrWhiteSpace(nameField.text) ||
          string.IsNullOrWhiteSpace(ageField.text) ||
          string.IsNullOrWhiteSpace(hospitalIdField.text) ||
          string.IsNullOrWhiteSpace(startDateField.text) ||
          string.IsNullOrWhiteSpace(endDateField.text)||
          string.IsNullOrWhiteSpace(sfeField.text)||
          string.IsNullOrWhiteSpace(sabad.text)||
          string.IsNullOrWhiteSpace(elfe.text))
        {
           
            animator.SetBool("isZomming", false);
            Done.gameObject.SetActive(false);
        }
        else
        {
           
            animator.SetBool("isZomming", true); // Start zooming
            Done.gameObject.SetActive(true);

        }
       
    }
    private void UpdateTotalDuration()
    {
        int totalDuration = 0;

        totalDuration += ParseField(sfeField);
        totalDuration += ParseField(sabad);
        totalDuration += ParseField(elfe);
       
        totalDurationText.text = totalDuration.ToString();
    }

    private int ParseField(TMP_InputField field)
    {
        if (int.TryParse(field.text, out int value))
        {
            return value;
        }
        return 0; 
    }

    public void saveConfig()
    {
        if (string.IsNullOrWhiteSpace(nameField.text) ||
          string.IsNullOrWhiteSpace(ageField.text) ||
          string.IsNullOrWhiteSpace(hospitalIdField.text) ||
          string.IsNullOrWhiteSpace(startDateField.text) ||
          string.IsNullOrWhiteSpace(endDateField.text))
        {
            Debug.LogError("Name, Age, Hospital ID, Start Date, and End Date fields must not be empty.");
            return;
        }

        string date = DateTime.Now.ToString("dd-MM-yyyy");
        string name = nameField.text;
        string age = ageField.text;
        string hospitalId = hospitalIdField.text;
        string startDate = startDateField.text;
        string endDate = endDateField.text;
        
        // Set null to "0".
        string sfe = string.IsNullOrEmpty(sfeField.text) ? "0" : sfeField.text;
        string sabad = string.IsNullOrEmpty(this.sabad.text) ? "0" : this.sabad.text;
        string elfe = string.IsNullOrEmpty(this.elfe.text) ? "0" : this.elfe.text;
      
        string totalDuration = totalDurationText.text;

        string trainingSide = affectedSideDropdown.options[affectedSideDropdown.value].text;
        if (trainingSide == "Right")
        {
            trainingSide = "2";
        }
        else
        {
            trainingSide = "1";
        }
            string headers = "Date,name,hospno,Startdate,end ,age,TotaDuration,SFE,SABDU,ELFE,useHand,forearmLength,upperarmLength";
        string data = $"{date},{name},{hospitalId},{startDate},{endDate},{age},{totalDuration},{sfe},{sabad},{elfe},{trainingSide},{upperArmLength},{foreArmLength}";


        string directoryPath = DataManager.directoryPath;
        if (!Directory.Exists(directoryPath))
        {
            Directory.CreateDirectory(directoryPath);
        }
     

        if (File.Exists(DataManager.configFilePath))
        {
            Debug.Log("Configuration File Already Exists. you can't update Here");
        }
        else {
            if (!File.Exists(DataManager.configFilePath))
            {
                File.Create(DataManager.configFilePath).Dispose();
                File.WriteAllText(DataManager.configFilePath, headers + Environment.NewLine);
                Debug.Log("Data saved to CSV: " + DataManager.configFilePath);
            }
            File.AppendAllText(DataManager.configFilePath, data + Environment.NewLine);

            SceneManager.LoadScene("welcomeScene");

        }
        
    }
}
