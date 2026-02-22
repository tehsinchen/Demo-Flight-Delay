import React, { useState, useMemo } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import { Plane, Search, Loader2, MapPin } from 'lucide-react';
import { APP_CONFIG } from './config/constants';
import { flightService } from './api/flightService';
import { FlightGroup, HistogramPoint } from './types';
import { HistogramOverlay } from './components/HistogramOverlay';
import { cn } from './utils/cn';
import 'leaflet/dist/leaflet.css';

// --- Sub-Component: FlightList ---
const FlightList = ({ 
  groups, 
  onSelect 
}: { 
  groups: FlightGroup[], 
  onSelect: (airline: string, no: string) => void 
}) => (
  <div className="max-h-60 overflow-y-auto pr-1 custom-scrollbar">
    {groups.map((group, idx) => (
      <div key={idx} className="mb-4 last:mb-0">
        <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1.5">
          {group.airline_name}
        </span>
        <div className="flex flex-wrap gap-1.5">
          {group.flight_nos.map(no => (
            <button 
              key={no}
              onClick={() => onSelect(group.airline_name, no)}
              className={cn(
                "px-2.5 py-1 text-xs font-medium bg-white border border-slate-200 rounded",
                "hover:border-blue-500 hover:text-blue-600 transition-all shadow-sm active:scale-95"
              )}
            >
              {no}
            </button>
          ))}
        </div>
      </div>
    ))}
  </div>
);

const App: React.FC = () => {
  const [flights, setFlights] = useState<FlightGroup[]>([]);
  const [selectedAirport, setSelectedAirport] = useState<string | null>(null);
  const [filter, setFilter] = useState("");
  const [histData, setHistData] = useState<HistogramPoint[] | null>(null);
  const [loading, setLoading] = useState(false);

  const filteredData = useMemo(() => {
    return flights.map(g => ({
      ...g,
      flight_nos: g.flight_nos.filter(no => no.toLowerCase().includes(filter.toLowerCase()))
    })).filter(g => g.flight_nos.length > 0);
  }, [flights, filter]);

  const handleViewFlight = async (airline: string, flightNo: string) => {
    const res = await flightService.getHistogram(selectedAirport!, airline, flightNo);
    setHistData(res.labels.map((l, i) => ({ name: l, count: res.values[i] })));
  };

  return (
    <div className="h-screen w-screen flex flex-col overflow-hidden bg-slate-50">
      {/* Header Section */}
      <header className="bg-slate-900 text-white p-4 shadow-lg z-[1000] flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Plane className="text-blue-400 rotate-45" />
          <h1 className="font-bold tracking-tighter uppercase text-sm md:text-base">
            {import.meta.env.VITE_APP_TITLE || 'Flight Ops'}
          </h1>
        </div>
        {loading && <Loader2 className="animate-spin text-blue-400" size={20} />}
      </header>

      {/* Main Map Content */}
      <main className="flex-1 relative">
        <MapContainer 
          center={APP_CONFIG.MAP.INITIAL_VIEW.center} 
          zoom={APP_CONFIG.MAP.INITIAL_VIEW.zoom} 
          className="h-full w-full"
        >
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          
          {APP_CONFIG.AIRPORTS.map(ap => (
            <Marker 
              key={ap.id} 
              position={ap.position} 
              eventHandlers={{ click: () => {
                setLoading(true);
                flightService.getFlightsByAirport(ap.id)
                  .then(setFlights)
                  .then(() => setSelectedAirport(ap.id))
                  .finally(() => setLoading(false));
              }}}
            >
              <Popup minWidth={320}>
                <div className="p-1">
                  <div className="flex items-center gap-2 mb-3 border-b pb-2">
                    <MapPin size={16} className="text-red-500" />
                    <h3 className="font-bold text-slate-800">{ap.name}</h3>
                  </div>
                  <div className="relative mb-3">
                    <Search className="absolute left-2.5 top-2.5 text-slate-400" size={14} />
                    <input 
                      className="w-full pl-9 pr-3 py-2 bg-slate-50 border rounded-lg text-sm outline-none focus:ring-1 focus:ring-blue-500" 
                      placeholder="Filter flights..."
                      value={filter}
                      onChange={(e) => setFilter(e.target.value)}
                    />
                  </div>
                  <FlightList groups={filteredData} onSelect={handleViewFlight} />
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>

        {histData && (
          <HistogramOverlay 
            data={histData} 
            title={`Delay Analysis: ${selectedAirport}`} 
            onClose={() => setHistData(null)} 
          />
        )}
      </main>
    </div>
  );
};

export default App;