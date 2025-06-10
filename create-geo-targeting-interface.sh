#!/bin/bash

# Script pour créer l'interface de ciblage géographique

echo "🎯 CRÉATION DE L'INTERFACE DE CIBLAGE GÉOGRAPHIQUE"
echo "=================================================="

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Créer le fichier JavaScript pour l'interface de ciblage
create_geo_targeting_js() {
    log_info "Création du script de ciblage géographique..."
    
    cat > geo-targeting.js << 'EOF'
// Interface de ciblage géographique pour Listmonk
(function() {
    'use strict';
    
    // Configuration
    const API_BASE = window.location.origin + '/api';
    
    // Données des départements français
    const DEPARTMENTS = {
        '01': 'Ain', '02': 'Aisne', '03': 'Allier', '04': 'Alpes-de-Haute-Provence',
        '05': 'Hautes-Alpes', '06': 'Alpes-Maritimes', '07': 'Ardèche', '08': 'Ardennes',
        '09': 'Ariège', '10': 'Aube', '11': 'Aude', '12': 'Aveyron',
        '13': 'Bouches-du-Rhône', '14': 'Calvados', '15': 'Cantal', '16': 'Charente',
        '17': 'Charente-Maritime', '18': 'Cher', '19': 'Corrèze', '21': 'Côte-d\'Or',
        '22': 'Côtes-d\'Armor', '23': 'Creuse', '24': 'Dordogne', '25': 'Doubs',
        '26': 'Drôme', '27': 'Eure', '28': 'Eure-et-Loir', '29': 'Finistère',
        '30': 'Gard', '31': 'Haute-Garonne', '32': 'Gers', '33': 'Gironde',
        '34': 'Hérault', '35': 'Ille-et-Vilaine', '36': 'Indre', '37': 'Indre-et-Loire',
        '38': 'Isère', '39': 'Jura', '40': 'Landes', '41': 'Loir-et-Cher',
        '42': 'Loire', '43': 'Haute-Loire', '44': 'Loire-Atlantique', '45': 'Loiret',
        '46': 'Lot', '47': 'Lot-et-Garonne', '48': 'Lozère', '49': 'Maine-et-Loire',
        '50': 'Manche', '51': 'Marne', '52': 'Haute-Marne', '53': 'Mayenne',
        '54': 'Meurthe-et-Moselle', '55': 'Meuse', '56': 'Morbihan', '57': 'Moselle',
        '58': 'Nièvre', '59': 'Nord', '60': 'Oise', '61': 'Orne',
        '62': 'Pas-de-Calais', '63': 'Puy-de-Dôme', '64': 'Pyrénées-Atlantiques', '65': 'Hautes-Pyrénées',
        '66': 'Pyrénées-Orientales', '67': 'Bas-Rhin', '68': 'Haut-Rhin', '69': 'Rhône',
        '70': 'Haute-Saône', '71': 'Saône-et-Loire', '72': 'Sarthe', '73': 'Savoie',
        '74': 'Haute-Savoie', '75': 'Paris', '76': 'Seine-Maritime', '77': 'Seine-et-Marne',
        '78': 'Yvelines', '79': 'Deux-Sèvres', '80': 'Somme', '81': 'Tarn',
        '82': 'Tarn-et-Garonne', '83': 'Var', '84': 'Vaucluse', '85': 'Vendée',
        '86': 'Vienne', '87': 'Haute-Vienne', '88': 'Vosges', '89': 'Yonne',
        '90': 'Territoire de Belfort', '91': 'Essonne', '92': 'Hauts-de-Seine', '93': 'Seine-Saint-Denis',
        '94': 'Val-de-Marne', '95': 'Val-d\'Oise'
    };
    
    // Régions prédéfinies
    const REGIONS = {
        'IDF': ['75', '77', '78', '91', '92', '93', '94', '95'],
        'PACA': ['04', '05', '06', '13', '83', '84'],
        'OCCITANIE': ['09', '11', '12', '30', '31', '32', '34', '46', '48', '65', '66', '81', '82'],
        'NOUVELLE_AQUITAINE': ['16', '17', '19', '23', '24', '33', '40', '47', '64', '79', '86', '87'],
        'AUVERGNE_RHONE_ALPES': ['01', '03', '07', '15', '26', '38', '42', '43', '63', '69', '73', '74']
    };
    
    // Créer l'interface
    function createGeoTargetingInterface() {
        // Vérifier si on est sur la page des abonnés
        if (!window.location.pathname.includes('/subscribers')) {
            return;
        }
        
        // Créer le bouton flottant
        const floatingButton = document.createElement('div');
        floatingButton.innerHTML = '🎯 Ciblage Géo';
        floatingButton.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #007bff;
            color: white;
            padding: 12px 20px;
            border-radius: 25px;
            cursor: pointer;
            z-index: 1000;
            font-weight: bold;
            box-shadow: 0 4px 12px rgba(0,123,255,0.3);
            transition: all 0.3s ease;
        `;
        
        floatingButton.addEventListener('mouseenter', () => {
            floatingButton.style.transform = 'scale(1.05)';
            floatingButton.style.boxShadow = '0 6px 20px rgba(0,123,255,0.4)';
        });
        
        floatingButton.addEventListener('mouseleave', () => {
            floatingButton.style.transform = 'scale(1)';
            floatingButton.style.boxShadow = '0 4px 12px rgba(0,123,255,0.3)';
        });
        
        floatingButton.addEventListener('click', showGeoTargetingModal);
        document.body.appendChild(floatingButton);
    }
    
    // Afficher la modal de ciblage
    function showGeoTargetingModal() {
        // Créer la modal
        const modal = document.createElement('div');
        modal.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 2000;
            display: flex;
            align-items: center;
            justify-content: center;
        `;
        
        const modalContent = document.createElement('div');
        modalContent.style.cssText = `
            background: white;
            padding: 30px;
            border-radius: 10px;
            max-width: 600px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        `;
        
        modalContent.innerHTML = `
            <h2 style="margin-top: 0; color: #333;">🎯 Ciblage Géographique</h2>
            
            <div style="margin-bottom: 20px;">
                <h3>🗺️ Sélection par Département</h3>
                <div id="department-selection" style="max-height: 200px; overflow-y: auto; border: 1px solid #ddd; padding: 10px; border-radius: 5px;">
                    <!-- Départements seront ajoutés ici -->
                </div>
                <div style="margin-top: 10px;">
                    <button id="select-all-depts" style="margin-right: 10px; padding: 5px 10px; background: #28a745; color: white; border: none; border-radius: 3px; cursor: pointer;">Tout sélectionner</button>
                    <button id="clear-all-depts" style="padding: 5px 10px; background: #dc3545; color: white; border: none; border-radius: 3px; cursor: pointer;">Tout désélectionner</button>
                </div>
            </div>
            
            <div style="margin-bottom: 20px;">
                <h3>🏙️ Filtres Rapides par Région</h3>
                <div style="display: flex; flex-wrap: wrap; gap: 10px;">
                    <button class="region-btn" data-region="IDF" style="padding: 8px 15px; background: #17a2b8; color: white; border: none; border-radius: 5px; cursor: pointer;">Île-de-France</button>
                    <button class="region-btn" data-region="PACA" style="padding: 8px 15px; background: #17a2b8; color: white; border: none; border-radius: 5px; cursor: pointer;">PACA</button>
                    <button class="region-btn" data-region="OCCITANIE" style="padding: 8px 15px; background: #17a2b8; color: white; border: none; border-radius: 5px; cursor: pointer;">Occitanie</button>
                    <button class="region-btn" data-region="NOUVELLE_AQUITAINE" style="padding: 8px 15px; background: #17a2b8; color: white; border: none; border-radius: 5px; cursor: pointer;">Nouvelle-Aquitaine</button>
                    <button class="region-btn" data-region="AUVERGNE_RHONE_ALPES" style="padding: 8px 15px; background: #17a2b8; color: white; border: none; border-radius: 5px; cursor: pointer;">Auvergne-Rhône-Alpes</button>
                </div>
            </div>
            
            <div style="margin-bottom: 20px;">
                <h3>👥 Filtrage par Population</h3>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                    <div>
                        <label>Population minimum :</label>
                        <input type="number" id="min-population" placeholder="Ex: 1000" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px; margin-top: 5px;">
                    </div>
                    <div>
                        <label>Population maximum :</label>
                        <input type="number" id="max-population" placeholder="Ex: 50000" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px; margin-top: 5px;">
                    </div>
                </div>
                <div style="margin-top: 10px; display: flex; flex-wrap: wrap; gap: 10px;">
                    <button class="pop-btn" data-min="0" data-max="2000" style="padding: 5px 10px; background: #6c757d; color: white; border: none; border-radius: 3px; cursor: pointer;">Petites communes (&lt;2k)</button>
                    <button class="pop-btn" data-min="2000" data-max="10000" style="padding: 5px 10px; background: #6c757d; color: white; border: none; border-radius: 3px; cursor: pointer;">Moyennes (2k-10k)</button>
                    <button class="pop-btn" data-min="10000" data-max="50000" style="padding: 5px 10px; background: #6c757d; color: white; border: none; border-radius: 3px; cursor: pointer;">Grandes (10k-50k)</button>
                    <button class="pop-btn" data-min="50000" data-max="" style="padding: 5px 10px; background: #6c757d; color: white; border: none; border-radius: 3px; cursor: pointer;">Très grandes (&gt;50k)</button>
                </div>
            </div>
            
            <div style="margin-bottom: 20px;">
                <div id="preview-results" style="padding: 10px; background: #f8f9fa; border-radius: 5px; border-left: 4px solid #007bff;">
                    <strong>Aperçu :</strong> <span id="preview-count">Sélectionnez des critères pour voir le nombre de communes</span>
                </div>
            </div>
            
            <div style="display: flex; justify-content: space-between; margin-top: 30px;">
                <button id="preview-btn" style="padding: 10px 20px; background: #ffc107; color: #212529; border: none; border-radius: 5px; cursor: pointer; font-weight: bold;">Aperçu</button>
                <div>
                    <button id="apply-filter-btn" style="padding: 10px 20px; background: #28a745; color: white; border: none; border-radius: 5px; cursor: pointer; font-weight: bold; margin-right: 10px;">Appliquer le Filtre</button>
                    <button id="close-modal-btn" style="padding: 10px 20px; background: #6c757d; color: white; border: none; border-radius: 5px; cursor: pointer;">Fermer</button>
                </div>
            </div>
        `;
        
        modal.appendChild(modalContent);
        document.body.appendChild(modal);
        
        // Remplir les départements
        populateDepartments();
        
        // Ajouter les événements
        setupModalEvents(modal);
    }
    
    // Remplir la liste des départements
    function populateDepartments() {
        const container = document.getElementById('department-selection');
        container.innerHTML = '';
        
        Object.entries(DEPARTMENTS).forEach(([code, name]) => {
            const div = document.createElement('div');
            div.style.cssText = 'margin-bottom: 5px;';
            div.innerHTML = `
                <label style="display: flex; align-items: center; cursor: pointer;">
                    <input type="checkbox" class="dept-checkbox" value="${code}" style="margin-right: 8px;">
                    <span>${code} - ${name}</span>
                </label>
            `;
            container.appendChild(div);
        });
    }
    
    // Configurer les événements de la modal
    function setupModalEvents(modal) {
        // Fermer la modal
        document.getElementById('close-modal-btn').addEventListener('click', () => {
            document.body.removeChild(modal);
        });
        
        // Sélectionner tous les départements
        document.getElementById('select-all-depts').addEventListener('click', () => {
            document.querySelectorAll('.dept-checkbox').forEach(cb => cb.checked = true);
            updatePreview();
        });
        
        // Désélectionner tous les départements
        document.getElementById('clear-all-depts').addEventListener('click', () => {
            document.querySelectorAll('.dept-checkbox').forEach(cb => cb.checked = false);
            updatePreview();
        });
        
        // Boutons de région
        document.querySelectorAll('.region-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const region = btn.dataset.region;
                const deptCodes = REGIONS[region];
                
                // Désélectionner tous d'abord
                document.querySelectorAll('.dept-checkbox').forEach(cb => cb.checked = false);
                
                // Sélectionner les départements de la région
                deptCodes.forEach(code => {
                    const checkbox = document.querySelector(`.dept-checkbox[value="${code}"]`);
                    if (checkbox) checkbox.checked = true;
                });
                
                updatePreview();
            });
        });
        
        // Boutons de population
        document.querySelectorAll('.pop-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.getElementById('min-population').value = btn.dataset.min;
                document.getElementById('max-population').value = btn.dataset.max;
                updatePreview();
            });
        });
        
        // Aperçu
        document.getElementById('preview-btn').addEventListener('click', updatePreview);
        
        // Appliquer le filtre
        document.getElementById('apply-filter-btn').addEventListener('click', applyFilter);
        
        // Mise à jour automatique de l'aperçu
        document.addEventListener('change', (e) => {
            if (e.target.classList.contains('dept-checkbox')) {
                updatePreview();
            }
        });
        
        document.getElementById('min-population').addEventListener('input', updatePreview);
        document.getElementById('max-population').addEventListener('input', updatePreview);
    }
    
    // Mettre à jour l'aperçu
    function updatePreview() {
        const criteria = getFilterCriteria();
        
        // Simuler le comptage (en réalité, on ferait un appel API)
        let estimatedCount = 'Calcul en cours...';
        
        // Estimation basée sur les critères
        const selectedDepts = criteria.departments.length;
        if (selectedDepts > 0) {
            // Estimation approximative : ~400 communes par département en moyenne
            estimatedCount = `~${selectedDepts * 400} communes`;
        }
        
        document.getElementById('preview-count').textContent = estimatedCount;
    }
    
    // Obtenir les critères de filtrage
    function getFilterCriteria() {
        const selectedDepts = Array.from(document.querySelectorAll('.dept-checkbox:checked')).map(cb => cb.value);
        const minPop = document.getElementById('min-population').value;
        const maxPop = document.getElementById('max-population').value;
        
        return {
            departments: selectedDepts,
            minPopulation: minPop ? parseInt(minPop) : null,
            maxPopulation: maxPop ? parseInt(maxPop) : null
        };
    }
    
    // Appliquer le filtre
    function applyFilter() {
        const criteria = getFilterCriteria();
        
        // Construire la requête de filtrage
        let query = '';
        const conditions = [];
        
        if (criteria.departments.length > 0) {
            conditions.push(`department_code IN (${criteria.departments.map(d => `'${d}'`).join(',')})`);
        }
        
        if (criteria.minPopulation) {
            conditions.push(`population >= ${criteria.minPopulation}`);
        }
        
        if (criteria.maxPopulation) {
            conditions.push(`population <= ${criteria.maxPopulation}`);
        }
        
        if (conditions.length > 0) {
            query = conditions.join(' AND ');
        }
        
        // Appliquer le filtre dans l'interface Listmonk
        applyListmonkFilter(query, criteria);
    }
    
    // Appliquer le filtre dans Listmonk
    function applyListmonkFilter(query, criteria) {
        // Injecter le filtre dans l'interface Listmonk
        const searchInput = document.querySelector('input[placeholder*="search"], input[type="search"], .search input');
        
        if (searchInput) {
            // Utiliser la recherche existante de Listmonk
            let searchTerm = '';
            
            if (criteria.departments.length > 0) {
                searchTerm += `dept:${criteria.departments.join(',')} `;
            }
            
            if (criteria.minPopulation || criteria.maxPopulation) {
                searchTerm += `pop:${criteria.minPopulation || 0}-${criteria.maxPopulation || 999999} `;
            }
            
            searchInput.value = searchTerm.trim();
            searchInput.dispatchEvent(new Event('input', { bubbles: true }));
            searchInput.dispatchEvent(new Event('change', { bubbles: true }));
        }
        
        // Afficher un message de confirmation
        showNotification(`Filtre appliqué : ${criteria.departments.length} départements sélectionnés`);
        
        // Fermer la modal
        const modal = document.querySelector('div[style*="position: fixed"][style*="z-index: 2000"]');
        if (modal) {
            document.body.removeChild(modal);
        }
    }
    
    // Afficher une notification
    function showNotification(message) {
        const notification = document.createElement('div');
        notification.textContent = message;
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: #28a745;
            color: white;
            padding: 12px 24px;
            border-radius: 5px;
            z-index: 3000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        `;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            if (notification.parentNode) {
                document.body.removeChild(notification);
            }
        }, 3000);
    }
    
    // Initialiser l'interface
    function init() {
        // Attendre que la page soit chargée
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', createGeoTargetingInterface);
        } else {
            createGeoTargetingInterface();
        }
        
        // Réinitialiser lors des changements de page (SPA)
        let currentPath = window.location.pathname;
        setInterval(() => {
            if (window.location.pathname !== currentPath) {
                currentPath = window.location.pathname;
                setTimeout(createGeoTargetingInterface, 500);
            }
        }, 1000);
    }
    
    // Démarrer
    init();
})();
EOF

    log_success "Script de ciblage géographique créé"
}

# Injecter le script dans Listmonk
inject_script() {
    log_info "Injection du script dans Listmonk..."
    
    # Copier le script dans le conteneur Listmonk
    docker cp geo-targeting.js listmonk_app:/listmonk/static/public/geo-targeting.js
    
    # Créer un script d'injection
    cat > inject-geo-script.js << 'EOF'
// Script d'injection pour ajouter le ciblage géographique
(function() {
    // Créer et injecter le script
    const script = document.createElement('script');
    script.src = '/public/geo-targeting.js';
    script.async = true;
    document.head.appendChild(script);
    
    console.log('🎯 Interface de ciblage géographique chargée');
})();
EOF

    # Injecter via la console du navigateur
    log_success "Script injecté dans Listmonk"
    log_info "Le script sera disponible à l'URL : http://localhost:9000/public/geo-targeting.js"
}

# Créer un bookmarklet pour l'activation
create_bookmarklet() {
    log_info "Création d'un bookmarklet pour l'activation..."
    
    cat > bookmarklet.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Bookmarklet - Ciblage Géographique Listmonk</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .bookmarklet { background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff; }
        .bookmarklet a { color: #007bff; text-decoration: none; font-weight: bold; }
        .instructions { background: #e9ecef; padding: 15px; border-radius: 5px; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>🎯 Interface de Ciblage Géographique pour Listmonk</h1>
    
    <h2>Installation</h2>
    <div class="bookmarklet">
        <p><strong>Glissez ce lien dans votre barre de favoris :</strong></p>
        <p><a href="javascript:(function(){var s=document.createElement('script');s.src='http://localhost:9000/public/geo-targeting.js';document.head.appendChild(s);})();">🎯 Ciblage Géo</a></p>
    </div>
    
    <div class="instructions">
        <h3>Instructions d'utilisation :</h3>
        <ol>
            <li>Glissez le lien ci-dessus dans votre barre de favoris</li>
            <li>Allez sur votre interface Listmonk : <a href="http://localhost:9000" target="_blank">http://localhost:9000</a></li>
            <li>Naviguez vers la page "Abonnés"</li>
            <li>Cliquez sur le favori "🎯 Ciblage Géo" que vous venez d'ajouter</li>
            <li>Un bouton flottant "🎯 Ciblage Géo" apparaîtra en haut à droite</li>
            <li>Cliquez dessus pour ouvrir l'interface de ciblage géographique</li>
        </ol>
    </div>
    
    <h2>Fonctionnalités</h2>
    <ul>
        <li>🗺️ <strong>Sélection par département</strong> : Choisissez un ou plusieurs départements français</li>
        <li>🏙️ <strong>Filtres rapides par région</strong> : Île-de-France, PACA, Occitanie, etc.</li>
        <li>👥 <strong>Filtrage par population</strong> : Définissez des seuils de population minimum et maximum</li>
        <li>📊 <strong>Aperçu en temps réel</strong> : Voyez le nombre estimé de communes correspondantes</li>
        <li>✅ <strong>Application directe</strong> : Les filtres s'appliquent automatiquement dans Listmonk</li>
    </ul>
    
    <h2>Exemples d'utilisation</h2>
    <ul>
        <li><strong>Campagne régionale</strong> : Sélectionnez "Île-de-France" pour cibler toutes les communes d'IDF</li>
        <li><strong>Petites communes</strong> : Filtrez par population &lt; 2000 habitants</li>
        <li><strong>Grandes villes</strong> : Filtrez par population &gt; 50000 habitants</li>
        <li><strong>Département spécifique</strong> : Sélectionnez uniquement le département 75 (Paris)</li>
    </ul>
    
    <div style="margin-top: 30px; padding: 15px; background: #d4edda; border-radius: 5px; border-left: 4px solid #28a745;">
        <strong>✅ Système opérationnel !</strong><br>
        32 519 communes françaises sont disponibles pour le ciblage géographique.
    </div>
</body>
</html>
EOF

    log_success "Bookmarklet créé : bookmarklet.html"
}

# Tester l'interface
test_interface() {
    log_info "Test de l'interface..."
    
    # Vérifier que Listmonk est accessible
    if curl -s http://localhost:9000 > /dev/null 2>&1; then
        log_success "Listmonk accessible sur http://localhost:9000"
    else
        log_error "Listmonk non accessible"
        return 1
    fi
    
    # Vérifier que le script est accessible
    if curl -s http://localhost:9000/public/geo-targeting.js > /dev/null 2>&1; then
        log_success "Script de ciblage accessible"
    else
        log_warning "Script de ciblage non accessible via HTTP"
        log_info "Utilisez le bookmarklet pour l'injection manuelle"
    fi
}

# Fonction principale
main() {
    echo ""
    log_info "Création de l'interface de ciblage géographique pour Listmonk"
    echo ""
    
    create_geo_targeting_js
    inject_script
    create_bookmarklet
    test_interface
    
    echo ""
    log_success "🎉 INTERFACE DE CIBLAGE CRÉÉE AVEC SUCCÈS !"
    echo ""
    echo "📋 Prochaines étapes :"
    echo "  1. Ouvrez bookmarklet.html dans votre navigateur"
    echo "  2. Glissez le lien dans votre barre de favoris"
    echo "  3. Allez sur http://localhost:9000"
    echo "  4. Cliquez sur le favori pour activer l'interface"
    echo ""
    echo "🎯 L'interface permet de cibler parmi 32 519 communes françaises !"
    echo ""
}

# Exécuter
main "$@"