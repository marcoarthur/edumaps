var map = L.map('map').setView([-23.56, -45.15], 15);

// Add OpenStreetMap tiles
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '© OpenStreetMap contributors'
}).addTo(map);

// Layer group for our GeoJSON features
var geoJsonLayer = L.layerGroup().addTo(map);
var pointsLayer = L.layerGroup().addTo(map);

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
    window.pointsLayer.clearLayers();
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
              const popupContent = createCityPopup(props);
              layer.bindPopup(popupContent[0]);
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
  pointsLayer.clearLayers();
  $('#geometryInfo').html('');
  $('#status').text('Map cleared');
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
    'nome_concurso': 'Nome Concurso',
    'total_escolas': 'Total de Escolas'
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

function loadRelatedPoints(cityName) {

  if (window.pointsLayer) {
    window.pointsLayer.clearLayers();
  }

  // Fetch related points GeoJSON
  $.getJSON(`/api/schools?city=${encodeURIComponent(cityName)}`)
    .done(function(pointsData) {
      if (pointsData.features && pointsData.features.length > 0) {
        // Create and style the points layer
        window.pointsLayer = L.geoJSON(pointsData, {
          pointToLayer: function(feature, latlng) {
            // Custom marker styling
            return L.circleMarker(latlng, {
              radius: 6,
              fillColor: "#ff7800",
              color: "#000",
              weight: 1,
              opacity: 1,
              fillOpacity: 0.8
            });
          },
          onEachFeature: function(feature, layer) {
            if (feature.properties) {
              const props = feature.properties;
              const popupContent = createSchoolPopup(props);
              layer.bindPopup(popupContent);
            }
          }
        }).addTo(map);

        console.log(`Loaded ${pointsData.features.length} points for ${cityName}`);
      } else {
        console.log(`No points found for ${cityName}`);
      }
    })
    .fail(function(xhr, status, error) {
      console.error('Points GeoJSON fetch error:', error);
    });
}

function createSchoolLink(cityName, displayText = null) {
  let $link = $('<a>', {
    href: '#',
    text: displayText || `Load ${cityName}`
  });

  // Add classes for styling
  $link.addClass('school');

  // Store city name in data attribute
  $link.data('city', cityName);

  // Add click handler
  $link.on('click', function(event) {
    event.preventDefault();
    let city = $(this).data('city');
    loadRelatedPoints(city);
  });

  return $link;
}

function createDetailLink(fid, displayText = null) {
  let $link = $('<a>', {
    href: `/api/details?fid=${fid}`,
    text: displayText || `Load ${fid}`,
  });
  $link.addClass('school');
  $link.data('fid', fid);
  $link.on('click', function(event) {
    event.preventDefault();
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
  return $link;
}

function createCityPopup(props) {
  const details = createDetailLink(props.fid, 'Detalhes')
  const schools = createSchoolLink(props.name, 'Escolas');
  const popupContent = $('<div>');
  popupContent.append(
    $('<strong>').text(props.name),
    $('<br>'),
    details,
    $('<br>'),
    schools,
  );
  return popupContent;
}

function createSchoolPopup(props) {
  const popupContent = `
    <div>
    <strong>${props.escola || 'Escola - Sem Nome'}</strong><br>
    ${props.categoria_administrativa ? `Tipo: ${props.categoria_administrativa}<br>` : ''}
    ${props.telefone || ''}
    </div>`;
  return popupContent;
}
