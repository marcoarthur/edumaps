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
    const $vp = $('div.info-panel');
    $vp.find('.details-container').remove();
    $vp.append(formatGeoJSONDetails(data));
  })
  .fail(function (jqxhr, textStatus, error) {
      console.error('Request failed:', textStatus, error);
  });
});

function formatGeoJSONDetails(geojsonData) {
  // Parse JSON if it's a string
  const data = typeof geojsonData === 'string' ? JSON.parse(geojsonData) : geojsonData;

  // Create container using jQuery
  const $container = $('<div>').addClass('details-container');

  // Create header
  const $header = $('<h3>').addClass('details-header').text(`Detalhes ${data.nome_municipio}`);
  const $subheader = $('<p>').addClass('details-subheader')
    .text('Dados malha IBGE, municípios paulista');

  // Create table
  const $table = $('<table>').addClass('geojson-details');
  const $tbody = $('<tbody>');

  // Field labels for better readability
  const fieldLabels = {
    'id': 'ID',
    'area': 'Área (km²)',
    'codigo_municipio': 'Código do Município',
    'nome_municipio': 'Município',
    'codigo_unidade_federativa': 'Código UF',
    'nome_unidade_federativa': 'Estado',
    'sigla_unidade_federativa': 'UF',
    'codigo_regiao': 'Código Região',
    'nome_regiao_intermediaria': 'Região Intermediária',
    'nome_regiao_interna': 'Região Imediata',
    'sigla_regiao': 'Sigla Região',
    'codigo_concurso': 'Código Concurso',
    'nome_concurso': 'Nome Concurso'
  };

  // Iterate through properties and create rows
  $.each(data, function(key, value) {
    if (key !== 'type' && key !== 'geometry') {
      const label = fieldLabels[key] || key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
      const formattedValue = formatValue(key, value);
      const isNull = value === null;

      const $row = $('<tr>');
      const $headerCell = $('<th>').text(label);
      const $dataCell = $('<td>').addClass(isNull ? 'null-value' : '').html(formattedValue);

      $row.append($headerCell, $dataCell);
      $tbody.append($row);
    }
  });

  $table.append($tbody);

  // Assemble the container
  $container.append($header, $subheader, $table);

  return $container;
}

function formatValue(key, value) {
  if (value === null) return 'N/A';

  switch (key) {
    case 'area':
      return Number(value).toLocaleString('pt-BR', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      });
    case 'codigo_municipio':
    case 'codigo_unidade_federativa':
      return `"${value}"`;
    default:
      return $('<div>').text(value).html(); // Basic XSS protection
  }
}
