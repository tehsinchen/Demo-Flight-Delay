import axios from 'axios';
import { APP_CONFIG } from '../config/constants';
import { FlightGroup, HistogramResponse } from '../types';

const api = axios.create({
  baseURL: APP_CONFIG.API_BASE_URL,
});

export const flightService = {
  getFlightsByAirport: async (code: string): Promise<FlightGroup[]> => {
    const { data } = await api.get<FlightGroup[]>(`/flights/${code}`);
    return data;
  },
  
  getHistogram: async (airport: string, airline: string, flightNo: string): Promise<HistogramResponse> => {
    // encodeURIComponent is crucial for airline names with spaces
    const { data } = await api.get<HistogramResponse>(
      `/histogram/${airport}/${encodeURIComponent(airline)}/${flightNo}`
    );
    return data;
  },
};