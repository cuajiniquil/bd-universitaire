CREATE DATABASE SGBD_PROJET;
USE SGBD_PROJET;

-- ------------------- --
-- 1.1: TABLES ENTITES --
-- ------------------- --

CREATE TABLE ETUDIANT(
Num_Etud INT PRIMARY KEY,
Nom_Et VARCHAR(50)  NOT NULL, 
Prenom_Et VARCHAR(50)  NOT NULL, 
Date_Naiss DATE NOT NULL,
Telephone_Et INT,
Email_Et VARCHAR(50) NOT NULL UNIQUE,
Adresse_Et VARCHAR(100) NOT NULL
);

CREATE TABLE COURS(
Code_Cours VARCHAR(50) PRIMARY KEY,
Nom_C VARCHAR(50) NOT NULL,
ECTS INT,
Heures FLOAT
);

CREATE TABLE EXAMEN(
ID_Exam VARCHAR(50) PRIMARY KEY,
Code_C VARCHAR(50) REFERENCES Cours(Code_Cours),
Salle VARCHAR(50) NOT NULL,
Coeff INT,
Date_Ex DATETIME,
Duree INT NOT NULL
);

CREATE TABLE ENSEIGNANT(
ID_Ens INT PRIMARY KEY,
Nom_En VARCHAR(50)  NOT NULL, 
Prenom_En VARCHAR(50)  NOT NULL, 
-- Grade VARCHAR(50) NOT NULL, --
Telephone_En INT,
Email_En VARCHAR(50) NOT NULL UNIQUE
);

-- ------------------------ --
-- 1.2: TABLES ASSOCIATIVES --
-- ------------------------ --

CREATE TABLE INSCRIPTION(
ID_Ins SERIAL PRIMARY KEY,
Num_Et INT REFERENCES ETUDIANT(Num_Etud),
Code_C VARCHAR(50) REFERENCES COURS(Code_Cours),
Status_Ins VARCHAR(20) NOT NULL CHECK(Status_Ins IN ('EnCours', 'Suppr', 'Annul', 'Val')),
Date_Ins DATETIME,
Raison_Annul VARCHAR(100)
);

CREATE TABLE NOTE(
ID_Note SERIAL PRIMARY KEY,
Num_Et INT REFERENCES ETUDIANT(Num_Etud), 
ID_Exam VARCHAR(50) REFERENCES EXAMEN(ID_Exam),
Note FLOAT CHECK(Note >= 0 AND Note <= 20)
);

CREATE TABLE ENCADREMENT(
ID_Enc SERIAL PRIMARY KEY,
ID_Ens INT REFERENCES ENSEIGNANT(ID_Ens),
Code_C VARCHAR(50) REFERENCES COURS(Code_Cours)
);

-- ------------------------- --
-- 2.2: MODIFICATIONS TABLES --
-- ------------------------- --

-- a: generation de ID valides
ALTER TABLE ETUDIANT DROP chk_id_e; -- erreur dans conditions de constraint
ALTER TABLE ETUDIANT ADD CONSTRAINT chk_id_e CHECK(Num_Etud >= 19800000 AND Num_Etud <= 29999999);
ALTER TABLE ENSEIGNANT ADD CONSTRAINT chk_id_en CHECK(ID_Ens >= 11980000 AND ID_Ens <= 12999999);

-- b: eviter que les CE (FK) donnent des valeurs 'orphelines'
-- note
SELECT NOTE.* FROM NOTE LEFT JOIN ETUDIANT e ON NOTE.Num_Et = e.Num_Etud WHERE e.Num_Etud IS NULL; -- trouver orphelins
DELETE FROM NOTE WHERE ID_Note = 4;
ALTER TABLE NOTE DROP fk_etud_n; 
ALTER TABLE NOTE ADD CONSTRAINT fk_etud_n FOREIGN KEY (Num_Et) REFERENCES ETUDIANT(Num_Etud) 
ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE NOTE DROP fk_exam_n;
ALTER TABLE NOTE ADD CONSTRAINT fk_exam_n FOREIGN KEY (ID_Exam) REFERENCES EXAMEN(ID_Exam)
ON DELETE RESTRICT ON UPDATE CASCADE;
-- inscription
ALTER TABLE INSCRIPTION DROP fk_etud_i; -- nom non-coherent 
ALTER TABLE INSCRIPTION ADD CONSTRAINT fk_etud_i FOREIGN KEY(Num_Et) REFERENCES ETUDIANT(Num_Etud)
ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE INSCRIPTION DROP fk_cours_i; 
ALTER TABLE INSCRIPTION ADD CONSTRAINT fk_cours_i FOREIGN KEY(Code_C) REFERENCES COURS(Code_Cours)
ON DELETE RESTRICT ON UPDATE CASCADE;
-- examen
ALTER TABLE EXAMEN DROP fk_cours_ex; 
ALTER TABLE EXAMEN ADD CONSTRAINT fk_cours_ex FOREIGN KEY(Code_C) REFERENCES COURS(Code_Cours)
ON DELETE RESTRICT ON UPDATE CASCADE;
-- encadrement
ALTER TABLE ENCADREMENT DROP fk_ens_ec; 
ALTER TABLE ENCADREMENT ADD CONSTRAINT fk_ens_ec FOREIGN KEY(ID_Ens) REFERENCES ENSEIGNANT(ID_Ens)
ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE ENCADREMENT DROP fk_cours_ec; 
ALTER TABLE ENCADREMENT ADD CONSTRAINT fk_cours_ec FOREIGN KEY(Code_C) REFERENCES COURS(Code_Cours)
ON DELETE RESTRICT ON UPDATE CASCADE;

-- c: vues et modifications pour simplifier requetes
-- semestres et annees (requete 3)
ALTER TABLE COURS ADD COLUMN Semestre ENUM('S1','S2') NOT NULL;
ALTER TABLE COURS ADD COLUMN Annee YEAR NOT NULL DEFAULT YEAR(CURRENT_DATE())); 
SELECT * FROM COURS;
ALTER TABLE ETUDIANT DROP COLUMN Adresse_Et;

-- moyennes
-- d'un etud dans un cours (requete 18)
DROP VIEW Moy_Etud_par_Cours;
CREATE VIEW Moy_Etud_par_Cours AS
SELECT n.Num_Et, c.Code_Cours, c.Nom_C,
(SUM(n.Note * ex.Coeff) / NULLIF(SUM(ex.Coeff),0)) AS Moyenne -- retour null si /0
FROM NOTE n JOIN EXAMEN ex ON n.ID_Exam = ex.ID_Exam JOIN COURS c ON ex.Code_C = c.Code_Cours
GROUP BY n.Num_Et, c.Code_Cours;
SELECT * FROM Moy_Etud_par_Cours;
-- generale (requete 8)
CREATE OR REPLACE VIEW Moy_Grle_Etud AS 
SELECT  e.Num_Etud, e.Nom_Et, e.Prenom_Et, 
(SUM(mc.Moyenne * c.ECTS) / NULLIF(SUM(c.ECTS),0)) AS Moyenne_Grle
FROM ETUDIANT e JOIN Moy_Etud_par_Cours mc ON e.Num_Etud = mc.Num_Et
JOIN COURS c ON mc.Code_Cours = c.Code_Cours
GROUP BY e.Num_Etud;
SELECT * FROM Moy_Grle_Etud;
-- comparaison semestres (3)

-- ------------------ -- 
-- 3.1 REQUETES COURS --
-- ------------------ -- 

USE SGBD_PROJET;

-- 1: OK (join/right join ne prennent pas noms en dehors de note donc left join)
SELECT e.Num_Etud, e.Nom_Et, e.Prenom_Et FROM ETUDIANT e
LEFT JOIN NOTE n ON e.Num_Etud = n.Num_Et WHERE n.Num_Et IS NULL;

-- 2: OK (vu que cle primaire dans table, pas besoin de penser a doublons)
SELECT COUNT(*) AS Nb_Etud_Tot FROM ETUDIANT;

-- 3: !!!!! creer nouvelles notes OK (cf 4),  separer inscriptions par semestre
-- condition: si moy s1 a > moy s2 (a-1) ou moy s2 a > moy s1 a 


-- 4: group by OK, 2 join OK; ajouter entrees (pour apres: ajouter formule moyenne generale)
SELECT c.Nom_C, AVG(n.Note) AS Moyenne_C FROM NOTE n 
JOIN EXAMEN e ON n.ID_Exam = e.ID_Exam
JOIN COURS c ON e.Code_C = c.Code_Cours
GROUP BY c.Code_Cours, c.Nom_C;

-- 5: OK encadre examen -> encadre matiere, utiliser encadre pour joindre cours et enseignant
SELECT en.Nom_En, en.Prenom_En, ex.ID_Exam, ex.Salle, c.Nom_C 
FROM ENSEIGNANT en JOIN ENCADREMENT ec ON en.ID_Ens = ec.ID_Ens 
JOIN COURS c ON ec.Code_C = c.Code_Cours JOIN EXAMEN ex ON ex.Code_C = c.Code_Cours
ORDER BY en.ID_Ens;

-- 6: 
SELECT c.Nom_C, COUNT(ex.ID_Exam) AS Nb_Examens FROM COURS c 
JOIN EXAMEN ex ON c.Code_Cours = ex.Code_C
GROUP BY c.Nom_C ORDER BY Nb_Examens DESC;

-- 7: switch case -> case when ... then ... else ... end as OK, difference dates: timestampdiff OK
SELECT 
CASE
	WHEN timestampdiff(YEAR,Date_Naiss, CURRENT_DATE()) < 20 THEN '< 20 ans'
	WHEN timestampdiff(YEAR,Date_Naiss, CURRENT_DATE()) BETWEEN 20 AND 30 THEN '20-30 ans'
	ELSE '> 30 ans'
END Age,
COUNT(*) AS Nb_Etudiants,
COUNT(*) / (SELECT COUNT(*) FROM ETUDIANT) AS Proportion
FROM ETUDIANT GROUP BY Age;

-- 8: vue moyenne grle OK
SELECT Nom_Et, Prenom_Et, Moyenne_Grle FROM Moy_Grle_Etud
WHERE Moyenne_Grle > 15;

-- 9: nouveau insert OK 
INSERT INTO ENSEIGNANT(ID_Ens, Nom_En, Prenom_En, Telephone_En, Email_En) VALUES 
('12024556','ROSSI','Andrea','463687652','rossia_univ@email.com'); 

SELECT en.ID_Ens, en.Nom_En, en.Prenom_En FROM ENSEIGNANT en
LEFT JOIN ENCADREMENT ec ON en.ID_Ens = ec.ID_Ens
WHERE ec.ID_Ens IS NULL; 

-- 10:  prof choisi: 			12008112	MAHAMAT	Yasmine
SELECT ID_Ens, Nom_En, Prenom_En FROM ENSEIGNANT;
SELECT c.Nom_C, c.Semestre, c.ECTS, c.Heures FROM Cours c 
JOIN ENCADREMENT ec ON c.Code_Cours = ec.Code_C
JOIN ENSEIGNANT en ON ec.ID_Ens = en.ID_Ens
WHERE en.Nom_En = 'MAHAMAT';

-- 11: 
SELECT c.Nom_C, c.Semestre, c.Annee,
COUNT(i.Code_C) AS Nb_Inscriptions
FROM COURS c LEFT JOIN INSCRIPTION i ON i.Code_C = c.Code_Cours 
GROUP BY c.Code_Cours ORDER BY Nb_Inscriptions DESC;

-- 12: MAX() OK 
SELECT MAX(nmax.Note) FROM NOTE nmax JOIN
EXAMEN ex ON ex.ID_Exam = nmax.ID_Exam
JOIN ETUDIANT et ON et.Num_Etud = nmax.Num_Et
 WHERE nmax.ID_Exam = ex.ID_Exam;
 
SELECT ex.ID_Exam, n.Note, et.Nom_Et, et.Prenom_Et
FROM EXAMEN ex JOIN NOTE n ON ex.ID_Exam = n.ID_Exam
JOIN ETUDIANT et ON et.Num_Etud = n.Num_Et
WHERE n.Note = (SELECT MAX(nmax.Note) FROM NOTE nmax WHERE nmax.ID_Exam = ex.ID_Exam);
-- ORDER BY ex.Date_Ex DESC; -- pas necessaire erreur group by est pour where

-- 13:  timestampdiff() pas besoin. date choisie: 2024-12-31
SELECT * FROM INSCRIPTION WHERE Date_Ins > '2025-10-01';

-- 14: !!!!! AVG(COUNT())?

-- 15: 
SELECT i.* FROM INSCRIPTION i LEFT JOIN ETUDIANT e ON i.Num_Et = e.Num_Etud
WHERE e.Nom_Et = 'NOSKOV' AND e.Prenom_Et = 'Ilya';

-- 16: OK 
SELECT e.Num_Etud, e.Nom_Et, e.Prenom_Et FROM ETUDIANT e
JOIN INSCRIPTION i ON i.Num_Et = e.Num_Etud  JOIN COURS c ON c.Code_Cours = i.Code_C
WHERE c.Nom_C = 'Biologie Moleculaire 2';

-- 17: OK structure switch (cf.7)
SELECT 
CASE
	WHEN MONTH(Date_Ins) = 1 THEN 'Jan'
	WHEN MONTH(Date_Ins) = 2 THEN 'Fev'
    WHEN MONTH(Date_Ins) = 3 THEN 'Mar'
	WHEN MONTH(Date_Ins) = 4 THEN 'Avr'
    WHEN MONTH(Date_Ins) = 5 THEN 'Mai'
    WHEN MONTH(Date_Ins) = 6 THEN 'Jun'
    WHEN MONTH(Date_Ins) = 7 THEN 'Jul'
    WHEN MONTH(Date_Ins) = 8 THEN 'Aut'
    WHEN MONTH(Date_Ins) = 9 THEN 'Sep'
    WHEN MONTH(Date_Ins) = 10 THEN 'Oct'
    WHEN MONTH(Date_Ins) = 11 THEN 'Nov'
    WHEN MONTH(Date_Ins) = 12 THEN 'Dec'
END Mois,
COUNT(*) AS Nb_Ins
FROM INSCRIPTION GROUP BY Mois;

-- 18: OK
SELECT e.Nom_Et, e.Prenom_Et, mc.* FROM ETUDIANT e
JOIN Moy_Etud_par_Cours mc ON mc.Num_Et = e.Num_Etud ORDER BY Num_Et;					

-- 19: ajouter 3e matiere OK, remplacer WHERE COUNT OK
INSERT INTO COURS (Code_Cours, Nom_C, ECTS, Heures, Annee, Semestre) VALUES
('OOPINF','Programmation Oriente Objet',4,30,2025,'S2'); 
INSERT INTO INSCRIPTION(ID_Ins, Num_Et, Code_C,Status_Ins, Date_Ins, Raison_Annul) VALUES 
(6,20255423,'OOPINF','EnCours','2025-08-30 19:18:26',NULL);

SELECT e.Nom_Et, e.Prenom_Et FROM ETUDIANT e JOIN INSCRIPTION i ON i.Num_Et = e.Num_Etud 
GROUP BY e.Num_Etud HAVING COUNT(i.Num_Et) > 3;

-- 20: OK
SELECT en.*,c.Nom_C FROM ENSEIGNANT en LEFT JOIN ENCADREMENT ec ON ec.ID_Ens = en.ID_Ens 
LEFT JOIN COURS c on c.Code_Cours = ec.Code_C ORDER BY en.Nom_En, en.Prenom_En;

-- 21: OK
SELECT * FROM INSCRIPTION WHERE Status_Ins = 'Annul' OR Status_Ins = 'Suppr';

-- 22: OK MAX() -> DESC LIMIT 1
INSERT INTO ENCADREMENT(ID_Enc, ID_Ens, Code_C) VALUES 
(3,12008128,'OOPINF');

SELECT en.Nom_En, en.Prenom_En, COUNT(ec.ID_Ens) AS Nb_Cours 
FROM ENSEIGNANT en JOIN ENCADREMENT ec ON ec.ID_Ens = en.ID_Ens
GROUP BY en.ID_Ens
ORDER BY Nb_Cours DESC LIMIT 1;

-- 23: OK
SELECT * FROM ETUDIANT;

-- 24:  OK
SELECT c.*, COUNT(i.Num_Et) AS Nb_Ins FROM COURS c JOIN INSCRIPTION i ON c.Code_Cours = i.Code_C
GROUP BY c.Code_Cours ORDER BY Nb_Ins DESC;


-- 25: OK (a faire avec jeu final) REMPLACER 2 -> 5 -> 50, 
SELECT c.*, COUNT(i.Num_Et) AS Nb_Ins FROM COURS c JOIN INSCRIPTION i ON c.Code_Cours = i.Code_C 
GROUP BY c.Code_Cours HAVING Nb_Ins >= 50;

-- 26: OK, raccourcir; condition moyparcours count ssi > 10, groupby
SELECT mc.Code_Cours, mc.Nom_C, COUNT(DISTINCT mc.Num_Et) AS Nb_Etud, 
SUM(CASE WHEN mc.Moyenne > 10 THEN 1 ELSE 0 END) AS Nb_Val,
-- Nb_Val/Nb_Etud directement ne marche pas 
SUM(CASE WHEN mc.Moyenne > 10 THEN 1 ELSE 0 END)/COUNT(DISTINCT mc.Num_Et) AS Taux_Reussite
FROM Moy_Etud_par_Cours mc GROUP BY mc.Code_Cours ORDER BY Taux_Reussite DESC LIMIT 5;

-- 27: OK
SELECT COUNT(ID_Ins) AS Nb_Ins_Annul FROM INSCRIPTION WHERE Status_Ins = 'Annul';

-- 28: !!!!!!!!!!!!!!!
SELECT et.*, COUNT(DISTINCT i.Code_C) AS Nb_C_Suivis FROM ETUDIANT et JOIN INSCRIPTION i ON i.Num_Et = et.Num_Etud
JOIN ENCADREMENT ec ON ec.Code_C = i.Code_C JOIN ENSEIGNANT en ON en.ID_Ens = ec.ID_Ens
WHERE en.ID_Ens = '12010490' GROUP BY et.Num_Etud
HAVING COUNT(DISTINCT i.Code_C) = COUNT(DISTINCT ec.Code_C);

-- 29: OK ins join etud join cours join encadre join ens
SELECT et.Num_Etud, et.Nom_Et, et.Prenom_Et, c.Nom_C, en.Nom_En, en.Prenom_En 
FROM INSCRIPTION i JOIN ETUDIANT et ON i.Num_Et = et.Num_Etud
JOIN COURS c ON c.Code_Cours = i.Code_C
JOIN ENCADREMENT ec ON ec.Code_C = i.Code_C
JOIN ENSEIGNANT en ON en.ID_Ens = ec.ID_Ens
ORDER BY et.Num_Etud;

-- 30: OK moy par cours <- moy etud
SELECT mc.Nom_C,
COUNT(DISTINCT mc.Num_Et) AS Nb_Etud,
AVG(mc.Moyenne) AS Moy_C FROM moy_etud_par_cours mc
GROUP BY mc.Code_Cours 
HAVING Moy_C <= 12;

-- 31: OK
SELECT e.Nom_Et, e.Prenom_Et, i.Date_Ins, c.Nom_C FROM INSCRIPTION i
JOIN ETUDIANT e ON e.Num_Etud = i.Num_Et
JOIN COURS c ON c.Code_Cours = i.Code_C
WHERE i.Status_Ins = 'Val' OR i.Status_Ins = 'EnCours'
ORDER BY e.Nom_Et, e.Prenom_Et;

-- 32: OK, 
SELECT e.Nom_Et, e.Prenom_Et FROM ETUDIANT e
JOIN INSCRIPTION i ON i.Num_Et = e.Num_Etud
JOIN EXAMEN ex ON ex.Code_C = i.Code_C
WHERE ex.ID_Exam = 'BMG2_DS1_2526';

-- 33: OK, 
SELECT ex.ID_Exam, n.Num_Et, n.Note FROM NOTE n JOIN Examen ex ON ex.ID_Exam = n.ID_Exam  
JOIN COURS c ON c.Code_Cours = ex.Code_C
WHERE c.Nom_C = 'Droit Administratif' ORDER BY ex.ID_Exam, n.Num_Et;

-- 34: OK, 
SELECT ex.* FROM Examen ex JOIN COURS c ON c.Code_Cours = ex.Code_C
WHERE c.Nom_C = 'Introduction a Immunologie';

-- 35: OK
SELECT en.Nom_En, en.Prenom_En, c.* FROM COURS c JOIN ENCADREMENT ec ON c.Code_Cours = ec.Code_C
JOIN ENSEIGNANT en ON en.ID_Ens = ec.ID_Ens;

-- 36: OK count, group by, unique -> distinct
SELECT en.Nom_En, en.Prenom_En, COUNT(DISTINCT i.Num_Et) AS Nb_Etud FROM ENSEIGNANT en 
JOIN ENCADREMENT ec ON ec.ID_Ens = en.ID_Ens JOIN INSCRIPTION i ON i.Code_C = ec.Code_C
GROUP BY en.ID_Ens;

-- 37: OK nouveau cours, = NULL -> IS NULL 
INSERT INTO COURS (Code_Cours, Nom_C, ECTS, Heures) VALUES
('PHSVSDV','Physiologie Vegetale',2,12);

SELECT c.* FROM COURS c LEFT JOIN INSCRIPTION i ON i.Code_C = c.Code_Cours
WHERE i.Num_Et IS NULL;

-- 38: OK group by moy par matiere AVG(mc.Moyenne) AS Moy_Cours
SELECT en.Nom_En, en.Prenom_En, COUNT(DISTINCT c.Code_Cours) AS Nb_Cours, COUNT(DISTINCT n.Num_Et) AS Nb_Etud,
AVG(mc.Moyenne) AS Moy_Cours
FROM ENSEIGNANT en JOIN ENCADREMENT ec ON en.ID_Ens = ec.ID_Ens
JOIN COURS c ON ec.Code_C = c.Code_Cours LEFT JOIN Moy_Etud_par_Cours mc ON mc.Code_Cours = c.Code_Cours
LEFT JOIN NOTE n ON n.Num_Et = mc.Num_Et
GROUP BY en.ID_Ens;

-- 39: OK
INSERT INTO NOTE(ID_Note, Num_Et, ID_Exam, Note) VALUES
(6,20232732,'BMG2_DS1_2526',7.75);

SELECT e.Nom_Et, e.Prenom_Et, n.ID_Exam, n.Note FROM ETUDIANT e
JOIN NOTE n ON n.Num_Et = e.Num_Etud WHERE n.Note < 10;

-- 40: OK 
SELECT en.Nom_En, en.Prenom_En, COUNT(ec.Code_C) AS Nb_Cours FROM ENSEIGNANT en
JOIN ENCADREMENT ec ON ec.ID_Ens = en.ID_Ens JOIN COURS c ON c.Code_Cours = ec.Code_C
GROUP BY ec.ID_Ens ORDER BY Nb_Cours DESC;

-- 41: OK,  
SELECT c.* FROM COURS c JOIN ENCADREMENT ec ON ec.Code_C = c.Code_Cours
JOIN ENSEIGNANT en ON en.ID_Ens = ec.ID_Ens
WHERE en.Nom_En = 'GUITARD' AND en.Prenom_En = 'Celine';

-- ------------------- -- 
-- 3.2: REQUETES BONUS -- 
-- ------------------- -- 

-- a: chercher etudiants avec email dans un domaine donne (ici example.com)
SELECT Num_Etud, Telephone_Et, Email_Et FROM ETUDIANT WHERE Email_Et LIKE '%@example.fr';

-- b: voir le cours avec la meilleure relation ECTS-HEURES
SELECT *, (ECTS/Heures) AS Taux_ECTS_par_h FROM COURS
ORDER BY Taux_ECTS_par_h DESC LIMIT 1;
-- c: examens qui ont deja eu lieu
SELECT * FROM EXAMEN WHERE Date_Ex < current_date();

-- ------------------- -- 
-- 3.3: REQUETE PROF --
-- ------------------- -- 
-- lister tous les enseignants avec cours quils enseignent 
SELECT en.ID_Ens, en.Nom_En, en.Prenom_En, c.Nom_C
FROM ENSEIGNANT en LEFT JOIN ENCADREMENT ec ON en.ID_Ens = ec.ID_Ens
JOIN COURS c ON c.Code_Cours = ec.Code_C;
-- moyenne par cours pour tous les cours
SELECT mc.Nom_C,
COUNT(mc.Num_Et) AS Nb_Etud,
AVG(mc.Moyenne) AS Moy_C FROM moy_etud_par_cours mc
GROUP BY mc.Code_Cours;

USE SGBD_PROJET;
				