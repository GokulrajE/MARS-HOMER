using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;

using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using SimpleJSON;
using Unity.VisualScripting; // Make sure you have SimpleJSON in your project
public class OneTimeConfig : MonoBehaviour
{
    public TMP_InputField homerIdField;
    public TMP_InputField startDateField;
    public TMP_InputField endDateField;

    public TMP_InputField mlDuration;
    public TMP_InputField apDuration;
    public TMP_InputField mlapDuration;
    public Button Done;
    public TMP_Dropdown affectedSideDropdown;
    public TMP_Dropdown LocationDropdown;
    public TextMeshProUGUI DoneBtnTxt;

    public TextMeshProUGUI totalDurationText;
    public string upperArmLength = "250";
    public string foreArmLength = "150";

    // Verification Panel - NEW
    public GameObject verifyPanel;
    public GameObject popUpPanel;
    public GameObject detailsPanel;
    public TMP_Dropdown verifyLocation;
    public TMP_InputField HOMERID;
    public TextMeshProUGUI popUpConfirmationPatientID;
    public TextMeshProUGUI messageText;
    public Button popupOk;
    public Button popupCancel;
    public Button verifyButton;

    // AWS Configuration - NEW
    private readonly string awsBucketName = "homerclouds";
    private readonly string awsProfile = "default";


    // Patient Data - NEW
    private string currentPatientID;
    private string currentLocation;
    private string currentTrainingSide;
    private void Start()
    {
        // Initialize verification panel (hidden by default)
        if (!AppData.isNRSBuilt)
        {
            if (verifyPanel != null)
                verifyPanel.SetActive(false);
            if (popUpPanel != null)
                popUpPanel.SetActive(false);
            homerIdField.readOnly = true;
            LocationDropdown.interactable = false;
            affectedSideDropdown.interactable=false;
            

          
        }
        
        // Automatically set startDateField and endDateField
        DateTime startDate = DateTime.Now;
        DateTime endDate = startDate.AddDays(28).Date.AddDays(1).AddSeconds(-1);
        Debug.Log(endDate + "endDate");
        if (File.Exists(DataManager.configFile))
        {
            DataTable configData = DataManager.loadCSV(DataManager.configFile);

            DataRow lastRow = configData.Rows[configData.Rows.Count - 1];
            string hospNumber = lastRow.Field<string>("HomerID");
            bool rightHand = lastRow.Field<string>("TrainingSide") == "Right";

            //startDate = DateTime.ParseExact(lastRow.Field<string>("StartDate"), "dd-MM-yyyy", CultureInfo.InvariantCulture);
            endDate = DateTime.ParseExact(lastRow.Field<string>("endDate"), "dd-MM-yyyy HH:mm:ss", CultureInfo.InvariantCulture);
           
            homerIdField.text = hospNumber;
            affectedSideDropdown.options[affectedSideDropdown.value].text = rightHand ? "Right" : "Left";
            LocationDropdown.options[LocationDropdown.value].text = lastRow.Field<string>("Location");

            mlDuration.text = lastRow.Field<string>("ML");
            apDuration.text = lastRow.Field<string>("AP");
            mlapDuration.text = lastRow.Field<string>("MLAP");

            totalDurationText.text = lastRow.Field<string>("TotalTime");
            DoneBtnTxt.text = "Login";
        }
        else
        {
            // Pre-fill ID if we arrived from the login scene (new user selected there)
            if (!string.IsNullOrEmpty(AppData.Instance.userID))
            {
                homerIdField.text = AppData.Instance.userID;
                homerIdField.readOnly = true;
            }

            if (!AppData.isNRSBuilt)
            {
                detailsPanel.SetActive(false);
                verifyPanel.SetActive(true);
            }
        }
       
        startDateField.text = startDate.ToString("dd-MM-yyyy HH:mm:ss");
        endDateField.text = endDate.ToString("dd-MM-yyyy HH:mm:ss");
        mlDuration.onValueChanged.AddListener(delegate { UpdateTotalDuration(); });
        apDuration.onValueChanged.AddListener(delegate { UpdateTotalDuration(); });
        mlapDuration.onValueChanged.AddListener(delegate { UpdateTotalDuration(); });
        Done.onClick.AddListener(delegate { saveConfig(); });
        // Add verify button listener - NEW
        if (verifyButton != null)
        {
            verifyButton.onClick.AddListener(OnVerifyButtonClick);
            Debug.Log($"Verify ButtonInitialized");
        }
        if (popupOk != null)
            popupOk.onClick.AddListener(OnPopupOkClick);
        if (popupCancel != null)
            popupCancel.onClick.AddListener(OnPopupCancelClick);
        mlDuration.text = "0";
        apDuration.text = "0";
        mlapDuration.text = "0";

    }
    // Called when verify button is clicked

    private void OnVerifyButtonClick()
    {
        Debug.Log("Verify button clicked");
      

        if (HOMERID == null)
        {
            Debug.LogError("HOMERID is not assigned in the Inspector!");
            return;
        }

        if (string.IsNullOrWhiteSpace(HOMERID.text))
        {
            Debug.Log("Homer ID is empty");
            messageText.text = "Please enter Homer ID";
            return;
        }
               
        verifyButton.interactable = false;
        
        Debug.Log($"Homer ID entered: {HOMERID.text}");

        currentPatientID = HOMERID.text;
        currentLocation = verifyLocation.options[verifyLocation.value].text;
        //currentTrainingSide = affectedSideDropdown.options[affectedSideDropdown.value].text;

        Debug.Log($"Current Patient ID: {currentPatientID}, Location: {currentLocation}");

        if (homerIdField == null)
        {
            Debug.LogError("HOMERID TextMeshProUGUI is not assigned!");
        }
        else
        {
            homerIdField.text = currentPatientID;
        }

        if (verifyPanel == null)
        {
            Debug.LogError("verifyPanel is not assigned!");
        }
        else
        {
            verifyPanel.SetActive(true);
            Debug.Log("Verify panel activated");
        }
     
        // Start verification process
        StartCoroutine(VerifyHomerID(currentPatientID, currentLocation));
    }
    // Coroutine to verify HomerID: downloads location/patients/{homerID}/{homerID}.json from S3
    private IEnumerator VerifyHomerID(string homerID, string location)
    {
        messageText.text = "Verifying HomerID...";
        yield return null;

        string s3Path = $"s3://{awsBucketName}/{location.ToLower()}/patients/{homerID}/{homerID}.json";
        string tempFilePath = Path.Combine(Application.temporaryCachePath, "HomerPatient_temp.json");
        string arguments = $"s3 cp {s3Path} \"{tempFilePath}\" --profile {awsProfile}";

        System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo();
        startInfo.FileName = "aws";
        startInfo.Arguments = arguments;
        startInfo.RedirectStandardOutput = true;
        startInfo.RedirectStandardError = true;
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;

        using (System.Diagnostics.Process process = new System.Diagnostics.Process())
        {
            process.StartInfo = startInfo;
            process.Start();
            string error = process.StandardError.ReadToEnd();
            process.WaitForExit();

            if (process.ExitCode != 0)
            {
                Debug.LogError($"AWS CLI Error: {error}");
                messageText.text = $"HomerID {homerID} not found.";
                verifyButton.interactable = true;
                yield break;
            }
        }

        if (!File.Exists(tempFilePath))
        {
            messageText.text = $"HomerID {homerID} not found.";
            verifyButton.interactable = true;
            yield break;
        }

        string jsonContent = File.ReadAllText(tempFilePath);
        File.Delete(tempFilePath);

        ProcessPatientDetails(jsonContent, homerID);
        verifyButton.interactable = true;
    }

    // Reads the per-patient JSON: if group is null → unassigned; if "control" → blocked; otherwise show confirmation popup
    private void ProcessPatientDetails(string jsonContent, string homerID)
    {
        var json = JSON.Parse(jsonContent);
        if (json == null)
        {
            messageText.text = "Invalid patient data format.";
            return;
        }

        var groupNode = json["group"];
        if (groupNode == null || groupNode.IsNull || string.IsNullOrEmpty(groupNode.Value))
        {
            messageText.text = $"{homerID} is Unassigned. Please wait — PI should assign a group.";
            return;
        }

        if (groupNode.Value.ToLower() == "control")
        {
            messageText.text = $"{homerID} is assigned to the Control group. Cannot enroll in MARS.";
            return;
        }

        var activationDateNode = json["activationDate"];
        if (activationDateNode != null && !activationDateNode.IsNull && !string.IsNullOrEmpty(activationDateNode.Value))
        {
            messageText.text = $"{homerID} is already activated. Cannot create a new account.";
            return;
        }

        string hospID = json["hospitalID"];
        currentTrainingSide = json["trainingSide"];
        popUpConfirmationPatientID.text = $"Homer ID:  {homerID}\nPatient ID:  {hospID}\nTrainingSide: {currentTrainingSide}\n\n\tAre you sure?";
        messageText.text = "";
        popUpPanel.SetActive(true);
    }

    // NEW: Called when OK button is clicked in popup
    private void OnPopupOkClick()
    {
        popUpPanel.SetActive(false);
        verifyPanel.SetActive(false);
        detailsPanel.SetActive(true);
        // Set the saved values back to fields
        homerIdField.text = currentPatientID;
        affectedSideDropdown.value = GetDropdownIndexForSide(currentTrainingSide);
        LocationDropdown.value = GetDropdownIndexForLocation(currentLocation);

      
    }

    // NEW: Called when Cancel button is clicked in popup
    private void OnPopupCancelClick()
    {
        popUpPanel.SetActive(false);
        verifyPanel.SetActive(true);

        // Clear fields
        homerIdField.text = "";
        messageText.text = "Verification cancelled";
    }
    // NEW: Helper to get dropdown index for training side
    private int GetDropdownIndexForSide(string side)
    {
        for (int i = 0; i < affectedSideDropdown.options.Count; i++)
        {
            if (affectedSideDropdown.options[i].text.ToLower() == side.ToLower())
                return i;
        }
        return 0;
    }

    // NEW: Helper to get dropdown index for location
    private int GetDropdownIndexForLocation(string loc)
    {
        for (int i = 0; i < verifyLocation.options.Count; i++)
        {
            if (verifyLocation.options[i].text.ToLower() == loc.ToLower())
                return i;
        }
        return 0;
    }

    private void Update()
    {
       
       
    }

    private void UpdateTotalDuration()
    {
        int totalDuration = 0;

        totalDuration += ParseField(mlDuration);
        totalDuration += ParseField(apDuration);
        totalDuration += ParseField(mlapDuration);
       
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
    public void onExitClicked()
    {
        SceneManager.LoadScene("LOGIN");
    }
    public void saveConfig()
    {
        if (string.IsNullOrWhiteSpace(homerIdField.text) ||
          string.IsNullOrWhiteSpace(startDateField.text) ||
          string.IsNullOrWhiteSpace(endDateField.text))
        {
            Debug.LogError(" HomerID, Start Date, and End Date fields must not be empty.");
            return;
        }

      
        string homerId = homerIdField.text;
        string startDate = startDateField.text;
        string endDate = endDateField.text;
        AppData.Instance.setUser(homerId);
        // Set null to "0".
        string ML = string.IsNullOrEmpty(mlDuration.text) ? "0" : mlDuration.text;
        string AP = string.IsNullOrEmpty(this.apDuration.text) ? "0" : this.apDuration.text;
        string MLAP = string.IsNullOrEmpty(this.mlapDuration.text) ? "0" : this.mlapDuration.text;
      
        string totalDuration = totalDurationText.text;

        string trainingSide = affectedSideDropdown.options[affectedSideDropdown.value].text;
        string location = LocationDropdown.options[LocationDropdown.value].text.ToLower();
        string group = "Experimental";
        string headers = "HomerID,StartDate,EndDate,TotalTime,ML,AP,MLAP,ForeArmLength,UpperArmLength,TrainingSide,Location,Group";
        string data = $"{homerId},{startDate},{endDate},{totalDuration},{ML},{AP},{MLAP},{upperArmLength},{foreArmLength},{trainingSide},{location},{group}";
        string directoryPath = Path.Combine(Application.dataPath, "data", AppData.Instance.userID, "data");
        string datapath = Path.Combine(directoryPath, "configdata.csv");

        // Ensure directory exists
        if (!Directory.Exists(directoryPath)) Directory.CreateDirectory(directoryPath);

    
            if (!File.Exists(datapath))
            {
                File.WriteAllText(datapath, headers + Environment.NewLine);
                Debug.Log("Data saved to CSV: " + datapath);
            }
            File.AppendAllText(datapath, data + Environment.NewLine);
            SceneManager.LoadScene("MAIN");

    }
}
