/*
SQL Data Exploration of COVID data

Skills demonstrated in this project include: Basic SQL query structure, Aggregate Functions , Aliases, Joins, Converting Data Types,
Windows Functions, CTE's, Temp Tables, Creating Views. 
*/

-- Basic SELECT statement to begin to examine data to ensure it has been uploaded properly to Database into tables from Excel files

SELECT *
FROM CovidPortfolio.dbo.CovidDeaths
ORDER BY 3,4

SELECT *
FROM CovidPortfolio.dbo.CovidVac
ORDER BY location, date



/* 
Examining data reveals potential issue when working with location (country) and continent attributes. For entries where continent is NULL the location
column has a continent name. This indicates that when continent-wide COVID data was collected the continent name was entered in the location (country) column. A work
around to ensure only country level data is used only data where continent is NOT NULL should be pulled.
*/

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL
ORDER BY location, date



-- Let's look at total cases vs. total deaths, shows likelihood of dying after contracting covid in a particular country

SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercent
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL
ORDER BY location, date



-- If interested in death rate for a particular country can add to WHERE clause to filter: example United States

SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercent
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL AND location = 'United States'
ORDER BY location, date



-- Examine country infection rate by looking at Total Cases vs Population

SELECT location, date, total_cases, population, (total_cases/population)*100 as InfectionRate
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL
ORDER BY location, date



-- Aggregate Functions: Pull data to find the highest infection rate for each country

SELECT location, population, MAX(total_cases) as MaxTotalCases, MAX((total_cases/population))*100 as MaxInfectionRate
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL
GROUP BY location, population
ORDER BY MaxInfectionRate DESC



-- Total deaths in each country, ordered by total deaths to determine which country had most deaths
-- Total_deaths data needed to be converted to integers for aggregate function to work successfully

SELECT location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL
GROUP BY location
ORDER BY TotalDeathCount DESC



-- To Break things down by continent instead of country can look at data where continent column IS NULL 

SELECT location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is NULL
GROUP BY location
ORDER BY TotalDeathCount DESC



-- GLOBAL NUMBERS- Total daily world new case, new death, and daily world death rate

SELECT date, SUM(new_cases) as WorldCases, SUM(cast(new_deaths as int)) as WorldDeaths, SUM(cast(new_deaths as int))/SUM(new_cases)*100 as WorldDeathRate
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL AND date > '2020-01-22 00:00:00.000' --added filter by date because data all NULL until 1/23/2020
GROUP BY date
ORDER BY date



-- Total world numbers for entire data set simply remove the date data

SELECT SUM(new_cases) as WorldCases, SUM(cast(new_deaths as int)) as WorldDeaths, SUM(cast(new_deaths as int))/SUM(new_cases)*100 as WorldDeathRate
FROM CovidPortfolio.dbo.CovidDeaths
WHERE continent is not NULL AND date > '2020-01-22 00:00:00.000' --added filter by date because data all NULL until 1/23/2020



-- Let's start to look at the Vaccination data

SELECT *
FROM CovidPortfolio.dbo.CovidVac



-- Need to Join Death and Vaccination tables for further analysis

SELECT *
FROM CovidPortfolio.dbo.CovidDeaths as dea
JOIN CovidPortfolio.dbo.CovidVac as vac
	ON dea.location = vac.location
	and	dea.date = vac.date



--Daily new vaccinations info

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
FROM CovidPortfolio.dbo.CovidDeaths as dea
JOIN CovidPortfolio.dbo.CovidVac as vac
	ON dea.location = vac.location
	and	dea.date = vac.date
WHERE dea.continent is not NULL
ORDER BY 2,3



-- Total Population vs. Vaccinations
-- Can pull information that includes rolling count of total vaccinations in each country using a PARTITION function

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as int)) OVER (PARTITION BY dea.location ORDER BY dea.location, 
dea.date) as RollingVaccinationCount
FROM CovidPortfolio.dbo.CovidDeaths as dea
JOIN CovidPortfolio.dbo.CovidVac as vac
	ON dea.location = vac.location
	and	dea.date = vac.date
WHERE dea.continent is not NULL
ORDER BY 2,3



-- Using CTE to perform Calculation on Partition By in previous query
-- Can now determine the rolling percentage of population that has received vaccination

WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingVaccinationCount)
as
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as int)) OVER (PARTITION BY dea.location ORDER BY dea.location, 
dea.date) as RollingVaccinationCount
FROM CovidPortfolio.dbo.CovidDeaths as dea
JOIN CovidPortfolio.dbo.CovidVac as vac
	ON dea.location = vac.location
	and	dea.date = vac.date
WHERE dea.continent is not NULL
)
Select *, (RollingVaccinationCount/Population)*100 as TotalPercentVaccinated
FROM PopvsVac
ORDER BY 2,3



-- Using Temp Table to perform Calculation on Partition By in previous query
-- DROP Table clause added to be able to make error free changes to TEMP Table if needed

DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar (255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
RollingVaccinationCount numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as int)) OVER (PARTITION BY dea.location ORDER BY dea.location, 
dea.date) as RollingVaccinationCount
FROM CovidPortfolio.dbo.CovidDeaths as dea
JOIN CovidPortfolio.dbo.CovidVac as vac
	ON dea.location = vac.location
	and	dea.date = vac.date
WHERE dea.continent is not NULL

Select *, (RollingVaccinationCount/Population)*100 as TotalPercentVaccinated
FROM #PercentPopulationVaccinated
ORDER BY 2,3



-- Creating View to store data for later visualiztions

CREATE VIEW TotalPercentVaccinated as
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as int)) OVER (PARTITION BY dea.location ORDER BY dea.location, 
dea.date) as RollingVaccinationCount
FROM CovidPortfolio.dbo.CovidDeaths as dea
JOIN CovidPortfolio.dbo.CovidVac as vac
	ON dea.location = vac.location
	and	dea.date = vac.date
WHERE dea.continent is not NULL

















