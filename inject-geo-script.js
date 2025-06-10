// Script d'injection pour ajouter le ciblage géographique
(function() {
    // Créer et injecter le script
    const script = document.createElement('script');
    script.src = '/public/geo-targeting.js';
    script.async = true;
    document.head.appendChild(script);
    
    console.log('🎯 Interface de ciblage géographique chargée');
})();
