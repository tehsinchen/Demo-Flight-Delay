export interface FlightGroup {
  airline_name: string;
  flight_nos: string[];
}

export interface HistogramPoint {
  name: string;
  count: number;
}

export interface HistogramResponse {
  labels: string[];
  values: number[];
}