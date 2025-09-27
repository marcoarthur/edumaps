var map = L.map('map').setView([-23.56, -45.15], 15);

// Add OpenStreetMap tiles
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '© OpenStreetMap contributors'
}).addTo(map);

// Layer group for our GeoJSON features
var geoJsonLayer = L.layerGroup().addTo(map);

// Style for MultiPolygon features
var multiPolygonStyle = {
  color: '#3388ff',
  weight: 2,
  opacity: 0.8,
  fillColor: '#3388ff',
  fillOpacity: 0.2
};

// City search functionality
$('#searchCity').click(function() {
  const cityName = $('#cityInput').val().trim();

  if (!cityName) {
    $('#status').text('Please enter a city name');
    return;
  }

  loadCityGeoJSON(cityName);
});

// Allow pressing Enter to search
$('#cityInput').keypress(function(e) {
  if (e.which === 13) { // Enter key
    $('#searchCity').click();
  }
});

function loadCityGeoJSON(cityName) {
  $('#status').text(`Searching for ${cityName}...`);

  // Clear previous layers
  if (window.geoJsonLayer) {
    window.geoJsonLayer.clearLayers();
  }

  // Fetch GeoJSON for the specific city
  $.getJSON(`/api/geojson?city=${encodeURIComponent(cityName)}`)
    .done(function(data) {
      if (data.features && data.features.length > 0) {
        // Create and style the GeoJSON layer
        window.geoJsonLayer = L.geoJSON(data, {
          style: {
            color: '#3388ff',
            weight: 2,
            fillColor: '#3388ff',
            fillOpacity: 0.2
          },
          onEachFeature: function(feature, layer) {
            if (feature.properties) {
              const props = feature.properties;
              const details = `<a class="detail" href=/api/details?fid=${props.fid}>detail</a>`;
              const popupContent = `
                <div>
                <strong>${props.name || 'Unnamed Feature'}</strong><br>
                Area: ${props.area || ''} km<sup>2</sup><br>
                ${details}
                </div>
                `;
              layer.bindPopup(popupContent);
            }
          }
        }).addTo(map);

        // Fit map to the city bounds
        map.fitBounds(window.geoJsonLayer.getBounds());
        $('#status').text(`Found ${data.features.length} features for ${cityName}`);
      } else {
        $('#status').text(`No features found for ${cityName}`);
      }
    })
    .fail(function(xhr, status, error) {
      $('#status').text(`Error: ${error}`);
      console.error('GeoJSON fetch error:', error);
    });
}

// Clear map data
$('#clearData').click(function() {
  geoJsonLayer.clearLayers();
  $('#geometryInfo').html('');
  $('#status').text('Map cleared');
});

// Detail link
$(document).on( 'click', 'a', function (e) {
  e.preventDefault();
  const url = $(this).attr('href');
  $.getJSON(url, function(data) {
    $('#debugInfo').text(JSON.stringify(data,null,2));
  })
  .fail(function (jqxhr, textStatus, error) {
      console.error('Request failed:', textStatus, error);
  });
});
