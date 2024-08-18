--Renaming the table in the database to better reflect the type of data it contains to enahnce clarity and ensue that table's purpose is immediately understood
EXEC sp_rename 'dbo.hospital_admission', 'patients_admission';

--Previewing the Dataset
SELECT *
FROM dbo.patients_admission;

--Updating the values of the gender column of the dbo.hospital_admission table
UPDATE dbo.patients_admission
SET Gender =
            CASE
			--Change 'M' to 'Male'
			   WHEN Gender = 'M' THEN 'Male'
			--Change 'F' to 'Female'
			   WHEN Gender = 'F' THEN 'Female'
			--Leave other values unchanged
			   ELSE Gender
			END;

--Updating the values of the Locality column of the dbo.hospital_admission table
UPDATE dbo.patients_admission
SET Locality =
              CASE
			  --Change 'R' to 'Rural'
			    WHEN Locality = 'R' THEN 'Rural'
			  --Change 'U' to 'Urban'
			    WHEN Locality = 'U' THEN 'Urban'
			  --Leave other values unchanged
			    ELSE Locality
			  END;

--Updating the values of the Type_of_Admission Column of the dbo.hospital_admission table
UPDATE dbo.patients_admission
SET Type_of_admission =
                       CASE 
					  --Change 'E' to 'Emergency'
					     WHEN Type_of_admission = 'E' THEN 'Emergency'
					  --Change 'O' to 'Outpatient'
					     WHEN Type_of_admission = 'O' THEN 'Outpatient'
					  --Leave other values unchanged
					     ELSE Type_of_admission
					   END;


--Gender Distribution
SELECT Gender, Count(*) AS Number_of_patients
FROM dbo.patients_admission
GROUP BY Gender
ORDER BY Number_of_patients DESC
--From the result we have more male patients (9990) than female patients(5767)

--Average age of patients
SELECT AVG(Age) AS Average_Age
FROM dbo.patients_admission;
--From the result, the average age of the patients is 61

--Distribution of Outcome
WITH OutcomeDistribution AS(
     SELECT 
	      Outcome, COUNT(*) AS OutcomeCount
	 FROM dbo.patients_admission
	 GROUP BY Outcome
	 )
SELECT *
FROM OutcomeDistribution;
--From the result, 13756 patients were discharged, 1105 patients Expired/died and 896 Patients were discharged against medical advice.

--Calculating the percentage rate for Expiry, Discharge and DAMA(Discharged against medical advice)
WITH OutcomeRate AS(
       SELECT 
                   ROUND((SUM(CASE WHEN Outcome = 'EXPIRY' THEN 1 ELSE 0 END)*100.0)/COUNT(*),2) AS MortalityRate,
	               ROUND((SUM(CASE WHEN Outcome = 'Discharge' THEN 1 ELSE 0 END)*100.0)/COUNT(*),2) AS DischargeRate,
		           ROUND((SUM(CASE WHEN Outcome = 'DAMA' THEN 1 ELSE 0 END)*100.0)/COUNT(*),2) AS DAMARate
       FROM dbo.patients_admission
	   )
SELECT *
FROM OutcomeRate;
--From the result, Mortality Rate is 7%, Discharge Rate is 87%, DAMA(Discharged against medical advice)Rate is 5.7&

--Readmission rate analysis
--Patients with multiple admission
SELECT MRD_no, Count(*) AS Number_of_Admission
from dbo.patients_admission
GROUP BY MRD_no
HAVING COUNT(*) > 1
ORDER BY Number_of_Admission DESC;

--Calculating the Readmission rate percentage
WITH ReadnissionRate AS (
      SELECT 
	     a.MRD_no
	  FROM dbo.patients_admission a
	  JOIN dbo.patients_admission b
	  ON a.MRD_no = b.MRD_no
	  AND a.Date_of_discharge < b.Date_of_admission
	  GROUP BY a.MRD_no
),

TotalPatients AS (
       SELECT DISTINCT MRD_no
	   FROM dbo.patients_admission
)

SELECT 
     (COUNT(DISTINCT r.MRD_no)*100.0/ COUNT(t.MRD_no)) AS readmission_rate_percentage
FROM TotalPatients t
LEFT JOIN ReadnissionRate r
ON t.MRD_no = r.MRD_no;
--From the result, the readmission rate percentage is 22.3%

--Demographic analysis
--Retrieving the number of patients in each locality(Rural/Urban)
SELECT Locality, COUNT(*) Number_of_patients
FROM dbo.patients_admission
GROUP BY Locality
ORDER BY Number_of_patients DESC;
--From the result, 12077 patients Lived in the urban area, 3680 patients lived in rural areas.

--Influence of patients locality on readmission
WITH PatientAdmissions AS (
    SELECT 
        MRD_no, Locality, COUNT(*) AS AdmissionCount
    FROM dbo.patients_admission
    GROUP BY MRD_no, Locality
),
Readmissions AS (
    SELECT 
        Locality, COUNT(*) AS ReadmissionCount
    FROM PatientAdmissions
    WHERE AdmissionCount > 1
    GROUP BY Locality
),
TotalAdmissions AS (
    SELECT 
        Locality, COUNT(*) AS TotalCount
    FROM dbo.patients_admission
    GROUP BY Locality
)
SELECT 
    t.Locality,
    ROUND((COALESCE(r.ReadmissionCount, 0) * 100.0) / t.TotalCount, 2) AS ReadmissionRate
FROM TotalAdmissions t
LEFT JOIN Readmissions r 
ON t.Locality = r.Locality
GROUP BY  t.Locality, t.TotalCount,r.ReadmissionCount;
--From the result, the readmission rate percentage pf urban locality is 16.4% while the readmission rate of rural localit is 11.8%

--Influence of patients locality on mortality rate
SELECT Locality, COUNT(*) AS Mortality_rate
FROM dbo.patients_admission
WHERE Outcome = 'EXPIRY'
GROUP BY Locality
ORDER BY Mortality_rate DESC;
--From the result, there is a higher mortality rate among patients in the urban area(827) than patients in rural areas(278)

--Admission type (Emergency /Outpatient) Distribution
SELECT Type_of_admission, COUNT(*)Total_Admission
FROM dbo.patients_admission
GROUP BY Type_of_admission
ORDER BY Total_Admission DESC
--From the result, there were 10924 Emergency patients and 4833 Outpatients

--Comparing the mortality rate between Emergency patients and Outpatients
SELECT 
     Type_of_admission,
	 ROUND(SUM(CASE WHEN Outcome = 'EXPIRY' THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS Mortality_rate
FROM dbo.patients_admission
GROUP BY Type_of_admission;
--From the result, the mortality rate among emergency patients was 9.86% while the mortality rate among Outpatient was 0.58%


--Creating  two new columns in the Table which will contain the Month and Year that will be extracted from Date_of_admission column. 
--This is necessary for my time series analysis

--Creating the Admission_month column 
ALTER TABLE dbo.patients_admission
ADD Admission_month NVARCHAR(50);

UPDATE dbo.patients_admission
SET Admission_month = DATENAME(MONTH, Date_of_admission);

--Creating the Admission_year column
ALTER TABLE dbo.patients_admission
ADD Admission_year INT;

UPDATE dbo.patients_admission
SET Admission_year = YEAR(Date_of_admission);


--Retrieving the number of admission in each month of each year
SELECT 
      Admission_month, Admission_year, COUNT(*) AS Number_of_Admission
FROM dbo.patients_admission
WHERE Admission_year = 2017
GROUP BY Admission_month, Admission_year
ORDER BY  Number_of_Admission DESC;


SELECT 
      Admission_month, Admission_year, COUNT(*) AS Number_of_Admission
FROM dbo.patients_admission
WHERE Admission_year = 2018
GROUP BY Admission_month, Admission_year
ORDER BY Number_of_Admission DESC;


SELECT 
      Admission_month, Admission_year, COUNT(*) AS Number_of_Admission
FROM dbo.patients_admission
WHERE Admission_year = 2019
GROUP BY Admission_month, Admission_year
ORDER BY  Number_of_Admission DESC;

--Monthly Patient Admissions
SELECT 
      Admission_month, COUNT(*) AS Number_of_Admission
FROM dbo.patients_admission
GROUP BY Admission_month
ORDER BY  Number_of_Admission DESC;

--Retrieving the quarter with highest admission rate
WITH AdmissionPerQuarter AS(
     SELECT
	      Admission_year, DATEPART(QUARTER, Date_of_admission) AS Quarter, COUNT(*)AS total_admission
	 FROM dbo.patients_admission
	 GROUP BY Admission_year, DATEPART(QUARTER, Date_of_admission)
),
QuarterlyRank AS (
          SELECT 
		       Admission_year, Quarter, total_admission,
			   ROW_NUMBER() OVER (PARTITION BY Admission_year ORDER BY Total_admission DESC) AS Quarter_rank 
		  FROM AdmissionPerQuarter
)
SELECT 
      Admission_year, Quarter, total_admission
FROM QuarterlyRank 
WHERE Quarter_rank = 1
ORDER BY  Admission_year DESC;
--From the result, in 2019, the highest admission rate was recorded in the 1st quarter, in 2018, we have the 4th quarter, in 2017, we have the 4th quarter.

--Calculating the year over year admission rate
WITH AdmissionPerYear AS (
     SELECT 
	       Admission_year, COUNT(*) AS total_admission
	 FROM dbo.patients_admission
	 GROUP BY Admission_year
),
YearlyChange AS (
      SELECT 
	        Admission_year, total_admission,
			LAG(total_admission) OVER (ORDER BY Admission_year) AS Previous_year_admission
	 FROM AdmissionPerYear
)
SELECT 
     Admission_year, total_admission, previous_year_admission,
	 CASE 
	    WHEN Previous_year_admission IS NULL THEN NULL
		ELSE ((total_admission - previous_year_admission)*100.0/previous_year_admission)
	 END  AS Percentage_increase
FROM YearlyChange
ORDER BY Admission_year;
--From the result, the percentage increase of 2017 from the previous year is NULL because theres no data for 2016
--There was 39.81% growth from 2017 in 2018. And admission rate dropped by 69.22% in 2019.

--Retrieving the average duration of stay and average duration of intensive unit stay for each admission type (Emergency/Outpatient)
SELECT Type_of_admission, AVG(Duration_of_stay) AS Average_Duration_of_stay
FROM dbo.patients_admission
GROUP BY Type_of_admission
--Average Duration of Stay of Emergency patients is 7days while the average duration of stay of Outpatients is 5Days.

SELECT Type_of_admission, AVG(Duration_of_intensive_unit_stay) AS Average_Duration_of_Intensive_Unit_stay
FROM dbo.patients_admission
GROUP BY Type_of_admission ;
--Average duration of stay of Emergency patients in Intensive care unit is 4days while that of the Outpatients is 1day. 

--Patient's history. This include Smoking, Alcohol, Diabetes mellitus, hypertension, prior coronary artery disease, 
--Prior cardiomyopathy and chronic kidney disease.

--Retrieving the number of patients with any history of the specified conditions
SELECT COUNT(DISTINCT MRD_no)AS Patients_with_prior_history
FROM dbo.patients_admission
WHERE Smoking = 1 OR Alcohol = 1 OR Diabetes_mellitus = 1 OR Hypertension = 1 
OR Prior_coronary_artery_disease = 1 OR Prior_cardiomyopathy = 1 OR Chronic_kidney_disease = 1
--From the result, 10484 Patients have prior history of any of the specified condition

--Prevalence of Smoking, Alcohol, Diabetes mellitus, Hypertension, Prior coronary artery disease, 
--prior cardiomyopathy and chronic kidney disease among patients
SELECT 
     (SUM(CASE WHEN Smoking = 1 THEN 1 ELSE 0 END)*100.0)/COUNT(*) AS Smoking_prevalence,
	 (SUM(CASE WHEN Alcohol = 1 THEN 1 ELSE 0 END)*100.0)/COUNT(*) AS Alcohol_prevalence,
	 (SUM(CASE WHEN Diabetes_mellitus = 1 THEN 1 ELSE 0 END)* 100.0)/COUNT(*) AS DM_Prevalence,
	 (SUM(CASE WHEN Hypertension = 1 THEN 1 ELSE 0 END)* 100.0)/COUNT(*) AS Hypertension_Prevalence,
     (SUM(CASE WHEN Prior_coronary_artery_disease = 1 THEN 1 ELSE 0 END)* 100.0)/COUNT(*) AS CAD_Prevalence,
     (SUM(CASE WHEN Prior_cardiomyopathy = 1 THEN 1 ELSE 0 END)* 100.0)/COUNT(*) AS CAR_Prevalence,
     (SUM(CASE WHEN Chronic_kidney_disease = 1 THEN 1 ELSE 0 END)* 100.0)/COUNT(*) AS CKD_Prevalence
FROM dbo.patients_admission;
--From the result, Smoking is 5%, Alcohol is 6%, Diabetes mellitus is 32%, Hypertension is 48%, 
--Prior coronary artery disease is 66%, Prior cardiomyopathy is 15% and Chronic kidney disease is 9%

--Mortality Rate among patients with prior history
SELECT 
     (SUM(CASE WHEN Outcome = 'EXPIRY' AND(
	       Smoking = 1 OR Alcohol= 1 OR
		   Diabetes_mellitus = 1 OR Hypertension = 1 OR
		   Prior_coronary_artery_disease = 1 OR 
		   Prior_cardiomyopathy = 1 OR
		   Chronic_kidney_disease = 1
		   ) THEN 1 ELSE 0 END) * 100.0 /
	  SUM(CASE WHEN Outcome = 'EXPIRY' THEN 1 ELSE 0 END)) AS Mortality_rate
FROM dbo.patients_admission;
--The mortality rate among patients with prior history of any of the above specified condition is 84.34%

--Comparing patients with shock not classsifed as cardiogenic shock  and  patients with shock classified as cardiogenic shock
SELECT 
     COUNT(DISTINCT MRD_no) AS Number_of_patients,
     SUM(CASE WHEN Shock = 1 AND Cardiogenic_shock = 0 THEN 1 ELSE 0 END)AS Number_of_patients_with_shock,
	 SUM(CASE WHEN Cardiogenic_shock = 1 THEN 1 ELSE 0 END) AS Number_of_patients_with_cardiogenic_shock
FROM dbo.patients_admission;
--From the result, the number of patients with shock not classified as Cardiogenis shock is 217 
--The number of patients with shock classified as cardiogenic shock is 944.

--Retrieving patients with heart failure
SELECT 
     MRD_NO, Gender, AGE, Heart_failure,
	 HFREF, HFNEF
FROM dbo.patients_admission
WHERE Heart_failure = 1;

--Percentage of patients with "Heart failure with Reduced Ejection Fraction"(HFREF) and Patients with "Heart failure with Normal Ejection Fraction(HFNEF)
SELECT
    (SUM(CASE WHEN HFREF = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT MRD_no)) AS HFREF_percentage,
    (SUM(CASE WHEN HFNEF = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT MRD_no)) AS HFNEF_percentage
FROM dbo.patients_admission;
--From the result, the HFREF Percentage is 19.77% while the HFNEF Percentage is 17.57%

--Average haemoglobin level by gender
SELECT 
      Gender, ROUND(AVG(Hemoglobin),2) AS Average_haemoglobin_level
FROM dbo.patients_admission
GROUP BY Gender;
--From the result, the average haemoglobin level for male patients is 12.71 while the average haemoglobin level for Female patients is 11.37

--Average Lymphocyte count by gender
SELECT 
      Gender, ROUND(AVG(Total_lymphocyte_count),2) AS Average_lymphocyte_count
FROM dbo.patients_admission
GROUP BY Gender;
--From the result, the average lymphocyte count for male patients is 11.4 while that of female patients is 11.75

--Average Glucose level by gender
SELECT 
      Gender, ROUND(AVG(Glucose),2) AS Average_Glucose_level
FROM dbo.patients_admission
GROUP BY Gender;
--The average glucose level for male patients is 160 while that of female patients is 167

--Average Platelets count by gender
SELECT 
      Gender, ROUND(AVG(Platelets),2) AS Average_platelets_count
FROM dbo.patients_admission
GROUP BY Gender;
--The average platelet count for the male patients is 229.34 while that of the female patients is 254.68

--Average Creatinine level by gender
SELECT 
      Gender, ROUND(AVG(Creatinine),2) AS Average_Creatinine_level
FROM dbo.patients_admission
GROUP BY Gender;
--Average Cretinine level of the male patients is 1.41 while that of the female patients is 1.23

--Patients with Severe anaemia
SELECT 
      COUNT(*) AS Number_of_patients_with_severe_anaemia
FROM dbo.patients_admission
WHERE Severe_anaemia = 1;
--From the result, 305 patients have severe_anaemia