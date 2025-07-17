using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Runtime.Serialization;
using UnityEngine;
using static AppData;
using System.IO;
using Unity.VisualScripting;
using System.Text;



public static class MarsDefs
{
    public static readonly string[] Movements = new string[] { "SFE", "SABDU", "ELFE" };
   
    public static int getMovementIndex(string Movement)
    {
        return Array.IndexOf(Movements, Movement);
    }
}

public class marsUserData
{
    public  bool isExceeded { get; private set; }
    public  DataTable dTableConfig = null;
    public  DataTable dTableSession = null;
    public  DataTable dTableAssessment = null;
    public  DataTable dTableSupportConfig = null;
    public  string hospNumber;
    public DateTime startDate;

    public bool rightHand { private set; get; }
    //File headers
    static public string movement = "Mechanism";
    static public string moveTime = "MoveTime";
    static public string dateTime = "DateTime";
  
    static public string dateFormat = "dd-MM-yyyy";
    static public string hosno = "hospno";
    static public string startDateH = "startdate";
    static public string useHandHeader = "TrainingSide";
    static public string forearmLength = "forearmLength";
    static public string upperarmLength = "upperarmLength";
    static public string maxx = "Max_x", minx = "Min_x", maxy = "Max_y", miny = "Min_y";

    public int useHand;
    public int faLength;
    public int uaLength;

    public  Dictionary<string, float> movementMoveTimePrsc { get; private set; } // Prescribed movement time
    public  Dictionary<string, float> movementMoveTimeCurr { get; private set; } // Current movement time

    public  Dictionary<string, float> movementMoveTimePrev { get; private set; } // Previous movement time 

    // Total movement times.
    public  float totalMoveTimePrsc
    {
        get
        {
            if (movementMoveTimePrsc == null)
            {
                return -1f;
            }
            else
            {
                // Add all entries of the movement move time dictionary
                return movementMoveTimePrsc.Values.Sum();

            }
        }
    }
    public  int totalMoveTimeRemaining
    {
        get
        {
            float _total = 0f;
            float _Prsc = 0f;
            foreach (string movement in MarsDefs.Movements)
            {
                _Prsc += movementMoveTimePrsc[movement];
                _total += movementMoveTimePrev[movement] - movementMoveTimeCurr[movement];
            }
            //Debug.Log(_Prsc + "prescribed");
            //Debug.Log(_total + "done");
            if (_Prsc < _total)
            {
                isExceeded = true;
                _total = (_total - _Prsc);
                return (int)_total;
            }
            else
            {
                isExceeded = false;
                _total = (_Prsc - _total);
                return (int)_total;
            }

        }
    }
    // Constructor
    public marsUserData(string configData, string sessionData)
    {
        if (File.Exists(configData))
        {
            dTableConfig = DataManager.loadCSV(configData);
        }
        // Create session file if it does not exist.
        if (!File.Exists(sessionData)) DataManager.CreateSessionFile("MARS", GetDeviceLocation());

        // Read the session file
        dTableSession = DataManager.loadCSV(sessionData);
        movementMoveTimeCurr = createMoveTimeDictionary();

        // Read the therapy configuration data.
        parseTherapyConfigData();
        if (File.Exists(DataManager.filePathSessionData))
        {
            //parseMovementMoveTimePrev();
            parseMovementMoveTimePrev();
        }
     
        //check for TrainingSide
        //this.rightHand = dTableConfig.Rows[0]["TrainingSide"].ToString().ToUpper() == "RIGHT";
    }

   
    public  void parseMovementMoveTimePrev()
    {
        movementMoveTimePrev = createMoveTimeDictionary();
        for (int i = 0; i < MarsDefs.Movements.Length; i++)
        {
            var _totalMoveTime = dTableSession.AsEnumerable()
                .Where(row => DateTime.ParseExact(row.Field<string>(dateTime), dateFormat, CultureInfo.InvariantCulture).Date == DateTime.Now.Date)
                .Where(row => row.Field<string>(movement) == MarsDefs.Movements[i])
                .Sum(row => Convert.ToInt32(row[moveTime]));
            movementMoveTimePrev[MarsDefs.Movements[i]] = _totalMoveTime / 60f;
        }
    }
    public static Dictionary<string, float> createMoveTimeDictionary()
    {
        Dictionary<string, float> _temp = new Dictionary<string, float>();
        for (int i = 0; i < MarsDefs.Movements.Length; i++)
        {
            _temp.Add(MarsDefs.Movements[i], 0f);
        }
        return _temp;
    }

    public int getTodayMoveTimeForMovement(string movement)
    {
        return (int)SessionDataHandler.movementMoveTimePrev[movement] + (int)movementMoveTimeCurr[movement];
    }

    public int getCurrentDayOfTraining()
    {
        TimeSpan duration = DateTime.Now - startDate;
        return (int)duration.TotalDays;
    }
    private void parseTherapyConfigData()
    {
        DataRow lastRow = dTableConfig.Rows[dTableConfig.Rows.Count - 1];
        hospNumber = lastRow.Field<string>("HospitalNumber");
        rightHand = lastRow.Field<string>("TrainingSide").ToLower() == "right";
        startDate = DateTime.ParseExact(lastRow.Field<string>("Startdate"), "dd-MM-yyyy", CultureInfo.InvariantCulture);
        movementMoveTimePrsc = createMoveTimeDictionary();//prescribed time
        for (int i = 0; i < MarsDefs.Movements.Length; i++)
        {
            movementMoveTimePrsc[MarsDefs.Movements[i]] = float.Parse(lastRow.Field<string>(MarsDefs.Movements[i]));
        }
        if (rightHand)
        {
            useHand = 2;
        }
        else
        {
            useHand = 1;
        }
        faLength = int.Parse(lastRow.Field<string>("forearmLength"));
        uaLength = int.Parse(lastRow.Field<string>("upperarmLength"));
        Debug.Log($"{useHand},{faLength}, {uaLength}");
    }

    public string GetDeviceLocation() => dTableConfig.Rows[dTableConfig.Rows.Count - 1].Field<string>("Location");


    public DaySummary[] CalculateMoveTimePerDay(int noOfPastDays = 7)
    {
        DateTime today = DateTime.Now.Date;
        DaySummary[] daySummaries = new DaySummary[noOfPastDays];
        // Find the move times for the last seven days excluding today. If the date is missing, then the move time is set to zero.
        for (int i = 1; i <= noOfPastDays; i++)
        {
            DateTime _day = today.AddDays(-i);
            // Get the summary data for this date.
            var _moveTime = AppData.Instance.userData.dTableSession.AsEnumerable()
                .Where(row => DateTime.ParseExact(row.Field<string>(dateTime),DataManager.DATEFORMAT, CultureInfo.InvariantCulture).Date == _day)
                .Sum(row => Convert.ToInt32(row[moveTime]));
            // Create the day summary.
            daySummaries[i - 1] = new DaySummary
            {
                Day = Miscellaneous.GetAbbreviatedDayName(_day.DayOfWeek),
                Date = _day.ToString("dd/MM"),
                MoveTime = _moveTime / 60f
            };
            //Debug.Log($"{i} | {daySummaries[i - 1].Day} | {daySummaries[i - 1].Date} | {daySummaries[i - 1].MoveTime}");
        }
        return daySummaries;
    }
}
public static class Others
{
    public static float gameTime = 0f;
    public static float highestSuccessRate = 0f;
    public static string GetAbbreviatedDayName(DayOfWeek dayOfWeek)
    {
        return dayOfWeek.ToString().Substring(0, 3);
    }
}
public class MarsMovement
{
    //public static readonly Dictionary<string, float> DefaultMechanismSpeeds = new Dictionary<string, float>
    //{
    //    { "WFE", 10.0f },
    //    { "WURD", 10.0f },
    //    { "FPS", 10.0f },
    //    { "HOC", 10.0f },
    //    { "FME1", 10.0f },
    //    { "FME2", 10.0f },
    //};
    // public static string MECHPATH { get; private set; } = DataManager.mechPath;
    public string name { get; private set; }
    public string side { get; private set; }
    public bool promCompleted { get; private set; }
    public bool aromCompleted { get; private set; }
    public bool apromCompleted { get; private set; }
    public bool romCompleted { get; private set; }
    public ROM oldRom { get; private set; }
    public ROM newRom { get; private set; }
    public ROM currRom { get => newRom.isRomSet ? newRom : (oldRom.isRomSet ? oldRom : null); }
    public float currSpeed { get; private set; } = -1f;
    // Trial details for the mechanism.
    public int trialNumberDay { get; private set; }
    public int trialNumberSession { get; private set; }


    public MarsMovement(string name, string side, int sessno)
    {
        this.name = name?.ToUpper() ?? string.Empty;
        this.side = side;
        oldRom = new ROM(this.name);
        newRom = new ROM();
        //promCompleted = false;
        //aromCompleted = false;
        //apromCompleted = false;
        romCompleted = false;
        this.side = side;
        //currSpeed = -1f;
        UpdateTrialNumbers(sessno);
    }

    public bool IsMarsSupport(string movName) => string.Equals(name, movName, StringComparison.OrdinalIgnoreCase);
    
    public bool IsSide(string sideName) => string.Equals(side, sideName, StringComparison.OrdinalIgnoreCase);

    public bool IsSpeedUpdated() => currSpeed > 0;

    public void NextTrail()
    {
        trialNumberDay += 1;
        trialNumberSession += 1;
    }

    public float[] CurrentArom => currRom == null ? null : new float[] { currRom.aromMin, currRom.aromMax };
    public float[] CurrentProm => currRom == null ? null : new float[] { currRom.promMin, currRom.promMax };
    public float[] CurrentAProm => currRom == null ? null : new float[] { currRom.apromMin, currRom.apromMax };
    public void ResetRomValues()
    {
        newRom.setRom(0, 0,0,0);
        romCompleted = false;
    }



    public void SetNewRomValues(float minx, float maxx, float miny, float maxy)
    {
        newRom.setRom(minx,maxx,miny,maxy);
        if (minx != 0 || maxx != 0 || miny!=0 || maxy!=0) romCompleted = true;
        // Cehck if newRom's mechanism needs to be set.
        if (newRom.movement == null)
        {
            newRom.SetMovement(this.name);
        }
    }


    public void SaveAssessmentData()
    {
        if (romCompleted)
        {
            // Save the new ROM values to the file.
            newRom.WriteToAssessmentFile();
        }
    }
    /*
     * Function to update the trial numbers for the day and session for the mechanism for today.
     */
    public void UpdateTrialNumbers(int sessno)
    {
        // Get the last row for the today, for the selected MarsSupport.
        var selRows = AppData.Instance.userData.dTableSession.AsEnumerable()?
            .Where(row => DateTime.ParseExact(row.Field<string>("DateTime"), DataManager.DATEFORMAT, CultureInfo.InvariantCulture).Date == DateTime.Now.Date)
            .Where(row => row.Field<string>("Movment") == this.name);

        // Check if the selected rows is null.
        if (selRows.Count() == 0)
        {
            // Set the trial numbers to 1.
            trialNumberDay = 0;
            trialNumberSession = 0;
            return;
        }
        // Get the trial number as the maximum number for the trialNumber Day.
        trialNumberDay = selRows.Max(row => Convert.ToInt32(row.Field<string>("TrialNumberDay")));

        // Now let's get the session number for the current session.
        selRows = AppData.Instance.userData.dTableSession.AsEnumerable()?
            .Where(row => DateTime.ParseExact(row.Field<string>("DateTime"), DataManager.DATEFORMAT, CultureInfo.InvariantCulture).Date == DateTime.Now.Date)
            .Where(row => Convert.ToInt32(row.Field<string>("SessionNumber")) == sessno)
            .Where(row => row.Field<string>("Movement") == this.name);
        if (selRows.Count() == 0)
        {
            // Set the trial numbers to 1.
            trialNumberSession = 0;
            return;
        }
        // Get the maximum trial number for the session.
        UnityEngine.Debug.Log(selRows.Count());
        trialNumberSession = selRows.Max(row => Convert.ToInt32(row.Field<string>("TrialNumberSession")));
    }
}
public class ROM
{
    public static string[] FILEHEADER = new string[] {
        "DateTime", "MinX","MaxX","MinY","MaxY"
    };
    // Class attributes to store data read from the file
    public string datetime;
    public float MinX {  get; private set; }
    public float MaxX { get; private set; }
    public float MinY { get; private set; }
    public float MaxY { get; private set; }
    public string mode { get; private set; }
    public bool isRomXSet { get => MinX != 0 || MaxX != 0; }
    public bool isRomYSet { get => MinY != 0 || MaxY != 0; }

    public bool isRomSet { get => isRomXSet && isRomYSet; }

    public string movement { get; private set; }

   
  

    // Constructor that reads the file and initializes values based on the mechanism
    public ROM(string movementName, bool readFromFile = true)
    {
        if (readFromFile) ReadFromFile(movementName);
        else
        {
            // Handle case when no matching mechanism is found
            datetime = null;
            movement = movementName;
            MinX = 0;
            MaxX = 0;
            MinY = 0;
            MaxY = 0;
          
        }
    }

    public ROM(float angmin, float angmax, float aromAngMin, float aromAngMax, string mov, bool tofile)
    {
        MinX = angmin;
        MaxX = angmax;
        MinY = aromAngMin;
        MaxY = aromAngMax;
        movement = mov;
        datetime = DateTime.Now.ToString();
        if (tofile) WriteToAssessmentFile();
    }

    public ROM()
    {
        MinX = 0;
        MaxX = 0;
        MinY = 0;
        MaxY = 0;
        mode = null;
        movement = null;
        datetime = null;
    }

    public void SetMovement(string mov) => movement = (movement == null) ? mov : movement;
    public void SetMarsMode(string Mode) => mode = (mode == null) ? Mode : mode; // fws,hws,nws modes


    public void setRom(float Minx , float Maxx, float Miny, float Maxy)
    {
        MinX = Minx;
        MaxX = Maxx;
        MinY = Miny;
        MaxY = Maxy;
        datetime = DateTime.Now.ToString();
    }
    public void WriteToAssessmentFile()
    {
        string fileName = DataManager.GetRomFileName(movement,mode); ;
        using (StreamWriter file = new StreamWriter(fileName, true))
        {
            file.WriteLine(string.Join(",", new string[] { datetime, MinX.ToString(), MaxX.ToString(), MinY.ToString(), MaxY.ToString()}));
        }
    }

    private void ReadFromFile(string movementName)
    {
        string fileName = DataManager.GetRomFileName(movementName, mode);
        // Create the file if it doesn't exist
        if (!File.Exists(fileName))
        {
            using (var writer = new StreamWriter(fileName, false, Encoding.UTF8))
            {
                writer.WriteLine(string.Join(",", FILEHEADER));
            }
        }
        // Read file.
        DataTable romData = DataManager.loadCSV(fileName);
        // Check the number of rows.
        if (romData.Rows.Count == 0)
        {
            // Set default values for the mechanism.
            datetime = null;
            movement = movementName;
            MinX = 0;
            MaxX = 0;
            MinY = 0;
            MaxY = 0;
            return;
        }
        // Assign ROM from the last row.
        datetime = romData.Rows[romData.Rows.Count - 1].Field<string>("DateTime");
        movement = movementName;
        MinX = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("MinX"));
        MaxX = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("MaxX"));
        MinY = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("MinY"));
        MaxY = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("MaxY"));

    }
}


public static class Miscellaneous
{
    public static string GetAbbreviatedDayName(DayOfWeek dayOfWeek)
    {
        return dayOfWeek.ToString().Substring(0, 3);
    }
}



