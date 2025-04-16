DROP TABLE Poplatek CASCADE CONSTRAINTS;
DROP TABLE Vypujceni CASCADE CONSTRAINTS;
DROP TABLE Rezervace CASCADE CONSTRAINTS;
DROP TABLE Kniha_casopis CASCADE CONSTRAINTS;
DROP TABLE Je_autorem CASCADE CONSTRAINTS;
DROP TABLE Autor CASCADE CONSTRAINTS;
DROP TABLE Publikace CASCADE CONSTRAINTS;
DROP TABLE Nakladatelstvi CASCADE CONSTRAINTS;
DROP TABLE Uzivatel CASCADE CONSTRAINTS;

DROP SEQUENCE UzivatelSeq;
DROP SEQUENCE NakladatelstviSeq;
DROP SEQUENCE PublikaceSeq;
DROP SEQUENCE AutorSeq;
DROP SEQUENCE PoplatekSeq;

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

set serveroutput on size 20000;


-- ============================================================
-- ===                      SEQUENCES                       ===
-- ============================================================

CREATE SEQUENCE UzivatelSeq;
CREATE SEQUENCE NakladatelstviSeq;
CREATE SEQUENCE PublikaceSeq;
CREATE SEQUENCE AutorSeq;
CREATE SEQUENCE PoplatekSeq;


-- ============================================================
-- ===                       TABLES                         ===
-- ============================================================

CREATE TABLE Uzivatel ( 
    ID_uzivatel INTEGER DEFAULT UzivatelSeq.nextval, 
    jmeno VARCHAR(30) NOT NULL, 
    prijmeni VARCHAR(30) NOT NULL, 
    telefonni_cislo INTEGER, 
    ulice VARCHAR(30), 
    cislo_popisne INTEGER, 
    mesto VARCHAR(30), 
    email VARCHAR(40) NOT NULL,
    CHECK (email LIKE '%@%'),
    typ VARCHAR(20) NOT NULL, 
    CHECK (typ = 'zamestnanec' OR typ = 'ctenar'), 
    datum_konce_clenstvi DATE,
    pozice VARCHAR(30), 
    CONSTRAINT PK_uzivatel PRIMARY KEY (ID_uzivatel),
    CONSTRAINT check_typ_datum_konce_clenstvi CHECK (typ != 'ctenar' OR (typ = 'ctenar' AND datum_konce_clenstvi IS NOT NULL))
);


CREATE TABLE Nakladatelstvi ( 
    ID_nakladatelstvi INTEGER DEFAULT NakladatelstviSeq.nextval,
    nazev VARCHAR(30) NOT NULL, 
    ulice VARCHAR(30), 
    cislo_popisne INTEGER, 
    mesto VARCHAR(30), 
    CONSTRAINT PK_nakladatelstvi PRIMARY KEY (ID_nakladatelstvi) 
);


CREATE TABLE Publikace ( 
    ID_publikace INTEGER DEFAULT PublikaceSeq.nextval,
    nazev VARCHAR(50) NOT NULL, 
    jazyk VARCHAR(30), 
    datum_vydani DATE, 
    ID_nakladatelstvi INTEGER NOT NULL, 
    CONSTRAINT PK_publikace PRIMARY KEY (ID_publikace), 
    CONSTRAINT FK_publikace_nakladatelstvi FOREIGN KEY (ID_nakladatelstvi) REFERENCES Nakladatelstvi (ID_nakladatelstvi)
);


CREATE TABLE Autor ( 
    ID_autor INTEGER DEFAULT AutorSeq.nextval,
    jmeno VARCHAR(30), 
    prijmeni VARCHAR(30), 
    CONSTRAINT PK_autor PRIMARY KEY (ID_autor) 
);

CREATE TABLE Je_autorem ( 
    ID_autor INTEGER NOT NULL, 
    ID_publikace INTEGER NOT NULL, 
    CONSTRAINT PK_je_autorem PRIMARY KEY (ID_autor, ID_publikace), 
    CONSTRAINT FK_je_autorem_autor FOREIGN KEY (ID_autor) REFERENCES Autor (ID_autor), 
    CONSTRAINT FK_je_autorem_publikace FOREIGN KEY (ID_publikace) REFERENCES Publikace (ID_publikace)
);


CREATE TABLE Kniha_casopis ( 
    ID_publikace INTEGER NOT NULL, 
    typ VARCHAR(10) NOT NULL, 
    CHECK (typ = 'kniha' OR typ = 'casopis'), 
    ISBN VARCHAR(13), 
    kategorie VARCHAR(20), 
    ISSN VARCHAR(8), 
    CHECK (LENGTH(ISBN) = 13 OR LENGTH(ISBN) = 10), 
    CHECK (LENGTH(ISSN) = 8), 
    CONSTRAINT PK_kniha_casopis PRIMARY KEY (ID_publikace), 
    CONSTRAINT FK_kniha_casopis_publikace FOREIGN KEY (ID_publikace) REFERENCES Publikace (ID_publikace),
    CONSTRAINT check_if_book_isbn CHECK (typ != 'kniha' OR (typ = 'kniha' AND ISBN IS NOT NULL)),
    CONSTRAINT check_if_casopis_issn CHECK (typ != 'casopis' OR (typ = 'casopis' AND ISSN IS NOT NULL))
);

CREATE TABLE Rezervace ( 
    ID_uzivatel INTEGER NOT NULL, 
    ID_publikace INTEGER NOT NULL, 
    datum_zadani_rezervace DATE DEFAULT SYSDATE, 
    poradi_rezervace INTEGER NOT NULL, 
    CONSTRAINT PK_rezervace PRIMARY KEY (ID_uzivatel, ID_publikace, datum_zadani_rezervace), 
    CONSTRAINT FK_rezervace_uzivatel FOREIGN KEY (ID_uzivatel) REFERENCES Uzivatel (ID_uzivatel), 
    CONSTRAINT FK_rezervace_publikace FOREIGN KEY (ID_publikace) REFERENCES Publikace (ID_publikace)
);

CREATE TABLE Vypujceni ( 
    ID_uzivatel INTEGER NOT NULL, 
    ID_publikace INTEGER NOT NULL, 
    datum_vypujceni DATE DEFAULT SYSDATE, 
    datum_vraceni DATE, 
    CONSTRAINT PK_vypujceni PRIMARY KEY (ID_uzivatel, ID_publikace, datum_vypujceni), 
    CONSTRAINT FK_vypujceni_uzivatel FOREIGN KEY (ID_uzivatel) REFERENCES Uzivatel (ID_uzivatel), 
    CONSTRAINT FK_vypujceni_publikace FOREIGN KEY (ID_publikace) REFERENCES Publikace (ID_publikace) 
);


CREATE TABLE Poplatek ( 
    ID_poplatek INTEGER DEFAULT PoplatekSeq.nextval, 
    prestupek VARCHAR(30) NOT NULL, 
    castka INTEGER NOT NULL, 
    CHECK (castka >= 0), 
    datum_udeleni DATE DEFAULT SYSDATE, 
    datum_zaplaceni DATE, 
    ID_uzivatel INTEGER NOT NULL, 
    CONSTRAINT PK_poplatek PRIMARY KEY (ID_poplatek), 
    CONSTRAINT FK_poplatek_uzivatel FOREIGN KEY (ID_uzivatel) REFERENCES Uzivatel (ID_uzivatel)
);

-- ============================================================
-- ===                       INDEX                          ===
-- ============================================================

CREATE INDEX idx_je_autorem_id_autor ON Je_autorem(ID_autor);

-- ============================================================
-- ===                      TRIGGERS                        ===
-- ============================================================

-- vlozeni rezervace - poradi
CREATE OR REPLACE TRIGGER vlozeni_poradi_rezervace
BEFORE INSERT ON Rezervace
FOR EACH ROW
DECLARE
    pocet_rezervaci INTEGER; -- pocet rezervaci pro danou knihu
BEGIN
    SELECT NVL(COUNT(*), 0) INTO pocet_rezervaci
    FROM Rezervace
    WHERE ID_publikace = :NEW.ID_publikace;

    :NEW.poradi_rezervace := pocet_rezervaci + 1;
END;
/

-- automaticky udel poplatek za pozdni vraceni pri insertu vraceni
CREATE OR REPLACE TRIGGER vraceni_knihy
AFTER UPDATE OF datum_vraceni ON Vypujceni
FOR EACH ROW
BEGIN
   IF :NEW.datum_vraceni > :OLD.datum_vypujceni + 31 THEN
        INSERT INTO Poplatek (prestupek, castka, ID_uzivatel, datum_udeleni)
            VALUES('pozdni vraceni', 100, :NEW.ID_uzivatel, :NEW.datum_vraceni);
    END IF;
END;
/

-- ============================================================
-- ===                     PROCEDURES                       ===
-- ============================================================

-- ========= dekrementace poradi rezervace pri smazani rezervace =========
CREATE OR REPLACE PROCEDURE dekrementace_rezervaci(
    ID_pub IN Rezervace.ID_publikace%TYPE)
IS
    -- vyvoreni kurzoru pro ziskani vsech rezervaci se stejnym ID publikace
    CURSOR stejna_publikace IS
        SELECT poradi_rezervace FROM Rezervace
            WHERE ID_publikace = ID_pub; 
BEGIN 
    -- loop pres kurzor a snizeni vsech rezervaci o 1
    FOR element IN stejna_publikace
    LOOP
        UPDATE Rezervace
            SET poradi_rezervace = element.poradi_rezervace - 1
            WHERE ID_publikace = ID_pub
                AND poradi_rezervace = element.poradi_rezervace;
    END LOOP;
END;
/

-- ========= assert ze lze publikaci vypujcit (neexistuje rezervace anebo je uzivatel 1. v poradi rezervaci) =========
CREATE OR REPLACE PROCEDURE assert_lze_vypujcit(
    ID_pub IN Rezervace.ID_publikace%TYPE,
    ID_uz IN Rezervace.ID_uzivatel%TYPE)
IS
    unableToBorrowException EXCEPTION;
    pocet_rezervaci INTEGER;
    poradi INTEGER;
BEGIN
    SELECT COUNT(ID_publikace)
        INTO pocet_rezervaci
        FROM Rezervace
        WHERE ID_publikace = ID_pub;
    
    IF (pocet_rezervaci > 0) THEN
        SELECT poradi_rezervace
        INTO poradi
        FROM Rezervace
        WHERE ID_publikace = ID_pub 
            AND ID_uzivatel = ID_uz;
    END IF;
    
    IF (pocet_rezervaci > 0) THEN
        IF (poradi != 1) THEN
            RAISE unableToBorrowException;
        END IF;
    END IF;

EXCEPTION
    WHEN unableToBorrowException THEN
        DBMS_OUTPUT.ENABLE;
        DBMS_OUTPUT.put_line('Exception: nelze vypujcit, publikace je zarezervovana.');
END;
/


-- ============================================================
-- ===                       SEEDING                        ===
-- ============================================================

-- knihovnici
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, pozice)
VALUES('Adam','Helesic',724005067,'Bozetechova',656,'Brno','xheles06@vutbr.cz','zamestnanec','knihovnik');
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, pozice)
VALUES('Tomas','Masaryk',7557667889,'Masarykova',4,'Brno','tgm@centrum.cz','zamestnanec','knihovnik');
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, pozice)
VALUES('Ludmila','Kratochvilova',733086987,'Nova',666,'Modrice','ludmilka123@seznam.cz','zamestnanec','knihovnik');

-- ctenari
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, datum_konce_clenstvi)
VALUES('Roman','Tresek',724023671,'Sokolska',126,'Brno','xtrese00@vutbr.cz','ctenar',TO_DATE('23.3.2024', 'dd.mm.yyyy'));
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, datum_konce_clenstvi)
VALUES('Premysl','Otakar',721787255,'Hradska',32,'Brno','potakar@gmail.com','ctenar',TO_DATE('17.5.2024', 'dd.mm.yyyy'));
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, datum_konce_clenstvi)
VALUES('Vaclav','Marek',785978942,'Revolucni',15,'Breclav','vaclab@gmail.com','ctenar',TO_DATE('20.5.2024', 'dd.mm.yyyy'));
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, datum_konce_clenstvi)
VALUES('Petr','Rychly',777211015,'Ruzova',43,'Brno','doktorrychly@seznam.cz','ctenar',TO_DATE('15.6.2024', 'dd.mm.yyyy'));
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, datum_konce_clenstvi)
VALUES('Stanislava','Jachnicka',725366148,'Hlasicka',63,'Modrice','jachna@gmail.com','ctenar',TO_DATE('8.6.2024', 'dd.mm.yyyy'));
INSERT INTO Uzivatel (jmeno, prijmeni, telefonni_cislo, ulice, cislo_popisne, mesto, email, typ, datum_konce_clenstvi)
VALUES('Zlata','Adamovska',725366148,'Ruzova',63,'Brno','zlata.adamovska@gmail.com','ctenar',TO_DATE('13.1.2024', 'dd.mm.yyyy'));

-- nakladatelstvi
INSERT INTO Nakladatelstvi (nazev, ulice, cislo_popisne, mesto)
VALUES('Albatros','Revolucni',786,'Brno');
INSERT INTO Nakladatelstvi (nazev, ulice, cislo_popisne, mesto)
VALUES('Red','Masarykova',8762,'Brno');
INSERT INTO Nakladatelstvi (nazev, ulice, cislo_popisne, mesto)
VALUES('Lenka Pilchova - LEONARDO','Rychvaldska',640,'Petrvald u Karvine');
INSERT INTO Nakladatelstvi (nazev, ulice, cislo_popisne, mesto)
VALUES('Ringier Axel Springer','Komunardu',42,'Praha');
INSERT INTO Nakladatelstvi (nazev, ulice, cislo_popisne, mesto)
VALUES('Mlada fronta','Mezi vodami',9,'Praha');
INSERT INTO Nakladatelstvi (nazev, ulice, cislo_popisne, mesto)
VALUES('BETA s.r.o.','Kvetnoveho vitezstvi',31,'Praha');

-- knihy
INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('Harry Potter a princ dvoji krve','cestina',TO_DATE('2005', 'yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'Albatros'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISBN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'Harry Potter a princ dvoji krve'),'kniha','8000018195','fantasy');

INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('Harry Potter a Fenixuv rad','cestina',TO_DATE('2004', 'yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'Albatros'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISBN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'Harry Potter a Fenixuv rad'),'kniha','8000012944','fantasy');

INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('Zaklinac 1: Posledni prani','cestina',TO_DATE('2011', 'yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'Lenka Pilchova - LEONARDO'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISBN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 1: Posledni prani'), 'kniha','9788085951653','fantasy');

INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('Zaklinac 2: Mec osudu','cestina',TO_DATE('2011', 'yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'Lenka Pilchova - LEONARDO'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISBN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 2: Mec osudu'), 'kniha','9788085951660','fantasy');

INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('Maly princ','cestina',TO_DATE('2004', 'yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'Red'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISBN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ'), 'kniha','9788073902389','pohadka');

INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('Epos o Gilgamesovi','cestina',TO_DATE('1958', 'yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'Mlada fronta'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISBN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'Epos o Gilgamesovi'), 'kniha','2300121771','epicka poezie');

INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('Zhoubny kmen: Nakaza','cestina',TO_DATE('2010', 'yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'BETA s.r.o.'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISBN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'Zhoubny kmen: Nakaza'), 'kniha','9788073064099','sci-fi');

-- casopisy 
INSERT INTO Publikace (nazev, jazyk, datum_vydani, ID_nakladatelstvi)
VALUES('abc','cestina',TO_DATE('9.4.2013', 'dd.mm.yyyy'), (SELECT ID_nakladatelstvi FROM Nakladatelstvi WHERE nazev = 'Ringier Axel Springer'));
INSERT INTO Kniha_casopis (ID_publikace, typ, ISSN, kategorie)
VALUES((SELECT ID_publikace FROM Publikace WHERE nazev = 'abc'), 'casopis','03229580','pro deti');

-- autori
INSERT INTO Autor (jmeno, prijmeni)
VALUES('Joanne', 'Rowling');
INSERT INTO Autor (jmeno, prijmeni)
VALUES('Antoine', 'de Saint-Exupery');
INSERT INTO Autor (jmeno, prijmeni)
VALUES('Andrzej', 'Sapkowski');
INSERT INTO Autor (jmeno, prijmeni)
VALUES('Guillermo', 'del Toro');
INSERT INTO Autor (jmeno, prijmeni)
VALUES('Chuck', 'Hogan');

-- je autorem
INSERT INTO Je_autorem (ID_autor, ID_publikace)
VALUES((SELECT ID_autor FROM Autor WHERE jmeno = 'Joanne' AND prijmeni = 'Rowling'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Harry Potter a princ dvoji krve'));
INSERT INTO Je_autorem (ID_autor, ID_publikace)
VALUES((SELECT ID_autor FROM Autor WHERE jmeno = 'Joanne' AND prijmeni = 'Rowling'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Harry Potter a Fenixuv rad'));
INSERT INTO Je_autorem (ID_autor, ID_publikace)
VALUES((SELECT ID_autor FROM Autor WHERE jmeno = 'Antoine' AND prijmeni = 'de Saint-Exupery'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ'));
INSERT INTO Je_autorem (ID_autor, ID_publikace)
VALUES((SELECT ID_autor FROM Autor WHERE jmeno = 'Andrzej' AND prijmeni = 'Sapkowski'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 1: Posledni prani'));
INSERT INTO Je_autorem (ID_autor, ID_publikace)
VALUES((SELECT ID_autor FROM Autor WHERE jmeno = 'Andrzej' AND prijmeni = 'Sapkowski'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 2: Mec osudu'));
INSERT INTO Je_autorem (ID_autor, ID_publikace)
VALUES((SELECT ID_autor FROM Autor WHERE jmeno = 'Guillermo' AND prijmeni = 'del Toro'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zhoubny kmen: Nakaza'));
INSERT INTO Je_autorem (ID_autor, ID_publikace)
VALUES((SELECT ID_autor FROM Autor WHERE jmeno = 'Chuck' AND prijmeni = 'Hogan'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zhoubny kmen: Nakaza'));

-- rezervace
INSERT INTO Rezervace (ID_uzivatel, ID_publikace, datum_zadani_rezervace)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Stanislava' AND prijmeni = 'Jachnicka'), 
       (SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ'), TO_DATE('25.3.2024', 'dd.mm.yyyy'));
INSERT INTO Rezervace (ID_uzivatel, ID_publikace, datum_zadani_rezervace)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Stanislava' AND prijmeni = 'Jachnicka'), 
       (SELECT ID_publikace FROM Publikace WHERE nazev = 'Epos o Gilgamesovi'), TO_DATE('26.3.2024', 'dd.mm.yyyy'));
INSERT INTO Rezervace (ID_uzivatel, ID_publikace, datum_zadani_rezervace)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Vaclav' AND prijmeni = 'Marek'), 
       (SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ'), TO_DATE('29.3.2024', 'dd.mm.yyyy'));

-- vypujceni
INSERT INTO Vypujceni (ID_uzivatel, ID_publikace, datum_vypujceni)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Vaclav' AND prijmeni = 'Marek'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Harry Potter a princ dvoji krve'),TO_DATE('1.1.2024', 'dd.mm.yyyy'));
INSERT INTO Vypujceni (ID_uzivatel, ID_publikace, datum_vypujceni)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Zlata' AND prijmeni = 'Adamovska'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ'),TO_DATE('17.3.2024', 'dd.mm.yyyy'));
INSERT INTO Vypujceni (ID_uzivatel, ID_publikace, datum_vypujceni)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Zlata' AND prijmeni = 'Adamovska'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Harry Potter a Fenixuv rad'),TO_DATE('2.4.2024', 'dd.mm.yyyy'));
INSERT INTO Vypujceni (ID_uzivatel, ID_publikace, datum_vypujceni)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Adam' AND prijmeni = 'Helesic'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'abc'),TO_DATE('24.4.2024', 'dd.mm.yyyy'));

-- vraceni
UPDATE Vypujceni
    SET datum_vraceni = TO_DATE('17.2.2024', 'dd.mm.yyyy')
    WHERE ID_uzivatel = (SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Vaclav' AND prijmeni = 'Marek')
        AND ID_publikace = (SELECT ID_publikace FROM Publikace WHERE nazev = 'Harry Potter a princ dvoji krve')
        AND datum_vypujceni = TO_DATE('1.1.2024', 'dd.mm.yyyy');
UPDATE Vypujceni
    SET datum_vraceni = TO_DATE('2.4.2024', 'dd.mm.yyyy')
    WHERE ID_uzivatel = (SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Zlata' AND prijmeni = 'Adamovska')
        AND ID_publikace = (SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ')
        AND datum_vypujceni = TO_DATE('17.3.2024', 'dd.mm.yyyy');

-- poplatek
-- (poplatky za pozdni vraceni resena pres trigger)
INSERT INTO Poplatek (prestupek, castka, ID_uzivatel, datum_udeleni)
VALUES('poniceni knihy',150, (SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Premysl' AND prijmeni = 'Otakar'), TO_DATE('1.4.2024', 'dd.mm.yyyy'));
INSERT INTO Poplatek (prestupek, castka, ID_uzivatel, datum_udeleni)
VALUES('poniceni knihy',150, (SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Vaclav' AND prijmeni = 'Marek'), TO_DATE('1.4.2024', 'dd.mm.yyyy'));

-- zaplaceni poplatku
UPDATE Poplatek
    SET datum_zaplaceni = TO_DATE('17.2.2024', 'dd.mm.yyyy')
    WHERE ID_poplatek = (SELECT ID_poplatek FROM Poplatek
        WHERE ID_uzivatel = (SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Vaclav' AND prijmeni = 'Marek')
        AND datum_udeleni = TO_DATE('17.2.2024', 'dd.mm.yyyy'));
UPDATE Poplatek
    SET datum_zaplaceni = TO_DATE('15.4.2024', 'dd.mm.yyyy')
    WHERE ID_poplatek = (SELECT ID_poplatek FROM Poplatek
        WHERE ID_uzivatel = (SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Vaclav' AND prijmeni = 'Marek')
        AND datum_udeleni = TO_DATE('1.4.2024', 'dd.mm.yyyy'));


-- ============================================================
-- ===                      QUERIES                         ===
-- ============================================================

-- SHOW ALL TABLES
-- SELECT * FROM Uzivatel;
-- SELECT * FROM Nakladatelstvi;
-- SELECT * FROM Publikace;
-- SELECT * FROM Autor;
-- SELECT * FROM Je_autorem;
-- SELECT * FROM Kniha_casopis;
-- SELECT * FROM Rezervace;
-- SELECT * FROM Vypujceni;
-- SELECT * FROM Poplatek;

-- cast 3: SELECTs
-- zobrazeni vsech knih a casopisu s jejich autory a nakladatelstvimi
SELECT P.nazev AS Nazev, P.jazyk, KC.typ, KC.kategorie, A.prijmeni, A.jmeno, N.nazev AS nazev_nakladatelstvi
    FROM Publikace P
    LEFT JOIN Kniha_casopis KC ON (P.ID_publikace = KC.ID_publikace)
	LEFT JOIN Nakladatelstvi N ON (N.ID_nakladatelstvi = P.ID_nakladatelstvi)
    LEFT JOIN Je_autorem JA ON (JA.ID_publikace = P.ID_publikace)
    LEFT JOIN Autor A ON (A.ID_autor = JA.ID_autor)
    ORDER BY LOWER(P.nazev) ASC;


----------------------- jeden vyuzivajici spojeni tri tabulek
-- zobrazeni nazvu vsech knih od Joanne Rowling
SELECT P.nazev, A.prijmeni, A.jmeno
    FROM Publikace P
    JOIN Je_autorem JA ON (JA.ID_publikace = P.ID_publikace)
    JOIN Autor A ON (A.ID_autor = JA.ID_autor)
    WHERE 'Joanne' = A.jmeno AND 'Rowling' = A.prijmeni;


----------------------- jeden dotaz s predikatem IN s vnorenym selectem
-- ctenari, kterym byl udelen poplatek
SELECT U.prijmeni, U.jmeno
    FROM Uzivatel U
    WHERE U.ID_uzivatel IN
        (
            SELECT ID_uzivatel
                FROM Poplatek
        );


----------------------- jeden dotaz obsahujici predikat EXISTS
-- ma nekdo nezaplaceny poplatek?
SELECT U.prijmeni, U.jmeno
    FROM Uzivatel U
    WHERE EXISTS
        (
            SELECT ID_uzivatel 
            FROM Poplatek P
            WHERE U.ID_uzivatel = P.ID_uzivatel
                AND datum_zaplaceni IS NULL
        );


----------------------- dva dotazy s klauzuli GROUP BY a agregacni funkci
-- seznam autoru dle poctu knih
SELECT A.prijmeni, A.jmeno, COUNT(JA.ID_autor) AS pocet_knih
    FROM Je_autorem JA
    JOIN Autor A ON (JA.ID_autor = A.ID_autor)
    GROUP BY A.prijmeni, A.jmeno
    ORDER BY LOWER(A.prijmeni), LOWER(A.jmeno);


-- pocet vypujcek kazdeho ctenare
SELECT U.prijmeni, U.jmeno, COUNT(V.ID_uzivatel) AS pocet_vypujcek
    FROM Uzivatel U
    LEFT JOIN Vypujceni V ON (V.ID_uzivatel = U.ID_uzivatel)
    GROUP BY U.prijmeni, U.jmeno
    ORDER BY LOWER(U.prijmeni), LOWER(U.jmeno);


----------------------- dva dotazy vyuzivajici spojeni dvou tabulek
-- zobrazit vsechny uzivatele i s potencialnimi poplatky
SELECT U.prijmeni, U.jmeno, U.telefonni_cislo, U.email, P.prestupek, P.castka, P.datum_udeleni, P.datum_zaplaceni
    FROM Uzivatel U
    LEFT JOIN Poplatek P ON (U.ID_uzivatel = P.ID_uzivatel)
    ORDER BY LOWER(U.prijmeni), LOWER(U.jmeno), P.datum_udeleni DESC;


-- seznam uzivatelu, kteri si vypujcili knihy v lednu 2024
SELECT U.prijmeni, U.jmeno, V.datum_vypujceni
    FROM Vypujceni V
    NATURAL JOIN Uzivatel U
    WHERE V.datum_vypujceni BETWEEN TO_DATE('1.1.2024', 'dd.mm.yyyy') AND TO_DATE('31.1.2024', 'dd.mm.yyyy')
    ORDER BY LOWER(U.prijmeni), LOWER(U.jmeno);


----------------------- other?
-- ctenari s aktivnim clenstvim
SELECT jmeno, prijmeni, datum_konce_clenstvi
    FROM Uzivatel
    WHERE datum_konce_clenstvi >= SYSDATE;

-- kdo ma kolik vypujcek a poplatku
SELECT U.prijmeni, U.jmeno, COUNT(V.ID_uzivatel) AS pocet_vypujcek, COUNT(P.ID_poplatek) AS pocet_poplatku
    FROM Uzivatel U
    LEFT JOIN Vypujceni V ON (V.ID_uzivatel = U.ID_uzivatel)
    LEFT JOIN Poplatek P ON (P.ID_uzivatel = U.ID_uzivatel)
    GROUP BY U.prijmeni, U.jmeno
    ORDER BY LOWER(U.prijmeni), LOWER(U.jmeno);


------------------------------------- cast 4
-- dotaz ziskava data z tabulky uzivatelu (ID uzivatele) a s pomoci tabulky Vypujceni pocita kolik si kdo vypujcil publikaci
WITH detaily_vypujceni AS (
    SELECT v.ID_uzivatel, COUNT(*) AS pocet_pujcenych_publikaci
    FROM Vypujceni v
    JOIN Kniha_casopis kc ON v.ID_publikace = kc.ID_publikace
    GROUP BY v.ID_uzivatel
)
SELECT u.ID_uzivatel, u.jmeno, u.prijmeni,
    CASE
        WHEN dv.pocet_pujcenych_publikaci IS NULL THEN 0
        ELSE dv.pocet_pujcenych_publikaci
    END
    AS pocet_pujcenych_publikaci
FROM Uzivatel u
LEFT JOIN detaily_vypujceni dv ON u.ID_uzivatel = dv.ID_uzivatel
ORDER BY u.ID_uzivatel;


-- ============================================================
-- ===                    TRIGGER TESTS                     ===
-- ============================================================

-- ========= rezervace (maly princ byl jiz zarezervovan 2krat) =========
-- zobrazeni puvodni
SELECT * FROM Rezervace;

-- zmena
INSERT INTO Rezervace (ID_uzivatel, ID_publikace, datum_zadani_rezervace)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Premysl' AND prijmeni = 'Otakar'), 
       (SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ'), TO_DATE('30.3.2024', 'dd.mm.yyyy'));

-- zobrazeni zmenene
SELECT * FROM Rezervace;


-- ========= vypujceni =========
-- zobrazeni puvodni
SELECT U.prijmeni, U.jmeno, U.telefonni_cislo, U.email, P.prestupek, P.castka, P.datum_udeleni, P.datum_zaplaceni
    FROM Uzivatel U
    LEFT JOIN Poplatek P ON (U.ID_uzivatel = P.ID_uzivatel)
    ORDER BY LOWER(U.prijmeni), LOWER(U.jmeno), P.datum_udeleni DESC;

-- zmena
INSERT INTO Vypujceni (ID_uzivatel, ID_publikace, datum_vypujceni)
VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Premysl' AND prijmeni = 'Otakar'), (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 1: Posledni prani'),TO_DATE('5.1.2024', 'dd.mm.yyyy'));

UPDATE Vypujceni
    SET datum_vraceni = TO_DATE('8.2.2024', 'dd.mm.yyyy')
    WHERE ID_uzivatel = (SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Premysl' AND prijmeni = 'Otakar')
        AND ID_publikace = (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 1: Posledni prani')
        AND datum_vypujceni = TO_DATE('5.1.2024', 'dd.mm.yyyy');

-- zobrazeni zmenene
SELECT U.prijmeni, U.jmeno, U.telefonni_cislo, U.email, P.prestupek, P.castka, P.datum_udeleni, P.datum_zaplaceni
    FROM Uzivatel U
    LEFT JOIN Poplatek P ON (U.ID_uzivatel = P.ID_uzivatel)
    ORDER BY LOWER(U.prijmeni), LOWER(U.jmeno), P.datum_udeleni DESC;


-- ============================================================
-- ===                   PROCEDURE TESTS                    ===
-- ============================================================

-- ========= dekrementace poradi rezervaci =========
-- zobrazeni puvodni
SELECT * FROM Rezervace;

-- zmena
DELETE FROM Rezervace
    WHERE ID_publikace = (SELECT ID_publikace FROM Publikace WHERE nazev = 'Maly princ')
        AND poradi_rezervace = 1;

-- volani dekrementacni procedury
DECLARE
    ID_pub Publikace.ID_publikace%TYPE;
BEGIN
    SELECT ID_publikace
        INTO ID_pub
        FROM Publikace
        WHERE nazev = 'Maly princ';
    
    dekrementace_rezervaci(ID_pub);
END;
/

-- zobrazeni zmenene
SELECT * FROM Rezervace;


-- ========= rezervovane knihy nelze vypujcit =========
-- zobrazeni puvodni
SELECT * FROM Rezervace;

-- vypujceni
DECLARE
    ID_pub Publikace.ID_publikace%TYPE;
    ID_uz Uzivatel.ID_uzivatel%TYPE;
BEGIN
    -- case: rezervace neexistuje
    SELECT ID_publikace
        INTO ID_pub
        FROM Publikace
        WHERE nazev = 'Zaklinac 2: Mec osudu';

    SELECT ID_uzivatel
        INTO ID_uz
        FROM Uzivatel
        WHERE jmeno = 'Adam' AND prijmeni = 'Helesic';
    
    assert_lze_vypujcit(ID_pub, ID_uz);


    -- case: rezervace existuje, ale uzivatel je prvni v poradi
    INSERT INTO Rezervace (ID_uzivatel, ID_publikace, datum_zadani_rezervace)
    VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Adam' AND prijmeni = 'Helesic'), 
       (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 2: Mec osudu'), TO_DATE('28.4.2024', 'dd.mm.yyyy'));

    assert_lze_vypujcit(ID_pub, ID_uz);


    -- case: rezervace existuje a uzivatel neni prvni v poradi
    INSERT INTO Rezervace (ID_uzivatel, ID_publikace, datum_zadani_rezervace)
    VALUES((SELECT ID_uzivatel FROM Uzivatel WHERE jmeno = 'Roman' AND prijmeni = 'Tresek'), 
       (SELECT ID_publikace FROM Publikace WHERE nazev = 'Zaklinac 2: Mec osudu'), TO_DATE('28.4.2024', 'dd.mm.yyyy'));

    SELECT ID_uzivatel
        INTO ID_uz
        FROM Uzivatel
        WHERE jmeno = 'Roman' AND prijmeni = 'Tresek';

    assert_lze_vypujcit(ID_pub, ID_uz);
END;
/

-- zobrazeni zmenene
SELECT * FROM Rezervace;


-- ============================================================
-- ===                    EXPLAIN PLAN                      ===
-- ============================================================

EXPLAIN PLAN FOR
SELECT A.prijmeni, A.jmeno, COUNT(JA.ID_autor) AS pocet_knih
    FROM Je_autorem JA
    JOIN Autor A ON (JA.ID_autor = A.ID_autor)
    GROUP BY A.prijmeni, A.jmeno
    ORDER BY LOWER(A.prijmeni), LOWER(A.jmeno);

SELECT plan_table_output  
FROM TABLE(DBMS_XPLAN.DISPLAY('plan_table',null,'typical'));


-- ============================================================
-- ===                     PERMISSIONS                      ===
-- ============================================================

GRANT ALL ON Poplatek TO xtrese00;


-- ============================================================
-- ===                         VIEW                         ===
-- ============================================================

-- zadani: "vytvoření alespoň jednoho materializovaného pohledu patřící druhému členu týmu a používající tabulky definované prvním členem týmu"
-- => granted privilegia pro tabulku Poplatek uzivateli xtrese00
-- xtrese00 u sebe pak muze vytvorit Materialized View:

-- CREATE MATERIALIZED VIEW MV_TotalCastka
-- AS
-- SELECT SUM(castka) AS Total_Castka
--     FROM xheles06.Poplatek;
