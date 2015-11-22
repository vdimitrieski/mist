DROP TABLE TeachesClasses;        
DROP TABLE AssistsInLabs;        
DROP TABLE Asistant;        
DROP TABLE Teacher;        
DROP TABLE Employee;        
DROP TABLE TeachingStuff;        
DROP TABLE Passes;        
DROP TABLE Takes;        
DROP TABLE NonTeachingStuff;        
DROP TABLE Chair;        
DROP TABLE Faculty;        
DROP TABLE Subject;        
DROP TABLE Student;        

CREATE TABLE Student (
	studentName varchar(20) NOT NULL ,
	studentSurname varchar(20) NOT NULL ,
	studentID int NOT NULL ,
	studentYear int NOT NULL 
	,
	CONSTRAINT PK_STUDENT PRIMARY KEY (studentYear, studentID, studentSurname)
);

CREATE TABLE Subject (
	subjectID int NOT NULL ,
	subjectName varchar(20) NOT NULL 
	,
	CONSTRAINT PK_SUBJECT PRIMARY KEY (subjectID)
);

CREATE TABLE Faculty (
	facultyID int NOT NULL ,
	facultyName varchar(20) NOT NULL 
	,
	CONSTRAINT PK_FACULTY PRIMARY KEY (facultyID)
);

CREATE TABLE Chair (
	chairName varchar(20) NOT NULL ,
	facultyID int NOT NULL 
	,
	CONSTRAINT PK_CHAIR PRIMARY KEY (facultyID, chairName),
	CONSTRAINT FK_CHAIR_FACULTY FOREIGN KEY (facultyID) REFERENCES Faculty (facultyID)
);

CREATE TABLE NonTeachingStuff (
	nonTeachingStuffID int NOT NULL ,
	nonTeachingStuffPosition varchar(20) NOT NULL 
	,
	CONSTRAINT PK_NONTEACHINGSTUFF PRIMARY KEY (nonTeachingStuffID)
);

CREATE TABLE Takes (
	studentYear int NOT NULL ,
	studentID int NOT NULL ,
	studentSurname varchar(20) NOT NULL ,
	subjectID int NOT NULL 
	,
	CONSTRAINT PK_TAKES PRIMARY KEY (studentYear, studentID, studentSurname, subjectID),
	CONSTRAINT FK_TAKES_STUDENT FOREIGN KEY (studentYear, studentID, studentSurname) REFERENCES Student (studentYear, studentID, studentSurname),
	CONSTRAINT FK_TAKES_SUBJECT FOREIGN KEY (subjectID) REFERENCES Subject (subjectID)
);

CREATE TABLE Passes (
	grade int NOT NULL ,
	examDate date NOT NULL ,
	subjectID int NOT NULL ,
	studentYear int NOT NULL ,
	studentID int NOT NULL ,
	studentSurname varchar(20) NOT NULL 
	,
	CONSTRAINT PK_PASSES PRIMARY KEY (subjectID, studentYear, studentID, studentSurname),
	CONSTRAINT FK_PASSES_SUBJECT FOREIGN KEY (subjectID) REFERENCES Subject (subjectID),
	CONSTRAINT FK_PASSES_STUDENT FOREIGN KEY (studentYear, studentID, studentSurname) REFERENCES Student (studentYear, studentID, studentSurname)
);

CREATE TABLE TeachingStuff (
	teachingStuffID int NOT NULL ,
	teachingStuffTitle varchar(20) NOT NULL ,
	chairName varchar(20) NOT NULL ,
	facultyID int NOT NULL 
	,
	CONSTRAINT PK_TEACHINGSTUFF PRIMARY KEY (teachingStuffID),
	CONSTRAINT FK_TEACHINGSTUFF_CHAIR FOREIGN KEY (chairName, facultyID) REFERENCES Chair (facultyID, chairName)
);

CREATE OR REPLACE VIEW View_Chair_TeachingStuff AS
    SELECT * FROM Chair chair JOIN TeachingStuff teachingstuff ON chair.facultyID = teachingstuff.facultyID and chair.chairName = teachingstuff.chairName;

CREATE OR REPLACE TRIGGER TRG_IRI_Chair_TeachingStuff_View
INSTEAD OF INSERT ON View_Chair_TeachingStuff
FOR EACH ROW
DECLARE
    I NUMBER;
    Exc EXCEPTION;
    t Chair%ROWTYPE;
BEGIN
    SELECT COUNT(*) INTO I 
        FROM Chair 
        WHERE (facultyID = :NEW.facultyID and chairName = :NEW.chairName);
    IF I <> 0 THEN
        INSERT INTO TeachingStuff (teachingStuffID, teachingStuffTitle, chairName, facultyID) VALUES (:NEW.teachingStuffID, :NEW.teachingStuffTitle, :NEW.chairName, :NEW.facultyID);
    ELSE
        IRI_Chair_TeachingStuff_PCK.Trigger_Ex := FALSE;
        INSERT INTO Chair (chairName, facultyID) VALUES (:NEW.chairName, :NEW.facultyID);
        INSERT INTO TeachingStuff (teachingStuffID, teachingStuffTitle, chairName, facultyID) VALUES (:NEW.teachingStuffID, :NEW.teachingStuffTitle, :NEW.chairName, :NEW.facultyID);
        IRI_Chair_TeachingStuff_PCK.Trigger_Ex := TRUE;
        SELECT * INTO t
            FROM Chair WHERE (chairName = :NEW.chairName and facultyID = :NEW.facultyID);
        IF NOT Global_PCK.ContainmentIRI_Chair(t) THEN
            RAISE Exc;
        END IF;
    END IF:
    EXCEPTION WHEN Exc THEN
        RAISE_APPLICATION_ERROR (-20001,'IRIC violation!');
END;

CREATE OR REPLACE PACKAGE IRI_Chair_TeachingStuff_PCK
IS
    TYPE TRecTeachingStuff IS RECORD (teachingStuffID TeachingStuff.teachingStuffID%TYPE, teachingStuffTitle TeachingStuff.teachingStuffTitle%TYPE, chairName TeachingStuff.chairName%TYPE, facultyID TeachingStuff.facultyID%TYPE);
    TYPE TTabForDelUpd IS TABLE OF TRecTeachingStuff INDEX BY BINARY_INTEGER;
    For_TeachingStuff TTabForDelUpd;
    Count_IRI NUMBER(8,0);
    Trigger_Ex BOOLEAN;
END;

FUNCTION ContainmentIRI_Chair (v IN Chair%ROWTYPE)
RETURN BOOLEAN
IS
    I NUMBER;
BEGIN
    SELECT COUNT(*) INTO I FROM TeachingStuff u
        WHERE (u.facultyID = v.facultyID and u.chairName = v.chairName);
    IF I <> 0 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;

CREATE OR REPLACE TRIGGER TRG_TeachingStuff_IRI_Chair_TeachingStuff_DEL1
BEFORE DELETE TeachingStuff
BEGIN
    IRI_Chair_TeachingStuff_PCK.Count_IRI := 0;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff.DELETE;
END;

CREATE OR REPLACE TRIGGER TRG_TeachingStuff_IRI_Chair_TeachingStuff_DEL2
BEFORE DELETE ON TeachingStuff
FOR EACH ROW
DECLARE
    u TeachingStuff%ROWTYPE;
BEGIN
    u.teachingStuffID := :OLD.teachingStuffID;
    u.teachingStuffTitle := :OLD.teachingStuffTitle;
    u.chairName := :OLD.chairName;
    u.facultyID := :OLD.facultyID;
    IRI_Chair_TeachingStuff_PCK.Count_IRI := IRI_Chair_TeachingStuff_PCK.Count_IRI + 1;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            teachingStuffID := u.teachingStuffID;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            teachingStuffTitle := u.teachingStuffTitle;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            chairName := u.chairName;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            facultyID := u.facultyID;
END;

CREATE OR REPLACE TRIGGER TRG_TeachingStuff_IRI_Chair_TeachingStuff_DEL3
AFTER DELETE ON TeachingStuff
DECLARE
    u TeachingStuff%ROWTYPE;
    I NUMBER;
BEGIN
    FOR j IN 1.. IRI_Chair_TeachingStuff_PCK.Count_IRI LOOP
        u.teachingStuffID := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).teachingStuffID;
        u.teachingStuffTitle := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).teachingStuffTitle;
        u.chairName := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).chairName;
        u.facultyID := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).facultyID;
        SELECT COUNT(*) INTO I FROM Chair
            WHERE (facultyID = u.facultyID and chairName = u.chairName);
        IF I <> 0 THEN
            Cascade_IRI_Del_TeachingStuff(u)
        END IF;
    END LOOP;
END;

PROCEDURE CascadeIRI_Del_TeachingStuff (u IN TeachingStuff%ROWTYPE)
IS
BEGIN
    DELETE FROM Chair v WHERE (v.facultyID = u.facultyID and v.chairName = u.chairName);
END;
        
CREATE OR REPLACE TRIGGER TRG_Chair_IRI_Chair_TeachingStuff_DEL1
BEFORE DELETE Chair
BEGIN
    IRI_Chair_TeachingStuff_PCK.Count_IRI := 0;
    IRI_Chair_TeachingStuff_PCK.For_Chair.DELETE;
END;

CREATE OR REPLACE TRIGGER TRG_Chair_IRI_Chair_TeachingStuff_DEL2
BEFORE DELETE ON Chair
FOR EACH ROW
DECLARE
    u Chair%ROWTYPE;
BEGIN
    u.chairName := :OLD.chairName;
    u.facultyID := :OLD.facultyID;
    IRI_Chair_TeachingStuff_PCK.Count_IRI := IRI_Chair_TeachingStuff_PCK.Count_IRI + 1;
    IRI_Chair_TeachingStuff_PCK.For_Chair (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            teachingStuffID := u.teachingStuffID;
    IRI_Chair_TeachingStuff_PCK.For_Chair (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            teachingStuffTitle := u.teachingStuffTitle;
    IRI_Chair_TeachingStuff_PCK.For_Chair (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            chairName := u.chairName;
    IRI_Chair_TeachingStuff_PCK.For_Chair (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            facultyID := u.facultyID;
END;

CREATE OR REPLACE TRIGGER TRG_Chair_IRI_Chair_TeachingStuff_DEL3
AFTER DELETE ON Chair
DECLARE
    u Chair%ROWTYPE;
    I NUMBER;
BEGIN
    FOR j IN 1.. IRI_Chair_TeachingStuff_PCK.Count_IRI LOOP
        u.chairName := IRI_Chair_TeachingStuff_PCK.For_Chair (j).chairName;
        u.facultyID := IRI_Chair_TeachingStuff_PCK.For_Chair (j).facultyID;
        SELECT COUNT(*) INTO I FROM TeachingStuff
            WHERE (teachingStuffID = u.teachingStuffID);
        IF I <> 0 THEN
            Cascade_IRI_Del_Chair(u)
        END IF;
    END LOOP;
END;

PROCEDURE CascadeIRI_Del_Chair (u IN Chair%ROWTYPE)
IS
BEGIN
    DELETE FROM TeachingStuff v WHERE (v.teachingStuffID = u.teachingStuffID);
END;

CREATE OR REPLACE TRIGGER TRG_TeachingStuff_IRI_Chair_TeachingStuff_UPD1
BEFORE UPDATE ON TeachingStuff
BEGIN
    IRI_Chair_TeachingStuff_PCK.Count_IRI := 0;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff.DELETE;
END;

CREATE OR REPLACE TRIGGER TRG_TeachingStuff_IRI_Chair_TeachingStuff_UPD2
BEFORE UPDATE ON TeachingStuff
FOR EACH ROW
WHEN (NEW.teachingStuffID <> OLD.teachingStuffID or NEW.teachingStuffTitle <> OLD.teachingStuffTitle or NEW.chairName <> OLD.chairName or NEW.facultyID <> OLD.facultyID)
DECLARE
    u TeachingStuff%ROWTYPE;
BEGIN
    u.teachingStuffID := :OLD.teachingStuffID;
    u.teachingStuffTitle := :OLD.teachingStuffTitle;
    u.chairName := :OLD.chairName;
    u.facultyID := :OLD.facultyID;
    IRI_Chair_TeachingStuff_PCK.Count_IRI := IRI_Chair_TeachingStuff_PCK.Count_IRI + 1;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            teachingStuffID := u.teachingStuffID;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            teachingStuffTitle := u.teachingStuffTitle;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            chairName := u.chairName;
    IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            facultyID := u.facultyID;
END;

CREATE OR REPLACE TRIGGER TRG_TeachingStuff_IRI_Chair_TeachingStuff_UPD3
AFTER UPDATE ON TeachingStuff
DECLARE
    u TeachingStuff%ROWTYPE;
    I NUMBER;
BEGIN
    FOR j IN 1..IRI_Chair_TeachingStuff_PCK.Count_IRI LOOP
        u.teachingStuffID := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).teachingStuffID;
        u.teachingStuffTitle := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).teachingStuffTitle;
        u.chairName := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).chairName;
        u.facultyID := IRI_Chair_TeachingStuff_PCK.For_TeachingStuff (j).facultyID;
        SELECT COUNT(*) INTO I FROM Chair 
            WHERE (facultyID = u.facultyID and chairName = u.chairName);
        IF I <> 0 THEN
            RAISE_APPLICATION_ERROR (-20002,'Tuple modification is forbidden TeachingStuff');
        END IF;
    END LOOP;
END;

CREATE OR REPLACE TRIGGER TRG_Chair_IRI_Chair_TeachingStuff_UPD1
BEFORE UPDATE ON Chair
BEGIN
    IRI_Chair_TeachingStuff_PCK.Count_IRI := 0;
    IRI_Chair_TeachingStuff_PCK.For_Chair.DELETE;
END;

CREATE OR REPLACE TRIGGER TRG_Chair_IRI_Chair_TeachingStuff_UPD2
BEFORE UPDATE ON Chair
FOR EACH ROW
WHEN (NEW.chairName <> OLD.chairName or NEW.facultyID <> OLD.facultyID)
DECLARE
    u Chair%ROWTYPE;
BEGIN
    u.chairName := :OLD.chairName;
    u.facultyID := :OLD.facultyID;
    IRI_Chair_TeachingStuff_PCK.Count_IRI := IRI_Chair_TeachingStuff_PCK.Count_IRI + 1;
    IRI_Chair_TeachingStuff_PCK.For_Chair (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            chairName := u.chairName;
    IRI_Chair_TeachingStuff_PCK.For_Chair (IRI_Chair_TeachingStuff_PCK.Count_IRI).
            facultyID := u.facultyID;
END;

CREATE OR REPLACE TRIGGER TRG_Chair_IRI_Chair_TeachingStuff_UPD3
AFTER UPDATE ON Chair
DECLARE
    u Chair%ROWTYPE;
    I NUMBER;
BEGIN
    FOR j IN 1..IRI_Chair_TeachingStuff_PCK.Count_IRI LOOP
        u.chairName := IRI_Chair_TeachingStuff_PCK.For_Chair (j).chairName;
        u.facultyID := IRI_Chair_TeachingStuff_PCK.For_Chair (j).facultyID;
        SELECT COUNT(*) INTO I FROM TeachingStuff 
            WHERE (teachingStuffID = u.teachingStuffID);
        IF I <> 0 THEN
            RAISE_APPLICATION_ERROR (-20002,'Tuple modification is forbidden Chair');
        END IF;
    END LOOP;
END;
CREATE TABLE Employee (
	employeeID int NOT NULL ,
	employeeName varchar(20) NOT NULL ,
	employeeSurname varchar(20) NOT NULL ,
	nonTeachingStuffID int NOT NULL ,
	teachingStuffID int NOT NULL 
	,
	CONSTRAINT PK_EMPLOYEE PRIMARY KEY (employeeID),
	CONSTRAINT FK_EMPLOYEE_NONTEACHINGSTUFF FOREIGN KEY (nonTeachingStuffID) REFERENCES NonTeachingStuff (nonTeachingStuffID),
	CONSTRAINT FK_EMPLOYEE_TEACHINGSTUFF FOREIGN KEY (teachingStuffID) REFERENCES TeachingStuff (teachingStuffID)
);

CREATE TABLE Teacher (
	teachingStuffID int NOT NULL 
	,
	CONSTRAINT PK_TEACHER PRIMARY KEY (teachingStuffID),
	CONSTRAINT FK_TEACHER_TEACHINGSTUFF FOREIGN KEY (teachingStuffID) REFERENCES TeachingStuff (teachingStuffID)
);

CREATE TABLE Asistant (
	teachingStuffID int NOT NULL 
	,
	CONSTRAINT PK_ASISTANT PRIMARY KEY (teachingStuffID),
	CONSTRAINT FK_ASISTANT_TEACHINGSTUFF FOREIGN KEY (teachingStuffID) REFERENCES TeachingStuff (teachingStuffID)
);

CREATE TABLE AssistsInLabs (
	teachingStuffID int NOT NULL ,
	subjectID int NOT NULL 
	,
	CONSTRAINT PK_ASSISTSINLABS PRIMARY KEY (teachingStuffID, subjectID),
	CONSTRAINT FK_ASSISTSINLABS_TEACHINGSTUFF FOREIGN KEY (teachingStuffID) REFERENCES TeachingStuff (teachingStuffID),
	CONSTRAINT FK_ASSISTSINLABS_SUBJECT FOREIGN KEY (subjectID) REFERENCES Subject (subjectID)
);

CREATE TABLE TeachesClasses (
	classDate date NOT NULL ,
	classTime time NOT NULL ,
	teachingStuffID int NOT NULL ,
	subjectID int NOT NULL ,
	subjectID_TeachesLabs int NOT NULL 
	,
	CONSTRAINT PK_TEACHESCLASSES PRIMARY KEY (teachingStuffID, subjectID),
	CONSTRAINT FK_TEACHESCLASSES_TEACHINGSTUFF FOREIGN KEY (teachingStuffID) REFERENCES TeachingStuff (teachingStuffID),
	CONSTRAINT FK_TEACHESCLASSES_SUBJECT FOREIGN KEY (subjectID) REFERENCES Subject (subjectID),
	CONSTRAINT FK_TEACHESCLASSES_SUBJECT_TEACHESLABS FOREIGN KEY (subjectID_TeachesLabs) REFERENCES Subject (subjectID)
);

