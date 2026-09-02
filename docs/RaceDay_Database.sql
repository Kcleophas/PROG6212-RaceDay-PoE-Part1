USE master;
GO

IF DB_ID('RaceDayDB') IS NOT NULL
BEGIN
    ALTER DATABASE RaceDayDB
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

    DROP DATABASE RaceDayDB;
END;
GO

CREATE DATABASE RaceDayDB;
GO

USE RaceDayDB;
GO

/* ---------------------------------------------------------
   2. USERS
   ERD:
   Users 1 : 0..1 OrganiserProfiles
   Users 1 : 0..1 ParticipantProfiles
   Users 1 : Many Events
   Users 1 : Many Enrolments
   --------------------------------------------------------- */
CREATE TABLE dbo.Users
(
    UserID INT IDENTITY(1,1) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(150) NOT NULL,
    PasswordHash NVARCHAR(255) NOT NULL,
    Role NVARCHAR(20) NOT NULL,
    Phone NVARCHAR(20) NULL,
    CreatedAt DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),
    IsActive BIT NOT NULL
        DEFAULT 1,

    CONSTRAINT PK_Users
        PRIMARY KEY (UserID),

    CONSTRAINT UQ_Users_Email
        UNIQUE (Email),

    CONSTRAINT CK_Users_Role
        CHECK (Role IN ('Organiser', 'Participant'))
);
GO


/* ---------------------------------------------------------
   3. ORGANISER_PROFILES
   UserID is both PK and FK.
   --------------------------------------------------------- */
CREATE TABLE dbo.OrganiserProfiles
(
    UserID INT NOT NULL,
    OrganisationName NVARCHAR(150) NOT NULL,
    OrganisationContactEmail NVARCHAR(150) NULL,

    CONSTRAINT PK_OrganiserProfiles
        PRIMARY KEY (UserID),

    CONSTRAINT FK_OrganiserProfiles_Users
        FOREIGN KEY (UserID)
        REFERENCES dbo.Users(UserID)
);
GO


/* ---------------------------------------------------------
   4. PARTICIPANT_PROFILES
   UserID is both PK and FK.
   --------------------------------------------------------- */
CREATE TABLE dbo.ParticipantProfiles
(
    UserID INT NOT NULL,
    DateOfBirth DATE NOT NULL,
    EmergencyContactName NVARCHAR(100) NULL,
    EmergencyContactPhone NVARCHAR(20) NULL,

    CONSTRAINT PK_ParticipantProfiles
        PRIMARY KEY (UserID),

    CONSTRAINT FK_ParticipantProfiles_Users
        FOREIGN KEY (UserID)
        REFERENCES dbo.Users(UserID)
);
GO


/* ---------------------------------------------------------
   5. EVENTS
   OrganiserID references Users.UserID.
   --------------------------------------------------------- */
CREATE TABLE dbo.Events
(
    EventID INT IDENTITY(1,1) NOT NULL,
    OrganiserID INT NOT NULL,
    EventName NVARCHAR(150) NOT NULL,
    Description NVARCHAR(500) NULL,
    EventDate DATE NOT NULL,
    Location NVARCHAR(150) NOT NULL,
    DistanceKm DECIMAL(6,2) NOT NULL,
    EventType NVARCHAR(30) NOT NULL,
    RegistrationOpen DATE NOT NULL,
    RegistrationClose DATE NOT NULL,
    MaxParticipants INT NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    CreatedAt DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Events
        PRIMARY KEY (EventID),

    CONSTRAINT FK_Events_Users
        FOREIGN KEY (OrganiserID)
        REFERENCES dbo.Users(UserID),

    CONSTRAINT CK_Events_Distance
        CHECK (DistanceKm > 0),

    CONSTRAINT CK_Events_MaxParticipants
        CHECK (MaxParticipants > 0),

    CONSTRAINT CK_Events_Dates
        CHECK (RegistrationClose >= RegistrationOpen),

    CONSTRAINT CK_Events_EventDate
        CHECK (EventDate >= RegistrationOpen)
);
GO


/* ---------------------------------------------------------
   6. CATEGORIES
   One Event can have many Categories.
   --------------------------------------------------------- */
CREATE TABLE dbo.Categories
(
    CategoryID INT IDENTITY(1,1) NOT NULL,
    EventID INT NOT NULL,
    CategoryName NVARCHAR(100) NOT NULL,
    MinAge INT NULL,
    MaxAge INT NULL,
    EntryFee DECIMAL(10,2) NOT NULL
        DEFAULT 0.00,
    StartTime TIME NOT NULL,

    CONSTRAINT PK_Categories
        PRIMARY KEY (CategoryID),

    CONSTRAINT FK_Categories_Events
        FOREIGN KEY (EventID)
        REFERENCES dbo.Events(EventID),

    CONSTRAINT CK_Categories_Ages
        CHECK
        (
            (MinAge IS NULL AND MaxAge IS NULL)
            OR
            (MinAge >= 0 AND MaxAge >= MinAge)
        ),

    CONSTRAINT CK_Categories_EntryFee
        CHECK (EntryFee >= 0),

    CONSTRAINT UQ_Categories_Event_CategoryName
        UNIQUE (EventID, CategoryName)
);
GO


/* ---------------------------------------------------------
   7. ENROLMENTS
   Resolves Participant <-> Event many-to-many relationship.
   ParticipantID references Users.UserID.
   --------------------------------------------------------- */
CREATE TABLE dbo.Enrolments
(
    EnrolmentID INT IDENTITY(1,1) NOT NULL,
    ParticipantID INT NOT NULL,
    EventID INT NOT NULL,
    CategoryID INT NOT NULL,
    EnrolmentDate DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),
    EnrolmentStatus NVARCHAR(20) NOT NULL
        DEFAULT 'Confirmed',
    RaceNumber NVARCHAR(20) NOT NULL,

    CONSTRAINT PK_Enrolments
        PRIMARY KEY (EnrolmentID),

    CONSTRAINT FK_Enrolments_Participant
        FOREIGN KEY (ParticipantID)
        REFERENCES dbo.Users(UserID),

    CONSTRAINT FK_Enrolments_Event
        FOREIGN KEY (EventID)
        REFERENCES dbo.Events(EventID),

    CONSTRAINT FK_Enrolments_Category
        FOREIGN KEY (CategoryID)
        REFERENCES dbo.Categories(CategoryID),

    CONSTRAINT UQ_Enrolments_RaceNumber
        UNIQUE (EventID, RaceNumber)
);
GO


/* ---------------------------------------------------------
   8. RESULTS
   One Enrolment can have zero or one Result.
   --------------------------------------------------------- */
CREATE TABLE dbo.Results
(
    ResultID INT IDENTITY(1,1) NOT NULL,
    EnrolmentID INT NOT NULL,
    FinishTime TIME NOT NULL,
    FinishPosition INT NOT NULL,
    ResultStatus NVARCHAR(20) NOT NULL
        DEFAULT 'Official',
    RecordedAt DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Results
        PRIMARY KEY (ResultID),

    CONSTRAINT UQ_Results_EnrolmentID
        UNIQUE (EnrolmentID),

    CONSTRAINT FK_Results_Enrolments
        FOREIGN KEY (EnrolmentID)
        REFERENCES dbo.Enrolments(EnrolmentID),

    CONSTRAINT CK_Results_FinishPosition
        CHECK (FinishPosition > 0)
);
GO


/* =========================================================
   SAMPLE DATA
   ========================================================= */

/* ---------------------------------------------------------
   9. USERS
   2 Organisers + 2 Participants
   --------------------------------------------------------- */
INSERT INTO dbo.Users
(
    FirstName,
    LastName,
    Email,
    PasswordHash,
    Role,
    Phone
)
VALUES
(
    'Thabo',
    'Mokoena',
    'thabo.mokoena@raceday.co.za',
    'HASH_THABO_001',
    'Organiser',
    '0825551001'
),
(
    'Naledi',
    'Dlamini',
    'naledi.dlamini@raceday.co.za',
    'HASH_NALEDI_002',
    'Organiser',
    '0825551002'
),
(
    'Aiden',
    'Jacobs',
    'aiden.jacobs@example.co.za',
    'HASH_AIDEN_003',
    'Participant',
    '0825551003'
),
(
    'Lerato',
    'Naidoo',
    'lerato.naidoo@example.co.za',
    'HASH_LERATO_004',
    'Participant',
    '0825551004'
);
GO


/* ---------------------------------------------------------
   10. ORGANISER PROFILES
   --------------------------------------------------------- */
INSERT INTO dbo.OrganiserProfiles
(
    UserID,
    OrganisationName,
    OrganisationContactEmail
)
VALUES
(
    1,
    'Ubuntu Road Events',
    'events@ubunturoadevents.co.za'
),
(
    2,
    'Cape Active Sports',
    'info@capeactivesports.co.za'
);
GO


/* ---------------------------------------------------------
   11. PARTICIPANT PROFILES
   --------------------------------------------------------- */
INSERT INTO dbo.ParticipantProfiles
(
    UserID,
    DateOfBirth,
    EmergencyContactName,
    EmergencyContactPhone
)
VALUES
(
    3,
    '2001-05-14',
    'Michael Jacobs',
    '0835552001'
),
(
    4,
    '1999-11-22',
    'Priya Naidoo',
    '0835552002'
);
GO


/* ---------------------------------------------------------
   12. EVENTS
   3 sample events
   --------------------------------------------------------- */
INSERT INTO dbo.Events
(
    OrganiserID,
    EventName,
    Description,
    EventDate,
    Location,
    DistanceKm,
    EventType,
    RegistrationOpen,
    RegistrationClose,
    MaxParticipants,
    Status
)
VALUES
(
    1,
    'Johannesburg Summer Run',
    'Road running event for beginner and experienced runners.',
    '2026-10-18',
    'Johannesburg, Gauteng',
    10.00,
    'Running',
    '2026-08-01',
    '2026-10-10',
    1000,
    'Open'
),
(
    2,
    'Cape Active Cycle Challenge',
    'Road cycling event covering scenic Cape Town routes.',
    '2026-11-08',
    'Cape Town, Western Cape',
    42.00,
    'Cycling',
    '2026-08-15',
    '2026-10-31',
    750,
    'Open'
),
(
    1,
    'Durban Coastal Walk',
    'Community walking event along the Durban coastline.',
    '2026-11-22',
    'Durban, KwaZulu-Natal',
    15.00,
    'Walking',
    '2026-09-01',
    '2026-11-14',
    500,
    'Open'
);
GO


/* ---------------------------------------------------------
   13. CATEGORIES
   --------------------------------------------------------- */
INSERT INTO dbo.Categories
(
    EventID,
    CategoryName,
    MinAge,
    MaxAge,
    EntryFee,
    StartTime
)
VALUES
(
    1,
    '10KM Open',
    18,
    NULL,
    150.00,
    '07:00'
),
(
    1,
    '10KM Junior',
    13,
    17,
    100.00,
    '07:15'
),
(
    2,
    '42KM Cycling Open',
    18,
    NULL,
    350.00,
    '06:30'
),
(
    2,
    '42KM Cycling Veteran',
    40,
    NULL,
    300.00,
    '06:45'
),
(
    3,
    '15KM Open Walk',
    18,
    NULL,
    120.00,
    '08:00'
),
(
    3,
    '15KM Family Walk',
    10,
    NULL,
    80.00,
    '08:15'
);
GO


/* ---------------------------------------------------------
   14. ENROLMENTS
   --------------------------------------------------------- */
INSERT INTO dbo.Enrolments
(
    ParticipantID,
    EventID,
    CategoryID,
    EnrolmentStatus,
    RaceNumber
)
VALUES
(
    3,
    1,
    1,
    'Confirmed',
    'JHB001'
),
(
    4,
    1,
    1,
    'Confirmed',
    'JHB002'
),
(
    3,
    2,
    3,
    'Confirmed',
    'CPT001'
),
(
    4,
    3,
    5,
    'Confirmed',
    'DBN001'
);
GO


/* ---------------------------------------------------------
   15. RESULTS
   Results are recorded for the first two completed enrolments.
   --------------------------------------------------------- */
INSERT INTO dbo.Results
(
    EnrolmentID,
    FinishTime,
    FinishPosition,
    ResultStatus
)
VALUES
(
    1,
    '00:52:18',
    14,
    'Official'
),
(
    2,
    '00:58:42',
    27,
    'Official'
);
GO


/* =========================================================
   VERIFICATION QUERIES
   ========================================================= */

/* Users */
SELECT *
FROM dbo.Users;
GO

/* Organiser Profiles */
SELECT *
FROM dbo.OrganiserProfiles;
GO

/* Participant Profiles */
SELECT *
FROM dbo.ParticipantProfiles;
GO

/* Events */
SELECT *
FROM dbo.Events;
GO

/* Categories */
SELECT *
FROM dbo.Categories;
GO

/* Enrolments */
SELECT *
FROM dbo.Enrolments;
GO

/* Results */
SELECT *
FROM dbo.Results;
GO


/* ---------------------------------------------------------
   FINAL RELATIONSHIP VERIFICATION
   --------------------------------------------------------- */
SELECT
    e.EventName,
    c.CategoryName,
    u.FirstName + ' ' + u.LastName AS Participant,
    en.RaceNumber,
    en.EnrolmentStatus,
    r.FinishTime,
    r.FinishPosition,
    r.ResultStatus
FROM dbo.Enrolments AS en
INNER JOIN dbo.Users AS u
    ON en.ParticipantID = u.UserID
INNER JOIN dbo.Events AS e
    ON en.EventID = e.EventID
INNER JOIN dbo.Categories AS c
    ON en.CategoryID = c.CategoryID
LEFT JOIN dbo.Results AS r
    ON en.EnrolmentID = r.EnrolmentID
ORDER BY
    e.EventName,
    r.FinishPosition;
GO