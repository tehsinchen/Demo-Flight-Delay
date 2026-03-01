export const APP_CONFIG = {
  API_BASE_URL: import.meta.env.VITE_API_BASE_URL || '', 
  MAP: {
    INITIAL_VIEW: {
      center: [25.07, 121.35] as [number, number],
      zoom: 11,
    },
    // Minimalist, fast-loading tiles
    TILE_LAYER: "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
    ATTRIBUTION: '&copy; OpenStreetMap &copy; CARTO',
    // Performance settings
    MIN_ZOOM: 3,
    MAX_ZOOM: 14, // Prevents loading high-detail street level tiles
  },
  AIRPORTS: [
    { id: 'TPE', name: 'Taoyuan Int Airport', position: [25.0777432, 121.2319395] as [number, number] },
    { id: 'TSA', name: 'Songshan Airport', position: [25.0657117, 121.5515924] as [number, number] },
  ],
};