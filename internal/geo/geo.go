package geo

import (
	"database/sql"
	"fmt"

	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

// Service handles geographic operations
type Service struct {
	db *sqlx.DB
}

// NewService creates a new geographic service
func NewService(db *sqlx.DB) *Service {
	return &Service{db: db}
}

// GetDepartments returns all French departments
func (s *Service) GetDepartments() ([]Department, error) {
	var departments []Department
	query := `SELECT id, code, name, region, created_at, updated_at FROM french_departments ORDER BY code`
	
	if err := s.db.Select(&departments, query); err != nil {
		return nil, fmt.Errorf("error fetching departments: %w", err)
	}
	
	return departments, nil
}

// GetDepartmentByCode returns a department by its code
func (s *Service) GetDepartmentByCode(code string) (*Department, error) {
	var dept Department
	query := `SELECT id, code, name, region, created_at, updated_at FROM french_departments WHERE code = $1`
	
	if err := s.db.Get(&dept, query, code); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("department with code %s not found", code)
		}
		return nil, fmt.Errorf("error fetching department: %w", err)
	}
	
	return &dept, nil
}

// GetCommunes returns communes with optional filtering
func (s *Service) GetCommunes(filter TargetingFilter, limit, offset int) ([]Commune, error) {
	var communes []Commune

	query := `
		SELECT c.id, c.insee_code, c.name, c.department_code, c.population, 
		       c.postal_codes, c.latitude, c.longitude, c.created_at, c.updated_at,
		       d.name as department_name, d.region
		FROM french_communes c
		LEFT JOIN french_departments d ON c.department_code = d.code
	`

	// Build WHERE conditions using the query builder
	qb := NewQueryBuilder()
	whereClause, args, err := qb.BuildAdvancedQuery(filter)
	if err != nil {
		return nil, fmt.Errorf("error building query: %w", err)
	}

	if whereClause != "" {
		query += " WHERE " + whereClause
	}

	query += " ORDER BY c.name"

	// Add pagination
	argIndex := len(args) + 1
	if limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argIndex)
		args = append(args, limit)
		argIndex++
	}

	if offset > 0 {
		query += fmt.Sprintf(" OFFSET $%d", argIndex)
		args = append(args, offset)
	}

	if err := s.db.Select(&communes, query, args...); err != nil {
		return nil, fmt.Errorf("error fetching communes: %w", err)
	}

	return communes, nil
}

// GetCommuneByInseeCode returns a commune by its INSEE code
func (s *Service) GetCommuneByInseeCode(inseeCode string) (*Commune, error) {
	var commune Commune
	query := `
		SELECT c.id, c.insee_code, c.name, c.department_code, c.population, 
		       c.postal_codes, c.latitude, c.longitude, c.created_at, c.updated_at,
		       d.name as department_name, d.region
		FROM french_communes c
		LEFT JOIN french_departments d ON c.department_code = d.code
		WHERE c.insee_code = $1
	`
	
	if err := s.db.Get(&commune, query, inseeCode); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("commune with INSEE code %s not found", inseeCode)
		}
		return nil, fmt.Errorf("error fetching commune: %w", err)
	}
	
	return &commune, nil
}

// CreateCommune creates a new commune
func (s *Service) CreateCommune(commune *Commune) error {
	query := `
		INSERT INTO french_communes (insee_code, name, department_code, population, postal_codes, latitude, longitude)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at
	`
	
	err := s.db.QueryRow(query, commune.InseeCode, commune.Name, commune.DepartmentCode, 
		commune.Population, pq.Array(commune.PostalCodes), commune.Latitude, commune.Longitude).
		Scan(&commune.ID, &commune.CreatedAt, &commune.UpdatedAt)
	
	if err != nil {
		return fmt.Errorf("error creating commune: %w", err)
	}
	
	return nil
}

// UpdateCommune updates an existing commune
func (s *Service) UpdateCommune(commune *Commune) error {
	query := `
		UPDATE french_communes 
		SET name = $2, department_code = $3, population = $4, postal_codes = $5, 
		    latitude = $6, longitude = $7, updated_at = NOW()
		WHERE id = $1
	`
	
	result, err := s.db.Exec(query, commune.ID, commune.Name, commune.DepartmentCode, 
		commune.Population, pq.Array(commune.PostalCodes), commune.Latitude, commune.Longitude)
	
	if err != nil {
		return fmt.Errorf("error updating commune: %w", err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("error checking affected rows: %w", err)
	}
	
	if rowsAffected == 0 {
		return fmt.Errorf("commune with ID %d not found", commune.ID)
	}
	
	return nil
}

// AssociateSubscriberToCommune associates a subscriber with a commune
func (s *Service) AssociateSubscriberToCommune(subscriberID, communeID int) error {
	query := `
		INSERT INTO subscriber_communes (subscriber_id, commune_id)
		VALUES ($1, $2)
		ON CONFLICT (subscriber_id, commune_id) DO NOTHING
	`
	
	_, err := s.db.Exec(query, subscriberID, communeID)
	if err != nil {
		return fmt.Errorf("error associating subscriber to commune: %w", err)
	}
	
	return nil
}

// RemoveSubscriberFromCommune removes the association between a subscriber and a commune
func (s *Service) RemoveSubscriberFromCommune(subscriberID, communeID int) error {
	query := `DELETE FROM subscriber_communes WHERE subscriber_id = $1 AND commune_id = $2`
	
	_, err := s.db.Exec(query, subscriberID, communeID)
	if err != nil {
		return fmt.Errorf("error removing subscriber from commune: %w", err)
	}
	
	return nil
}

// GetSubscriberCommunes returns all communes associated with a subscriber
func (s *Service) GetSubscriberCommunes(subscriberID int) ([]Commune, error) {
	var communes []Commune
	query := `
		SELECT c.id, c.insee_code, c.name, c.department_code, c.population, 
		       c.postal_codes, c.latitude, c.longitude, c.created_at, c.updated_at,
		       d.name as department_name, d.region
		FROM french_communes c
		LEFT JOIN french_departments d ON c.department_code = d.code
		INNER JOIN subscriber_communes sc ON c.id = sc.commune_id
		WHERE sc.subscriber_id = $1
		ORDER BY c.name
	`
	
	if err := s.db.Select(&communes, query, subscriberID); err != nil {
		return nil, fmt.Errorf("error fetching subscriber communes: %w", err)
	}
	
	return communes, nil
}

// CountTargetingRecipients counts the number of subscribers matching the targeting criteria
func (s *Service) CountTargetingRecipients(filter TargetingFilter) (int, error) {
	var count int

	query := `
		SELECT COUNT(DISTINCT s.id)
		FROM subscribers s
		LEFT JOIN subscriber_communes sc ON s.id = sc.subscriber_id
		LEFT JOIN french_communes c ON sc.commune_id = c.id
		LEFT JOIN french_departments d ON c.department_code = d.code
		WHERE s.status = 'enabled'
	`

	// Build WHERE conditions using the query builder
	qb := NewQueryBuilder()
	whereClause, args, err := qb.BuildAdvancedQuery(filter)
	if err != nil {
		return 0, fmt.Errorf("error building query: %w", err)
	}

	if whereClause != "" {
		query += " AND " + whereClause
	}

	if err := s.db.Get(&count, query, args...); err != nil {
		return 0, fmt.Errorf("error counting targeting recipients: %w", err)
	}

	return count, nil
}

// GetTargetedSubscribers returns subscribers matching the targeting criteria
func (s *Service) GetTargetedSubscribers(filter TargetingFilter) ([]CommuneWithSubscriber, error) {
	var subscribers []CommuneWithSubscriber

	query := `
		SELECT DISTINCT s.id as subscriber_id, s.email as subscriber_email, 
		       s.name as subscriber_name, s.status as subscriber_status,
		       c.id, c.insee_code, c.name, c.department_code, c.population, 
		       c.postal_codes, c.latitude, c.longitude, c.created_at, c.updated_at,
		       d.name as department_name, d.region
		FROM subscribers s
		INNER JOIN subscriber_communes sc ON s.id = sc.subscriber_id
		INNER JOIN french_communes c ON sc.commune_id = c.id
		LEFT JOIN french_departments d ON c.department_code = d.code
		WHERE s.status = 'enabled'
	`

	// Build WHERE conditions using the query builder
	qb := NewQueryBuilder()
	whereClause, args, err := qb.BuildAdvancedQuery(filter)
	if err != nil {
		return nil, fmt.Errorf("error building query: %w", err)
	}

	if whereClause != "" {
		query += " AND " + whereClause
	}

	query += " ORDER BY c.name, s.name"

	if err := s.db.Select(&subscribers, query, args...); err != nil {
		return nil, fmt.Errorf("error fetching targeted subscribers: %w", err)
	}

	return subscribers, nil
}

// GetTargetingStats returns statistics for targeting
func (s *Service) GetTargetingStats(filter TargetingFilter) (*TargetingStats, error) {
	stats := &TargetingStats{
		ByDepartment:      make(map[string]int),
		ByRegion:          make(map[string]int),
		ByPopulationRange: make(map[string]int),
	}

	// Get total counts
	communes, err := s.GetCommunes(filter, 0, 0)
	if err != nil {
		return nil, err
	}

	stats.TotalCommunes = len(communes)

	// Count subscribers
	count, err := s.CountTargetingRecipients(filter)
	if err != nil {
		return nil, err
	}
	stats.TotalSubscribers = count

	// Calculate statistics by department and region
	var totalPop int64
	for _, commune := range communes {
		stats.ByDepartment[commune.DepartmentCode]++
		if commune.Region != "" {
			stats.ByRegion[commune.Region]++
		}
		totalPop += int64(commune.Population)

		// Population ranges
		popRange := getPopulationRange(commune.Population)
		stats.ByPopulationRange[popRange]++
	}

	if len(communes) > 0 {
		stats.AveragePopulation = float64(totalPop) / float64(len(communes))
	}

	// Get detailed population range stats
	stats.PopulationRanges = s.getPopulationRangeStats(filter)

	return stats, nil
}

// GetTargetingPreview returns a preview of targeting results
func (s *Service) GetTargetingPreview(filter TargetingFilter) (*TargetingPreview, error) {
	// Get sample communes (limited to 10 for preview)
	sampleCommunes, err := s.GetCommunes(filter, 10, 0)
	if err != nil {
		return nil, err
	}

	// Get full statistics
	stats, err := s.GetTargetingStats(filter)
	if err != nil {
		return nil, err
	}

	// Count total recipients
	count, err := s.CountTargetingRecipients(filter)
	if err != nil {
		return nil, err
	}

	// Calculate total population
	var totalPop int64
	allCommunes, err := s.GetCommunes(filter, 0, 0)
	if err != nil {
		return nil, err
	}

	for _, commune := range allCommunes {
		totalPop += int64(commune.Population)
	}

	preview := &TargetingPreview{
		Count:           count,
		Filters:         filter,
		SampleCommunes:  sampleCommunes,
		Statistics:      *stats,
		EstimatedReach:  count,
		PopulationTotal: totalPop,
	}

	return preview, nil
}

// GetDepartmentStats returns statistics by department
func (s *Service) GetDepartmentStats() (map[string]interface{}, error) {
	var results []struct {
		DepartmentCode string `db:"department_code"`
		DepartmentName string `db:"department_name"`
		Region         string `db:"region"`
		CommuneCount   int    `db:"commune_count"`
		SubscriberCount int   `db:"subscriber_count"`
		TotalPopulation int64 `db:"total_population"`
	}

	query := `
		SELECT 
			d.code as department_code,
			d.name as department_name,
			d.region,
			COUNT(DISTINCT c.id) as commune_count,
			COUNT(DISTINCT sc.subscriber_id) as subscriber_count,
			COALESCE(SUM(c.population), 0) as total_population
		FROM french_departments d
		LEFT JOIN french_communes c ON d.code = c.department_code
		LEFT JOIN subscriber_communes sc ON c.id = sc.commune_id
		GROUP BY d.code, d.name, d.region
		ORDER BY d.code
	`

	if err := s.db.Select(&results, query); err != nil {
		return nil, fmt.Errorf("error fetching department stats: %w", err)
	}

	stats := make(map[string]interface{})
	stats["departments"] = results

	return stats, nil
}

// GetPopulationRangeStats returns statistics by population ranges
func (s *Service) GetPopulationRangeStats() ([]PopulationRangeStats, error) {
	return s.getPopulationRangeStats(TargetingFilter{}), nil
}

// Helper functions

func (s *Service) getPopulationRangeStats(filter TargetingFilter) []PopulationRangeStats {
	ranges := []PopulationRangeStats{
		{Range: "0-500", Min: 0, Max: 500},
		{Range: "501-1000", Min: 501, Max: 1000},
		{Range: "1001-2000", Min: 1001, Max: 2000},
		{Range: "2001-5000", Min: 2001, Max: 5000},
		{Range: "5001-10000", Min: 5001, Max: 10000},
		{Range: "10001-20000", Min: 10001, Max: 20000},
		{Range: "20001-50000", Min: 20001, Max: 50000},
		{Range: "50001+", Min: 50001, Max: 999999999},
	}

	for i := range ranges {
		rangeFilter := filter
		rangeFilter.PopulationMin = &ranges[i].Min
		rangeFilter.PopulationMax = &ranges[i].Max

		communes, err := s.GetCommunes(rangeFilter, 0, 0)
		if err == nil {
			ranges[i].Count = len(communes)
		}

		count, err := s.CountTargetingRecipients(rangeFilter)
		if err == nil {
			ranges[i].Subscribers = count
		}
	}

	return ranges
}

func getPopulationRange(population int) string {
	switch {
	case population <= 500:
		return "0-500"
	case population <= 1000:
		return "501-1000"
	case population <= 2000:
		return "1001-2000"
	case population <= 5000:
		return "2001-5000"
	case population <= 10000:
		return "5001-10000"
	case population <= 20000:
		return "10001-20000"
	case population <= 50000:
		return "20001-50000"
	default:
		return "50001+"
	}
}

// GetGeoStats returns general geographic statistics
func (s *Service) GetGeoStats() (*GeoStats, error) {
	stats := &GeoStats{}

	// Count departments
	var deptCount int
	err := s.db.Get(&deptCount, "SELECT COUNT(*) FROM french_departments")
	if err != nil {
		return nil, fmt.Errorf("error counting departments: %w", err)
	}
	stats.TotalDepartments = deptCount

	// Count communes
	var communeCount int
	err = s.db.Get(&communeCount, "SELECT COUNT(*) FROM french_communes")
	if err != nil {
		return nil, fmt.Errorf("error counting communes: %w", err)
	}
	stats.TotalCommunes = communeCount

	// Count subscribers
	var subCount int
	err = s.db.Get(&subCount, "SELECT COUNT(DISTINCT subscriber_id) FROM subscriber_communes")
	if err != nil {
		return nil, fmt.Errorf("error counting subscribers: %w", err)
	}
	stats.TotalSubscribers = subCount

	// Count communes with subscribers
	var communesWithSubs int
	err = s.db.Get(&communesWithSubs, "SELECT COUNT(DISTINCT commune_id) FROM subscriber_communes")
	if err != nil {
		return nil, fmt.Errorf("error counting communes with subscribers: %w", err)
	}
	stats.CommunesWithSubscribers = communesWithSubs

	// Calculate coverage percentage
	if stats.TotalCommunes > 0 {
		stats.CoveragePercentage = float64(stats.CommunesWithSubscribers) / float64(stats.TotalCommunes) * 100
	}

	// Population statistics
	var totalPop, avgPop sql.NullInt64
	err = s.db.QueryRow("SELECT SUM(population), AVG(population) FROM french_communes").Scan(&totalPop, &avgPop)
	if err != nil {
		return nil, fmt.Errorf("error calculating population stats: %w", err)
	}

	if totalPop.Valid {
		stats.TotalPopulation = totalPop.Int64
	}
	if avgPop.Valid {
		stats.AveragePopulation = float64(avgPop.Int64)
	}

	// Regional breakdown
	var regionStats []RegionStat
	regionQuery := `
		SELECT 
			d.region,
			COUNT(DISTINCT d.code) as departments,
			COUNT(DISTINCT c.id) as communes,
			COUNT(DISTINCT sc.subscriber_id) as subscribers,
			COALESCE(SUM(c.population), 0) as total_population
		FROM french_departments d
		LEFT JOIN french_communes c ON d.code = c.department_code
		LEFT JOIN subscriber_communes sc ON c.id = sc.commune_id
		GROUP BY d.region
		ORDER BY d.region
	`

	err = s.db.Select(&regionStats, regionQuery)
	if err != nil {
		return nil, fmt.Errorf("error fetching region stats: %w", err)
	}

	// Calculate coverage percentage for each region
	for i := range regionStats {
		if regionStats[i].Communes > 0 {
			communesWithSubsInRegion := 0
			err = s.db.Get(&communesWithSubsInRegion, `
				SELECT COUNT(DISTINCT c.id) 
				FROM french_communes c
				INNER JOIN french_departments d ON c.department_code = d.code
				INNER JOIN subscriber_communes sc ON c.id = sc.commune_id
				WHERE d.region = $1
			`, regionStats[i].Region)
			if err == nil {
				regionStats[i].CoveragePercent = float64(communesWithSubsInRegion) / float64(regionStats[i].Communes) * 100
			}
		}
	}

	stats.RegionStats = regionStats

	return stats, nil
}
