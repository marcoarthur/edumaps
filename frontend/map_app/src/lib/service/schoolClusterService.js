// services/schoolClusterService.js
export async function fetchClusteredSchools(city, clusterIds = null) {
  const params = new URLSearchParams({
    city: encodeURIComponent(city)
  });
  
  if (clusterIds && clusterIds.length) {
    params.append('clusters', clusterIds.join(','));
  }
  
  const response = await fetch(`/api/schools/clustered?${params}`);
  
  if (!response.ok) {
    throw new Error(`Failed to fetch clustered schools: ${response.status}`);
  }
  
  return await response.json();
}

export async function fetchSchoolComparison(schoolIds) {
  const response = await fetch('/api/schools/compare', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ school_ids: schoolIds })
  });
  
  return await response.json();
}
